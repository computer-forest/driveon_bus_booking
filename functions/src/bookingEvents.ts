import { Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";

import { Note, notify, render, rupees, staffUids, templateText } from "./notifications";

const db = () => getFirestore();
const REGION = "asia-south1";

type Data = FirebaseFirestore.DocumentData;

const DEFAULTS = {
  cost: "Total fare for your {route} trip is {fare}. Advance due: {advance}.",
  confirmed: "Your bus is confirmed! {bus}, driver {driver}. Booking {reference}.",
  realloc: "Your bus has changed to {bus}. Driver: {driver}. Booking {reference}.",
  hold: "{reference} hold expires in {minutes} minutes.",
};

async function advancePercent(): Promise<number> {
  const cfg = (await db().doc("config/app").get()).data();
  return Number(cfg?.defaultAdvancePercent ?? 25);
}

function vars(b: Data, extra: Record<string, string | number> = {}): Record<string, string | number> {
  return {
    reference: String(b.reference ?? ""),
    route: String(b.route ?? ""),
    bus: String(b.busReg ?? ""),
    driver: String(b.driverName || "your driver"),
    fare: rupees(Number(b.totalFare ?? 0)),
    ...extra,
  };
}

/** What the customer should hear about a stage change, or null for none. */
async function forCustomer(before: Data | undefined, after: Data): Promise<Note | null> {
  const bookingId = String(after.id ?? "");
  const stage = String(after.stage);
  const ref = String(after.reference);
  const note = (n: Omit<Note, "bookingId">): Note => ({ ...n, bookingId });

  if (!before) {
    return note({
      title: "Bus held for you",
      body: `${ref} · ${after.route}. We'll call you to confirm the fare. No payment is needed yet.`,
      tone: "info",
      kind: "hold-created",
    });
  }
  if (before.stage !== stage) {
    switch (stage) {
      case "costConfirmed": {
        const advance = Math.round((Number(after.totalFare) * (await advancePercent())) / 100);
        return note({
          title: "Cost confirmed",
          body: render(await templateText("tpl-cost", DEFAULTS.cost), vars(after, { advance: rupees(advance) })),
          tone: "info",
          kind: "cost-confirmed",
        });
      }
      case "confirmed":
        return note({
          title: "Booking confirmed",
          body: render(await templateText("tpl-confirmed", DEFAULTS.confirmed), vars(after)),
          tone: "success",
          kind: "confirmed",
        });
      case "inTrip":
        return note({ title: "Your trip has started", body: `${ref} is under way. Have a safe journey.`, tone: "info", kind: "trip-started" });
      case "completed":
        return note({ title: "Trip completed", body: `${ref} is complete. How was it? Please rate your trip.`, tone: "success", kind: "trip-completed" });
      case "settled":
        return note({ title: "All paid up", body: `${ref} is settled. Thank you for travelling with us.`, tone: "success", kind: "settled" });
      case "expired":
        return note({ title: "Hold expired", body: `Your hold on ${after.busReg} for ${ref} ran out and the bus was released. You can search again.`, tone: "warning", kind: "hold-expired" });
      case "cancelled": {
        const refund = Number(after.refundedAmount ?? 0);
        return note({
          title: "Booking cancelled",
          body: `${ref} has been cancelled.${refund > 0 ? ` A refund of ${rupees(refund)} has been recorded.` : ""}`,
          tone: "warning",
          kind: "cancelled",
        });
      }
    }
    return null;
  }
  if (before.busId !== after.busId) {
    const fareChanged = Number(before.totalFare) !== Number(after.totalFare) && Number(after.totalFare) > 0;
    return note({
      title: "Your bus has changed",
      body:
        render(await templateText("tpl-realloc", DEFAULTS.realloc), vars(after)) +
        (fareChanged ? ` Your total fare is now ${rupees(Number(after.totalFare))}.` : ""),
      tone: "warning",
      kind: "reallocated",
    });
  }
  return null;
}

/**
 * Turns a booking change into notifications. Fires on every write, but only
 * a new booking, a stage change or a change of bus produces one, so the
 * server's own bookkeeping writes (such as the expiry warning flag) are quiet.
 */
export const onBookingWritten = onDocumentWritten({ document: "bookings/{id}", region: REGION }, async (event) => {
  const before = event.data?.before.data();
  const afterSnap = event.data?.after;
  if (!afterSnap?.exists) return;
  const after: Data = { ...afterSnap.data()!, id: event.params.id };

  const customerNote = await forCustomer(before, after);
  if (customerNote) await notify(event.id, [after.customerId], customerNote);

  if (!before) {
    await notify(`${event.id}-staff`, await staffUids(), {
      title: "New booking request",
      body: `${after.reference} · ${after.route} · ${after.customerName}. Confirm the fare before the hold ends.`,
      tone: "urgent",
      bookingId: event.params.id,
      kind: "staff-new-request",
    });
  }
  logger.info("booking event", { id: event.params.id, stage: after.stage, notified: !!customerNote });
});

/** A customer asking to cancel is something staff have to act on. */
export const onCancellationRequested = onDocumentCreated({ document: "cancellations/{id}", region: REGION }, async (event) => {
  const req = event.data?.data();
  if (!req) return;
  const booking = (await db().doc(`bookings/${req.bookingId}`).get()).data();
  await notify(event.id, await staffUids(), {
    title: "Cancellation requested",
    body: `${booking?.reference ?? "A booking"} · ${booking?.customerName ?? "customer"}${req.reason ? ` · "${req.reason}"` : ""}`,
    tone: "warning",
    bookingId: String(req.bookingId),
    kind: "staff-cancellation-request",
  });
});

/** Tells the customer when staff decline. (An approval is announced by the
 *  booking becoming Cancelled.) */
export const onCancellationDecided = onDocumentUpdated({ document: "cancellations/{id}", region: REGION }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === after.status || after.status !== "declined") return;
  const booking = (await db().doc(`bookings/${after.bookingId}`).get()).data();
  await notify(event.id, [String(after.requestedBy)], {
    title: "Cancellation request declined",
    body: `${booking?.reference ?? "Your booking"} stays as it is.${after.decisionNote ? ` ${after.decisionNote}` : ""}`,
    tone: "info",
    bookingId: String(after.bookingId),
    kind: "cancellation-declined",
  });
});

const WARN_MINUTES = 5;

/**
 * Warns staff, and the customer, that a hold is about to run out. Each hold
 * is warned once (`expiryWarned`). Returns how many it warned about.
 */
export async function warnExpiringHolds(now = Timestamp.now()): Promise<number> {
  const soon = Timestamp.fromMillis(now.toMillis() + WARN_MINUTES * 60 * 1000);
  const snap = await db()
    .collection("bookings")
    .where("stage", "==", "requested")
    .where("holdExpiresAt", ">", now)
    .where("holdExpiresAt", "<=", soon)
    .get();
  let warned = 0;
  for (const doc of snap.docs) {
    const b = doc.data();
    if (b.expiryWarned === true) continue;
    const minutes = Math.max(1, Math.ceil((b.holdExpiresAt.toMillis() - now.toMillis()) / 60000));
    await doc.ref.update({ expiryWarned: true });
    await notify(`${doc.id}-warn`, await staffUids(), {
      title: "Hold about to expire",
      body: render(await templateText("tpl-hold", DEFAULTS.hold), vars(b, { minutes })),
      tone: "urgent",
      bookingId: doc.id,
      kind: "staff-hold-expiring",
    });
    await notify(`${doc.id}-warn-customer`, [b.customerId], {
      title: "Hold expiring soon",
      body: `Your held bus for ${b.route} is released in about ${minutes} minutes unless we confirm it.`,
      tone: "urgent",
      bookingId: doc.id,
      kind: "hold-expiring",
    });
    warned++;
  }
  return warned;
}
