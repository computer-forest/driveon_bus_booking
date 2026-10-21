import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { interactive } from "./options";

/** Stages from which a booking will not change again. */
const FINISHED = new Set(["settled", "expired", "cancelled"]);

/**
 * Erases the signed-in customer's personal data (AUTH-09) and their login.
 *
 *  - Refused while any booking is still in progress, so nobody loses a
 *    trip, a hold or a balance they owe by deleting the account.
 *  - Bookings stay for operations and accounting but are anonymised: no
 *    name, phone, pickup landmark or link back to the person. Payments (the
 *    financial record) are kept untouched.
 *  - Ratings and cancellation requests lose their link and free text; search
 *    logs lose the link; notifications, devices, recent searches and the
 *    profile are deleted.
 *
 * Staff accounts cannot be removed this way.
 */
export const deleteAccount = onCall(interactive, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (request.auth?.token.role === "admin") {
    throw new HttpsError("permission-denied", "Staff accounts are removed by another admin.");
  }
  const db = getFirestore();

  const bookings = await db.collection("bookings").where("customerId", "==", uid).get();
  const open = bookings.docs.filter((d) => !FINISHED.has(String(d.data().stage)));
  if (open.length > 0) {
    throw new HttpsError(
      "failed-precondition",
      "You have bookings in progress. Once they are completed or cancelled you can delete your account.",
    );
  }

  const [ratings, requests, misses, notifications] = await Promise.all([
    db.collection("ratings").where("customerId", "==", uid).get(),
    db.collection("cancellations").where("requestedBy", "==", uid).get(),
    db.collection("searchMisses").where("customerId", "==", uid).get(),
    db.collection("notifications").where("userId", "==", uid).get(),
  ]);

  const writer = db.bulkWriter();
  for (const d of bookings.docs) {
    writer.update(d.ref, { customerId: "deleted", customerName: "Deleted customer", customerPhone: "", pickupLandmark: null });
  }
  for (const d of ratings.docs) writer.update(d.ref, { customerId: "deleted", feedback: "" });
  for (const d of requests.docs) writer.update(d.ref, { requestedBy: "deleted", reason: "" });
  for (const d of misses.docs) writer.update(d.ref, { customerId: "deleted" });
  for (const d of notifications.docs) writer.delete(d.ref);
  await writer.close();

  // The profile and its subcollections (recent searches, devices).
  await db.recursiveDelete(db.doc(`users/${uid}`));
  await getAuth().deleteUser(uid);

  logger.info("account deleted", { bookings: bookings.size });
  return { deleted: true, bookingsAnonymised: bookings.size };
});
