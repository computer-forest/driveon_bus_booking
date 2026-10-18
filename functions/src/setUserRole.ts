import { getAuth } from "firebase-admin/auth";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { requireActiveStaff } from "./staffGuard";

/**
 * Admin-only: sets another user's role claim.
 *
 *   in: { uid: string, role: "admin" | "customer" }
 *
 * Staff normally get the admin role at sign-in, from the `staff` allow-list
 * (see verifyMsg91Token); this is for exceptions.
 */
export const setUserRole = onCall(async (request) => {
  const actorUid = await requireActiveStaff(request);
  const { uid, role } = request.data ?? {};
  if (typeof uid !== "string" || (role !== "admin" && role !== "customer")) {
    throw new HttpsError("invalid-argument", "uid and a role of admin or customer are required.");
  }
  if (uid === actorUid) {
    throw new HttpsError("failed-precondition", "You cannot change your own role.");
  }
  await getAuth().setCustomUserClaims(uid, { role });
  return { uid, role };
});
