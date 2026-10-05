import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/**
 * Erases the signed-in customer's personal data (AUTH-09): the profile and
 * the sign-in itself. Staff accounts cannot be removed this way.
 *
 * Booking anonymisation and retention of financial records land with the
 * bookings collection in Stage 4; until then there is nothing else to touch.
 */
export const deleteAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (request.auth?.token.role === "admin") {
    throw new HttpsError("permission-denied", "Staff accounts are removed by another admin.");
  }
  await getFirestore().doc(`users/${uid}`).delete();
  await getAuth().deleteUser(uid);
  return { deleted: true };
});
