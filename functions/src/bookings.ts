import { getAuth } from "firebase-admin/auth";
import { FieldValue, Firestore, Timestamp, Transaction, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { Blackout, Bus, DayWindow, Occupied, dayStart, isBusFree, occupiesBus, parseIst } from "./availability";
import { warnExpiringHolds } from "./bookingEvents";

const db = (): Firestore => getFirestore();

const MAX_ACTIVE_HOLDS_PER_CUSTOMER = 3;
const MAX_TRIP_DAYS = 30;
const MAX_MONEY = 10_000_000;
const DAY_MS = 24 * 60 * 60 * 1000;

// --- small helpers -------------------------------------------------------

function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return uid;
}

function requireAdmin(request: CallableRequest): string {
  const uid = requireUid(request);
  if (request.auth?.token.role !== "admin") throw new HttpsError("permission-denied", "Staff only.");
  return uid;
}

const ms = (v: unknown): number | null => (v instanceof Timestamp ? v.toMillis() : null);

function money(v: unknown, label: string, min = 0): number {
  if (typeof v !== "number" || !Number.isInteger(v) || v < min || v > MAX_MONEY) {
    throw new HttpsError("invalid-argument", `${label} must be a whole number of rupees.`);
  }
  return v;
}

function text(v: unknown, max: number): string {
  return typeof v === "string" ? v.trim().slice(0, max) : "";
}

function toBus(id: string, d: FirebaseFirestore.DocumentData): Bus {
  return {
    id,
    active: d.active === true,
    capacity: typeof d.capacity === "number" ? d.capacity : 0,
    weeklyAvailability: Array.isArray(d.weeklyAvailability)
      ? (d.weeklyAvailability as DayWindow[]).map((w) => ({
          available: w.available === true,
          start: Number(w.start ?? 0),
          end: Number(w.end ?? 0),
        }))
      : [],
  };
}

function toOccupied(doc: FirebaseFirestore.QueryDocumentSnapshot, now: number): Occupied | null {
  const d = doc.data();
  const start = ms(d.start);
  const end = ms(d.end);
  if (start === null || end === null) return null;
  if (!occupiesBus(String(d.stage), ms(d.holdExpiresAt), now)) return null;
  return { busId: String(d.busId), start, end };
}

async function blackoutsFor(): Promise<Blackout[]> {
  const snap = await db().collection("blackouts").get();
  return snap.docs.map((d) => ({
    busId: String(d.data().busId),
    from: ms(d.data().from) ?? 0,
    to: ms(d.data().to) ?? 0,
  }));
}

/** Today's date in India as YYYYMMDD, for booking references. */
function istYmd(nowMs: number): string {
  const d = new Date(nowMs + 330 * 60 * 1000);
  return `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, "0")}${String(d.getUTCDate()).padStart(2, "0")}`;
}

async function actorName(uid: string): Promise<string> {
  try {
    return (await getAuth().getUser(uid)).displayName ?? "Staff";
  } catch {
    return "Staff";
  }
}

function audit(tx: Transaction, actor: string, actorUid: string, action: string, detail: string, docId: string) {
  tx.set(db().collection("auditLog").doc(), {
    actor,
    actorUid,
    action,
    detail,
    collection: "bookings",
    docId,
    at: FieldValue.serverTimestamp(),
  });
}

function parseTrip(request: CallableRequest): { start: number; end: number } {
  const start = parseIst(request.data?.startsAt);
  const end = parseIst(request.data?.endsAt);
  if (start === null || end === null) throw new HttpsError("invalid-argument", "startsAt and endsAt are required.");
  if (end <= start) throw new HttpsError("invalid-argument", "The trip must end after it starts.");
  if (end - start > MAX_TRIP_DAYS * DAY_MS) throw new HttpsError("invalid-argument", "That trip is too long.");
  if (dayStart(start) < dayStart(Date.now())) throw new HttpsError("invalid-argument", "That date has already passed.");
  return { start, end };
}

// --- search --------------------------------------------------------------

/**
 * Which buses can be chartered for a trip. The server alone decides:
 * customers cannot read other customers' bookings, so the app could never
 * work this out for itself.
 *
 *   in:  { startsAt, endsAt: "YYYY-MM-DDTHH:mm" (India time), capacity?: int }
 *   out: { busIds: string[] }
 */
export const searchBuses = onCall(async (request) => {
  const uid = requireUid(request);
  const { start, end } = parseTrip(request);
  const capacity = request.data?.capacity;
  if (capacity !== undefined && capacity !== null && (!Number.isInteger(capacity) || capacity < 0)) {
    throw new HttpsError("invalid-argument", "capacity must be a whole number.");
  }
  const now = Date.now();

  const [busSnap, vendorSnap, bookingSnap, blackouts] = await Promise.all([
    db().collection("buses").where("active", "==", true).get(),
    db().collection("vendors").get(),
    db().collection("bookings").where("end", ">", Timestamp.fromMillis(start)).get(),
    blackoutsFor(),
  ]);
  const vendorActive = new Map(vendorSnap.docs.map((d) => [d.id, d.data().active !== false]));
  const occupied = bookingSnap.docs.map((d) => toOccupied(d, now)).filter((o): o is Occupied => o !== null);

  const busIds = busSnap.docs
    .filter((d) => vendorActive.get(String(d.data().vendorId)) !== false) // a deactivated vendor's buses are hidden
    .map((d) => toBus(d.id, d.data()))
    .filter((bus) => (capacity == null || bus.capacity >= capacity) && isBusFree(bus, start, end, occupied, blackouts))
    .map((bus) => bus.id);

  if (busIds.length === 0) {
    // Feeds the "failed searches" report.
    await db().collection("searchMisses").add({
      at: FieldValue.serverTimestamp(),
      customerId: uid,
      startsAt: request.data.startsAt,
      endsAt: request.data.endsAt,
      capacity: capacity ?? null,
    });
  }
  return { busIds };
});

// --- hold ----------------------------------------------------------------

/**
 * Holds a bus for a customer. The availability check and the hold are one
 * transaction, serialised per bus by a lock document, so two customers
 * can never hold the same bus: exactly one succeeds and the other is told
 * the bus is gone.
 *
 *   in:  { busId, startsAt, endsAt, route, pickupLandmark? }
 *   out: { bookingId, reference }
 */
export const createHold = onCall(async (request) => {
  const uid = requireUid(request);
  if (request.auth?.token.role === "admin") throw new HttpsError("permission-denied", "Staff cannot hold a bus.");
  const { start, end } = parseTrip(request);
  const busId = text(request.data?.busId, 80);
  if (!busId) throw new HttpsError("invalid-argument", "busId is required.");
  const route = text(request.data?.route, 200) || "Charter";
  const landmark = text(request.data?.pickupLandmark, 200);

  const result = await db().runTransaction(async (tx) => {
    const now = Date.now();
    const busRef = db().doc(`buses/${busId}`);
    const lockRef = db().doc(`busLocks/${busId}`);
    const ymd = istYmd(now);
    const counterRef = db().doc(`counters/booking-${ymd}`);

    // All reads first.
    const [busSnap, lockSnap, counterSnap, profileSnap, configSnap, bookingSnap, mineSnap] = await Promise.all([
      tx.get(busRef),
      tx.get(lockRef),
      tx.get(counterRef),
      tx.get(db().doc(`users/${uid}`)),
      tx.get(db().doc("config/app")),
      tx.get(db().collection("bookings").where("busId", "==", busId).where("end", ">", Timestamp.fromMillis(start))),
      tx.get(db().collection("bookings").where("customerId", "==", uid)),
    ]);
    void lockSnap; // read so the write below conflicts with any concurrent hold on this bus

    if (!busSnap.exists) throw new HttpsError("not-found", "That bus does not exist.");
    const busData = busSnap.data()!;
    const vendorSnap = await tx.get(db().doc(`vendors/${busData.vendorId}`));
    if (vendorSnap.exists && vendorSnap.data()!.active === false) {
      throw new HttpsError("failed-precondition", "bus-unavailable");
    }

    const activeHolds = mineSnap.docs.filter(
      (d) => d.data().stage === "requested" && occupiesBus("requested", ms(d.data().holdExpiresAt), now),
    ).length;
    if (activeHolds >= MAX_ACTIVE_HOLDS_PER_CUSTOMER) {
      throw new HttpsError("resource-exhausted", "You already have several buses on hold. Wait for them to be confirmed or expire.");
    }

    const bus = toBus(busId, busData);
    const occupied = bookingSnap.docs.map((d) => toOccupied(d, now)).filter((o): o is Occupied => o !== null);
    const blackouts = (await tx.get(db().collection("blackouts").where("busId", "==", busId))).docs.map((d) => ({
      busId,
      from: ms(d.data().from) ?? 0,
      to: ms(d.data().to) ?? 0,
    }));
    if (!isBusFree(bus, start, end, occupied, blackouts)) throw new HttpsError("failed-precondition", "bus-unavailable");

    const holdMinutes = Number(configSnap.data()?.holdMinutes ?? 30);
    const sequence = Number(counterSnap.data()?.n ?? 0) + 1;
    const reference = `CB-${ymd}-${String(sequence).padStart(4, "0")}`;
    const profile = profileSnap.data() ?? {};
    const phoneDigits = uid.replace(/\D/g, "").slice(-10);

    const bookingRef = db().collection("bookings").doc();
    tx.set(lockRef, { n: FieldValue.increment(1), at: FieldValue.serverTimestamp() });
    tx.set(counterRef, { n: sequence });
    tx.set(bookingRef, {
      reference,
      customerId: uid,
      customerName: String(profile.name ?? "") || "Customer",
      customerPhone: phoneDigits ? `+91 ${phoneDigits.slice(0, 5)} ${phoneDigits.slice(5)}` : "",
      route,
      capacity: bus.capacity,
      busId,
      busReg: String(busData.regNumber ?? ""),
      driverName: String(busData.driverName ?? ""),
      start: Timestamp.fromMillis(start),
      end: Timestamp.fromMillis(end),
      totalFare: 0,
      amountPaid: 0,
      stage: "requested",
      holdExpiresAt: Timestamp.fromMillis(now + holdMinutes * 60 * 1000),
      pickupLandmark: landmark || null,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { bookingId: bookingRef.id, reference };
  });

  logger.info("hold created", { bookingId: result.bookingId });
  return result;
});

// --- staff actions on a booking -----------------------------------------

type Action =
  | "confirmCost"
  | "recordAdvance"
  | "startTrip"
  | "completeTrip"
  | "recordBalance"
  | "reallocate"
  | "cancel"
  | "declineCancellation";

const EDITABLE = ["requested", "costConfirmed", "confirmed"];

/**
 * Staff moves a booking through its lifecycle. The server checks that every
 * step is legal from the booking's current stage, so a screen (or anyone
 * with a staff token) cannot skip a stage or confirm a lapsed hold.
 *
 *   in: { bookingId, action, ...fields }
 *     confirmCost   { fare }
 *     recordAdvance { amount, mode?, reference? }   requested/costConfirmed -> confirmed
 *     startTrip                                      confirmed -> inTrip
 *     completeTrip                                   inTrip -> completed
 *     recordBalance { amount, mode?, reference? }   completed -> settled
 *     reallocate    { newBusId }
 *     cancel        { reason?, refundAmount?, mode?, reference?, requestId? }   releases the bus; records any refund;
 *                   with requestId it approves that customer request
 *     declineCancellation { requestId, note? }
 */
export const bookingAction = onCall(async (request) => {
  const staffUid = requireAdmin(request);
  const bookingId = text(request.data?.bookingId, 80);
  const action = request.data?.action as Action;
  if (!bookingId) throw new HttpsError("invalid-argument", "bookingId is required.");
  const actor = await actorName(staffUid);

  return db().runTransaction(async (tx) => {
    const now = Date.now();
    const ref = db().doc(`bookings/${bookingId}`);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "No such booking.");
    const b = snap.data()!;
    const stage = String(b.stage);
    const reference = String(b.reference);

    const holdLapsed = stage === "requested" && !occupiesBus(stage, ms(b.holdExpiresAt), now);
    const need = (allowed: string[], what: string) => {
      if (!allowed.includes(stage)) throw new HttpsError("failed-precondition", `Cannot ${what} a booking that is ${stage}.`);
      if (holdLapsed) throw new HttpsError("failed-precondition", "This hold has expired; the bus has been released.");
    };

    const addPayment = (kind: "advance" | "balance" | "refund", amount: number) => {
      tx.set(db().collection("payments").doc(), {
        bookingId,
        kind,
        amount,
        mode: text(request.data?.mode, 40) || (kind === "balance" ? "Cash" : "UPI"),
        reference: text(request.data?.reference, 100),
        receivedOn: Timestamp.fromMillis(now),
        recordedBy: `Admin · ${actor}`,
        at: FieldValue.serverTimestamp(),
      });
    };

    switch (action) {
      case "confirmCost": {
        need(EDITABLE, "set the cost of");
        const fare = money(request.data?.fare, "The fare", 1);
        tx.update(ref, {
          totalFare: fare,
          ...(stage === "requested" ? { stage: "costConfirmed", holdExpiresAt: null } : {}),
        });
        audit(tx, actor, staffUid, "Booking cost set", `${reference} · ₹${fare}`, bookingId);
        return { stage: stage === "requested" ? "costConfirmed" : stage };
      }
      case "recordAdvance": {
        need(["requested", "costConfirmed"], "confirm");
        if (!(Number(b.totalFare) > 0)) throw new HttpsError("failed-precondition", "Set the cost first.");
        const amount = money(request.data?.amount, "The advance", 0);
        if (amount > 0) addPayment("advance", amount);
        tx.update(ref, {
          amountPaid: Number(b.amountPaid) + amount,
          stage: "confirmed",
          holdExpiresAt: null,
          confirmedAt: FieldValue.serverTimestamp(),
        });
        audit(tx, actor, staffUid, "Booking confirmed", `${reference} · advance ₹${amount}`, bookingId);
        return { stage: "confirmed" };
      }
      case "startTrip":
        need(["confirmed"], "start");
        tx.update(ref, { stage: "inTrip" });
        audit(tx, actor, staffUid, "Trip started", reference, bookingId);
        return { stage: "inTrip" };
      case "completeTrip":
        need(["inTrip"], "complete");
        tx.update(ref, { stage: "completed" });
        audit(tx, actor, staffUid, "Trip completed", reference, bookingId);
        return { stage: "completed" };
      case "recordBalance": {
        need(["completed"], "settle");
        const amount = money(request.data?.amount, "The balance", 0);
        if (amount > 0) addPayment("balance", amount);
        tx.update(ref, { amountPaid: Number(b.amountPaid) + amount, stage: "settled" });
        audit(tx, actor, staffUid, "Booking settled", `${reference} · balance ₹${amount}`, bookingId);
        return { stage: "settled" };
      }
      case "cancel": {
        need(EDITABLE, "cancel");
        const refund = money(request.data?.refundAmount ?? 0, "The refund", 0);
        if (refund > Number(b.amountPaid)) {
          throw new HttpsError("failed-precondition", `The refund cannot be more than what was paid (₹${b.amountPaid}).`);
        }
        const requestId = text(request.data?.requestId, 80);
        const requestRef = requestId ? db().doc(`cancellations/${requestId}`) : null;
        const requestSnap = requestRef ? await tx.get(requestRef) : null;
        if (requestSnap) {
          if (!requestSnap.exists || requestSnap.data()!.bookingId !== bookingId) {
            throw new HttpsError("not-found", "No such cancellation request for this booking.");
          }
          if (requestSnap.data()!.status !== "pending") {
            throw new HttpsError("failed-precondition", "That request has already been decided.");
          }
        }
        if (refund > 0) addPayment("refund", refund);
        tx.update(ref, {
          stage: "cancelled",
          holdExpiresAt: null,
          cancelReason: text(request.data?.reason, 300),
          amountPaid: Number(b.amountPaid) - refund,
          refundedAmount: refund,
        });
        if (requestRef) {
          tx.update(requestRef, { status: "approved", decidedBy: actor, decidedAt: FieldValue.serverTimestamp(), refundAmount: refund });
        }
        audit(tx, actor, staffUid, "Booking cancelled", `${reference}${refund > 0 ? ` · refund ₹${refund}` : ""}`, bookingId);
        return { stage: "cancelled" };
      }
      case "declineCancellation": {
        const requestId = text(request.data?.requestId, 80);
        if (!requestId) throw new HttpsError("invalid-argument", "requestId is required.");
        const requestRef = db().doc(`cancellations/${requestId}`);
        const requestSnap = await tx.get(requestRef);
        if (!requestSnap.exists || requestSnap.data()!.bookingId !== bookingId) {
          throw new HttpsError("not-found", "No such cancellation request for this booking.");
        }
        if (requestSnap.data()!.status !== "pending") {
          throw new HttpsError("failed-precondition", "That request has already been decided.");
        }
        tx.update(requestRef, {
          status: "declined",
          decidedBy: actor,
          decidedAt: FieldValue.serverTimestamp(),
          decisionNote: text(request.data?.note, 300),
        });
        audit(tx, actor, staffUid, "Cancellation request declined", reference, bookingId);
        return { stage };
      }
      case "reallocate": {
        need(EDITABLE, "move");
        const newBusId = text(request.data?.newBusId, 80);
        if (!newBusId) throw new HttpsError("invalid-argument", "newBusId is required.");
        const start = ms(b.start)!;
        const end = ms(b.end)!;
        const lockRef = db().doc(`busLocks/${newBusId}`);
        const [busSnap, , otherSnap, blackSnap] = await Promise.all([
          tx.get(db().doc(`buses/${newBusId}`)),
          tx.get(lockRef),
          tx.get(db().collection("bookings").where("busId", "==", newBusId).where("end", ">", Timestamp.fromMillis(start))),
          tx.get(db().collection("blackouts").where("busId", "==", newBusId)),
        ]);
        if (!busSnap.exists) throw new HttpsError("not-found", "That bus does not exist.");
        const occupied = otherSnap.docs
          .filter((d) => d.id !== bookingId)
          .map((d) => toOccupied(d, now))
          .filter((o): o is Occupied => o !== null);
        const blackouts = blackSnap.docs.map((d) => ({ busId: newBusId, from: ms(d.data().from) ?? 0, to: ms(d.data().to) ?? 0 }));
        if (!isBusFree(toBus(newBusId, busSnap.data()!), start, end, occupied, blackouts)) {
          throw new HttpsError("failed-precondition", "bus-unavailable");
        }
        tx.set(lockRef, { n: FieldValue.increment(1), at: FieldValue.serverTimestamp() });
        tx.update(ref, {
          busId: newBusId,
          busReg: String(busSnap.data()!.regNumber ?? ""),
          driverName: String(busSnap.data()!.driverName ?? ""),
          capacity: Number(busSnap.data()!.capacity ?? b.capacity),
        });
        audit(tx, actor, staffUid, "Booking moved to another bus", `${reference} · ${b.busReg} → ${busSnap.data()!.regNumber}`, bookingId);
        return { stage };
      }
      default:
        throw new HttpsError("invalid-argument", "Unknown action.");
    }
  });
});

// --- hold expiry ---------------------------------------------------------

/**
 * Releases holds that ran out. Availability already ignores a lapsed hold
 * the moment it lapses; this just records it, so the booking shows as
 * Expired instead of looking pending forever. Returns how many it released.
 */
export async function releaseLapsedHolds(now = Timestamp.now()): Promise<number> {
  const lapsed = await db()
    .collection("bookings")
    .where("stage", "==", "requested")
    .where("holdExpiresAt", "<=", now)
    .limit(400)
    .get();
  if (lapsed.empty) return 0;
  const batch = db().batch();
  for (const d of lapsed.docs) batch.update(d.ref, { stage: "expired" });
  await batch.commit();
  logger.info("expired holds", { count: lapsed.size });
  return lapsed.size;
}

export const expireHolds = onSchedule({ schedule: "every 1 minutes", region: "asia-south1" }, async () => {
  await warnExpiringHolds();
  await releaseLapsedHolds();
});
