import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

// Container images are kept by an Artifact Registry policy (keep the newest 2
// per function); never set a delete-everything-older-than policy on gcf-artifacts.
// Mumbai, next to Firestore. The app calls these with the same region.
setGlobalOptions({ region: "asia-south1" });

initializeApp();

export { verifyMsg91Token } from "./verifyMsg91Token";
export { setUserRole } from "./setUserRole";
export { deleteAccount } from "./deleteAccount";
export * from "./audit";
export { searchBuses, createHold, bookingAction, expireHolds } from "./bookings";
export { onBookingWritten, onCancellationRequested, onCancellationDecided } from "./bookingEvents";
