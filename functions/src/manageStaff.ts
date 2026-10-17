import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/**
 * Staff manage who else has staff access (the `staff` allow-list that
 * `verifyMsg91Token` checks at sign-in). The app never writes that list
 * itself: every change goes through here so it can be checked.
 *
 *   in: { action: "add" | "setActive" | "rename", phone, name?, active? }
 *     add        { phone, name }   adds a number, or switches a former member back on
 *     setActive  { phone, active } switches a member off or on
 *     rename     { phone, name }
 *
 * Rules enforced here:
 *  - staff only;
 *  - the phone must be a valid Indian mobile number;
 *  - you cannot switch yourself off, and the last active member cannot be
 *    switched off, so the team can never lock itself out;
 *  - switching someone off also ends their sessions and strips their staff
 *    role, so they stop working on the next token refresh.
 * Every change is written to the audit log with who made it.
 */

const db = () => getFirestore();

/** Digits with country code (91xxxxxxxxxx), or null if not a valid Indian mobile. */
export function normalizePhone(raw: unknown): string | null {
  if (typeof raw !== "string" && typeof raw !== "number") return null;
  let digits = String(raw).replace(/\D/g, "");
  if (digits.startsWith("0")) digits = digits.slice(1);
  if (digits.length === 10) digits = `91${digits}`;
  return /^91[6-9]\d{9}$/.test(digits) ? digits : null;
}

function cleanName(raw: unknown): string {
  return typeof raw === "string" ? raw.trim().replace(/\s+/g, " ").slice(0, 80) : "";
}

export const manageStaff = onCall(async (request) => {
  if (request.auth?.token.role !== "admin") throw new HttpsError("permission-denied", "Staff only.");
  const actorUid = request.auth.uid;
  const action = request.data?.action;
  const phone = normalizePhone(request.data?.phone);
  if (!phone) throw new HttpsError("invalid-argument", "Enter a valid 10-digit mobile number.");
  const target = `staff_${phone}`;
  const ref = db().doc(`staff/${phone}`);

  let actor = "Staff";
  try {
    actor = (await getAuth().getUser(actorUid)).displayName ?? "Staff";
  } catch {
    /* keep the generic name */
  }

  const audit = (act: string, detail: string) =>
    db().collection("auditLog").add({
      actor,
      actorUid,
      action: act,
      detail,
      collection: "staff",
      docId: phone,
      at: FieldValue.serverTimestamp(),
    });

  const masked = `+91 ${phone.slice(2, 7)} ${phone.slice(7)}`;

  if (action === "add") {
    const name = cleanName(request.data?.name);
    if (name.length < 2) throw new HttpsError("invalid-argument", "Enter the person's name.");
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.exists && snap.data()?.active === true) {
        throw new HttpsError("already-exists", "That number already has staff access.");
      }
      tx.set(ref, { name, active: true, addedBy: actorUid, addedAt: FieldValue.serverTimestamp() }, { merge: true });
    });
    await audit("Staff added", `${name} · ${masked}`);
    return { phone, active: true };
  }

  if (action === "rename") {
    const name = cleanName(request.data?.name);
    if (name.length < 2) throw new HttpsError("invalid-argument", "Enter the person's name.");
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "That number is not on the staff list.");
    await ref.update({ name });
    await audit("Staff renamed", `${masked} is now ${name}`);
    return { phone, name };
  }

  if (action === "setActive") {
    const active = request.data?.active;
    if (typeof active !== "boolean") throw new HttpsError("invalid-argument", "active must be true or false.");
    if (!active && target === actorUid) {
      throw new HttpsError("failed-precondition", "You cannot switch off your own access.");
    }
    let name = "";
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "That number is not on the staff list.");
      name = String(snap.data()?.name ?? "");
      if (!active && snap.data()?.active === true) {
        const others = await tx.get(db().collection("staff").where("active", "==", true));
        if (others.docs.filter((d) => d.id !== phone).length === 0) {
          throw new HttpsError("failed-precondition", "At least one person must keep staff access.");
        }
      }
      tx.update(ref, { active });
    });
    if (!active) {
      // End their sessions now; the staff role is stripped so the next token has none.
      try {
        await getAuth().revokeRefreshTokens(target);
        await getAuth().setCustomUserClaims(target, null);
      } catch (e) {
        if ((e as { code?: string }).code !== "auth/user-not-found") logger.warn("could not end staff session", { target });
      }
    }
    await audit(active ? "Staff access restored" : "Staff access removed", `${name} · ${masked}`);
    return { phone, active };
  }

  throw new HttpsError("invalid-argument", "Unknown action.");
});
