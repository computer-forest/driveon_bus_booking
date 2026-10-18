import { getFirestore } from "firebase-admin/firestore";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

/**
 * Staff status is checked against the live staff list on every action, not
 * just the role in the sign-in token. A token keeps saying "staff" for up to
 * an hour after someone is removed; this makes removal take effect at once.
 *
 * Staff accounts are `staff_91XXXXXXXXXX`, and `staff/91XXXXXXXXXX` is the
 * list entry that must exist and be active.
 */
export async function requireActiveStaff(request: CallableRequest): Promise<string> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (request.auth?.token.role !== "admin" || !/^staff_91\d{10}$/.test(uid)) {
    throw new HttpsError("permission-denied", "Staff only.");
  }
  const entry = await getFirestore().doc(`staff/${uid.slice("staff_".length)}`).get();
  if (!entry.exists || entry.data()?.active !== true) {
    throw new HttpsError("permission-denied", "Your staff access has been switched off.");
  }
  return uid;
}
