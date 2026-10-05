import { getAuth } from "firebase-admin/auth";
import { HttpsError, onCall } from "firebase-functions/v2/https";

/**
 * Admin-only: sets another user's role claim.
 *
 *   in: { uid: string, role: "admin" | "customer" }
 *
 * The first admin cannot come from here (there is nobody to call it); use
 * `npm run create-admin`.
 */
export const setUserRole = onCall(async (request) => {
  if (request.auth?.token.role !== "admin") {
    throw new HttpsError("permission-denied", "Only an admin can change roles.");
  }
  const { uid, role } = request.data ?? {};
  if (typeof uid !== "string" || (role !== "admin" && role !== "customer")) {
    throw new HttpsError("invalid-argument", "uid and a role of admin or customer are required.");
  }
  if (uid === request.auth.uid) {
    throw new HttpsError("failed-precondition", "You cannot change your own role.");
  }
  await getAuth().setCustomUserClaims(uid, { role });
  return { uid, role };
});
