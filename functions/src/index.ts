import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

// Container images are kept by an Artifact Registry policy (keep the newest 2
// per function); never set a delete-everything-older-than policy on gcf-artifacts.
// Mumbai, next to Firestore. The app calls these with the same region.
// Cost: a sixth of a vCPU per instance (the 1st-gen size) is plenty for this
// traffic and bills about six times less CPU time than the 2nd-gen default
// of one vCPU; instances then take one request at a time. maxInstances caps
// what a bug or a flood of requests could ever cost.
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
