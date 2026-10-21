import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

// Container images are kept by an Artifact Registry policy (keep the newest 2
// per function); never set a delete-everything-older-than policy on gcf-artifacts.
// Mumbai, next to Firestore. The app calls these with the same region.
// Background work (sweeps, audit and notification triggers, photo cleanup)
// runs on a sixth of a vCPU per instance to keep idle cost down, and the
// number of instances is capped so a bug cannot run up a large bill. Calls a
// person waits on override this with a full vCPU (see options.ts).
setGlobalOptions({ region: "asia-south1", cpu: "gcf_gen1", maxInstances: 10 });

initializeApp();

export { verifyMsg91Token } from "./verifyMsg91Token";
export { setUserRole } from "./setUserRole";
export { deleteAccount } from "./deleteAccount";
export * from "./audit";
export { searchBuses, createHold, bookingAction, expireHolds } from "./bookings";
export { onBookingWritten, onCancellationRequested, onCancellationDecided } from "./bookingEvents";
export { cleanBusPhotos, sweepBusPhotos } from "./busPhotos";
export { manageStaff } from "./manageStaff";
