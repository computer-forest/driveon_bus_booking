import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions/v2";

/**
 * In-app notifications and push.
 *
 * Every notification is a `notifications/{eventId}_{uid}` document (the
 * in-app inbox) plus, if the person has registered a device, an FCM push.
 * The document id is derived from the triggering event, so a trigger that is
 * delivered twice (Firestore triggers are at-least-once) creates one inbox
 * entry and sends one push.
 */

const db = () => getFirestore();

export type Tone = "info" | "success" | "warning" | "urgent";

export interface Note {
  title: string;
  body: string;
  tone: Tone;
  bookingId?: string;
  kind: string;
}

/** Replaces {placeholders}; an unknown one is left as written. */
export function render(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (whole, key: string) => (key in vars ? String(vars[key]) : whole));
}

/** 18000 -> "₹18,000", 1234567 -> "₹12,34,567" (Indian grouping). */
export function rupees(amount: number): string {
  const digits = String(Math.round(amount));
  if (digits.length <= 3) return `₹${digits}`;
  const last3 = digits.slice(-3);
  const rest = digits.slice(0, -3).replace(/\B(?=(\d{2})+(?!\d))/g, ",");
  return `₹${rest},${last3}`;
}

/** The staff-editable text for a template, if it uses placeholders; otherwise
 *  [fallback] (an old example sentence is not a template). */
export async function templateText(id: string, fallback: string): Promise<string> {
  try {
    const text = (await db().doc(`templates/${id}`).get()).data()?.preview;
    return typeof text === "string" && /\{\w+\}/.test(text) ? text : fallback;
  } catch {
    return fallback;
  }
}

/** Uids of everyone currently on the active staff list. */
export async function staffUids(): Promise<string[]> {
  const snap = await db().collection("staff").where("active", "==", true).get();
  return snap.docs.map((d) => `staff_${d.id}`);
}

/**
 * The notifications a customer may switch off as phone pushes. Everything
 * else (fares, confirmations, cancellations, bus changes, staff alerts) is
 * always pushed. The in-app inbox keeps every message either way.
 */
export const PUSH_GROUPS: Record<string, string> = {
  "hold-created": "reminders",
  "hold-expiring": "reminders",
  "hold-expired": "reminders",
  "trip-started": "tripUpdates",
  "trip-completed": "tripUpdates",
  settled: "tripUpdates",
};

/** True unless this person switched off the push group [kind] belongs to. */
export async function pushWanted(uid: string, kind: string): Promise<boolean> {
  const group = PUSH_GROUPS[kind];
  if (!group) return true;
  try {
    const prefs = (await db().doc(`users/${uid}/prefs/push`).get()).data();
    return prefs?.[group] !== false;
  } catch {
    return true;
  }
}

async function push(uid: string, note: Note): Promise<void> {
  try {
    if (!(await pushWanted(uid, note.kind))) return;
    const devices = await db().collection(`users/${uid}/devices`).get();
    const tokens = devices.docs.map((d) => d.id);
    if (tokens.length === 0) return;
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: note.title, body: note.body },
      data: { kind: note.kind, ...(note.bookingId ? { bookingId: note.bookingId } : {}) },
      android: { priority: "high", notification: { channelId: "default" } },
    });
    // Forget devices that no longer exist so they are not tried again.
    const dead = res.responses
      .map((r, i) => (!r.success && /registration-token-not-registered|invalid-argument/.test(r.error?.code ?? "") ? tokens[i] : null))
      .filter((t): t is string => t !== null);
    await Promise.all(dead.map((t) => db().doc(`users/${uid}/devices/${t}`).delete()));
  } catch (e) {
    // A failed push must never fail the booking change that caused it.
    logger.warn("push failed", { uid, error: String(e) });
  }
}

/** Sends [note] to each of [uids]. Safe to call twice for the same [eventKey]. */
export async function notify(eventKey: string, uids: Array<string | null | undefined>, note: Note): Promise<void> {
  const unique = [...new Set(uids.filter((u): u is string => !!u && u !== "deleted"))];
  await Promise.all(
    unique.map(async (uid) => {
      try {
        await db().doc(`notifications/${eventKey}_${uid}`).create({
          userId: uid,
          title: note.title,
          body: note.body,
          tone: note.tone,
          kind: note.kind,
          bookingId: note.bookingId ?? null,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      } catch (e) {
        if ((e as { code?: number }).code === 6) return; // already sent for this event
        throw e;
      }
      await push(uid, note);
    }),
  );
}
