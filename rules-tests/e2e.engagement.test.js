// Notifications, hold warnings, cancellation decisions with refunds, and
// account deletion, end to end against the emulators.
const { test, before, after } = require("node:test");
const assert = require("node:assert");
const { initializeApp, deleteApp } = require("firebase/app");
const { getAuth, connectAuthEmulator, signInWithCustomToken } = require("firebase/auth");
const {
  getFirestore, connectFirestoreEmulator, doc, getDoc, getDocs, collection, query, where, setDoc, deleteDoc, Timestamp, serverTimestamp,
} = require("firebase/firestore");
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require("firebase/functions");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

let env;
const apps = [];
let counter = 0;

async function client(phone, audience = "customer") {
  const app = initializeApp({ projectId: "driveon-charter", apiKey: "fake" }, `e${counter++}`);
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, "127.0.0.1", 8085);
  const fns = getFunctions(app, "asia-south1");
  connectFunctionsEmulator(fns, "127.0.0.1", 5001);
  const call = (name, data) => httpsCallable(fns, name)(data).then((r) => r.data);
  const { customToken } = await call("verifyMsg91Token", { accessToken: "fake-access-token-x", phone, audience });
  await signInWithCustomToken(auth, customToken);
  return { auth, db, call, uid: auth.currentUser.uid };
}

const dayOffset = (n) => new Date(Date.now() + 5.5 * 3600 * 1000 + n * 86400 * 1000).toISOString().slice(0, 10);
const when = (n, hhmm) => `${dayOffset(n)}T${hhmm}`;
const allDays = Array.from({ length: 7 }, () => ({ available: true, start: 360, end: 1380 }));
const bus = (id, extra = {}) => ({
  regNumber: `REG-${id}`, vendorId: "ven-ok", vendorName: "V", capacity: 20, seatType: "x", ac: true, baseCity: "Thane",
  driverName: "Suresh Patil", active: true, weeklyAvailability: allDays, amenities: [], photoCount: 0, updatedBy: "system:seed", ...extra,
});

const seed = async (fn) => {
  let out;
  await env.withSecurityRulesDisabled(async (ctx) => { out = await fn(ctx.firestore()); });
  return out;
};
const put = (path, data) => seed((db) => setDoc(doc(db, path), data));
const read = (path) => seed((db) => getDoc(doc(db, path)));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function reset() {
  await env.clearFirestore();
  await put("staff/919820000001", { name: "Priya", active: true });
  await put("vendors/ven-ok", { name: "V", active: true, updatedBy: "system:seed" });
}

/** A person's inbox, oldest first, once it has at least [count] entries. */
async function inbox(c, count) {
  for (let i = 0; i < 60; i++) {
    const snap = await getDocs(query(collection(c.db, "notifications"), where("userId", "==", c.uid)));
    if (snap.size >= count) return snap.docs.map((d) => d.data()).sort((a, b) => a.createdAt.toMillis() - b.createdAt.toMillis());
    await sleep(250);
  }
  const snap = await getDocs(query(collection(c.db, "notifications"), where("userId", "==", c.uid)));
  return snap.docs.map((d) => d.data());
}

const rejectsWith = (p, code, message) =>
  assert.rejects(p, (e) => e.code === `functions/${code}` && (message === undefined || e.message === message), `expected ${code} ${message ?? ""}`);

before(async () => {
  env = await initializeTestEnvironment({ projectId: "driveon-charter", firestore: { host: "127.0.0.1", port: 8085 } });
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8085";
});
after(async () => {
  await env.cleanup();
  await Promise.all(apps.map(deleteApp));
});

test("a booking's life produces the right notifications for the customer, and staff are alerted to new requests", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  await put("buses/b2", bus("b2", { driverName: "Ramesh Jadhav" }));
  const c = await client("9820055001");
  const staff = await client("9820000001", "staff");

  const hold = await c.call("createHold", { busId: "b1", startsAt: when(40, "10:00"), endsAt: when(40, "16:00"), route: "Thane → Lonavala" });
  const act = (action, extra = {}) => staff.call("bookingAction", { bookingId: hold.bookingId, action, ...extra });
  await act("confirmCost", { fare: 18000 });
  await act("recordAdvance", { amount: 4500 });
  await act("reallocate", { newBusId: "b2" });
  await act("startTrip");
  await act("completeTrip");
  await act("recordBalance", { amount: 13500 });

  const mine = await inbox(c, 7);
  assert.deepEqual(mine.map((n) => n.kind), [
    "hold-created", "cost-confirmed", "confirmed", "reallocated", "trip-started", "trip-completed", "settled",
  ]);
  const byKind = Object.fromEntries(mine.map((n) => [n.kind, n]));
  assert.match(byKind["hold-created"].body, /CB-\d{8}-0001/);
  assert.equal(byKind["cost-confirmed"].body, "Total fare for your Thane → Lonavala trip is ₹18,000. Advance due: ₹4,500.");
  assert.match(byKind["confirmed"].body, /Your bus is confirmed! REG-b1, driver Suresh Patil/);
  assert.match(byKind["reallocated"].body, /changed to REG-b2\. Driver: Ramesh Jadhav/);
  assert.ok(mine.every((n) => n.read === false && n.bookingId === hold.bookingId && n.userId === c.uid));
  assert.equal(byKind["confirmed"].tone, "success");

  const staffInbox = await inbox(staff, 1);
  const request = staffInbox.find((n) => n.kind === "staff-new-request");
  assert.ok(request, "staff were told about the new request");
  assert.match(request.body, /Thane → Lonavala/);
});

test("a customer can read their own notifications but not another person's", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const a = await client("9820055002");
  const b = await client("9820055003");
  await a.call("createHold", { busId: "b1", startsAt: when(41, "10:00"), endsAt: when(41, "16:00"), route: "A → B" });
  const mine = await inbox(a, 1);
  assert.equal(mine.length, 1);
  assert.equal((await inbox(b, 0)).length, 0);
  const snap = await getDocs(query(collection(a.db, "notifications"), where("userId", "==", a.uid)));
  await assert.rejects(getDoc(doc(b.db, `notifications/${snap.docs[0].id}`)));
});

test("staff-edited templates with placeholders are used; an old example sentence is not a template", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  await put("templates/tpl-cost", { name: "Cost confirmed", preview: "Fare {fare} for {route}; pay {advance} to confirm {reference}.", updatedBy: "system:seed" });
  await put("templates/tpl-confirmed", { name: "Booking confirmed", preview: "Your bus is confirmed! MH-04-BT-7781, driver Suresh Patil...", updatedBy: "system:seed" });
  const c = await client("9820055004");
  const staff = await client("9820000001", "staff");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(42, "10:00"), endsAt: when(42, "16:00"), route: "A → B" });
  await staff.call("bookingAction", { bookingId: hold.bookingId, action: "confirmCost", fare: 20000 });
  await staff.call("bookingAction", { bookingId: hold.bookingId, action: "recordAdvance", amount: 5000 });
  const mine = await inbox(c, 3);
  const cost = mine.find((n) => n.kind === "cost-confirmed");
  assert.match(cost.body, /^Fare ₹20,000 for A → B; pay ₹5,000 to confirm CB-\d{8}-0001\.$/);
  assert.equal(mine.find((n) => n.kind === "confirmed").body, "Your bus is confirmed! REG-b1, driver Suresh Patil. Booking " + hold.reference + ".");
});

test("the same event delivered twice makes one notification", async () => {
  await reset();
  const { initializeApp: initAdmin, getApps } = require("node:module").createRequire(require("node:path").join(__dirname, "../functions/package.json"))("firebase-admin/app");
  if (getApps().length === 0) initAdmin({ projectId: "driveon-charter" });
  const { notify } = require("../functions/lib/notifications.js");
  const note = { title: "T", body: "B", tone: "info", kind: "test" };
  await notify("evt-1", ["cust_919820055005"], note);
  await notify("evt-1", ["cust_919820055005", null, "deleted"], note);
  const snap = await seed((db) => getDocs(query(collection(db, "notifications"), where("userId", "==", "cust_919820055005"))));
  assert.equal(snap.size, 1);
});

test("a failing push never blocks the notification (a phone is registered but FCM is unreachable here)", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820055006");
  await setDoc(doc(c.db, `users/${c.uid}/devices/fake-token-123`), { platform: "android", updatedAt: serverTimestamp() });
  await c.call("createHold", { busId: "b1", startsAt: when(43, "10:00"), endsAt: when(43, "16:00"), route: "A → B" });
  assert.equal((await inbox(c, 1)).length, 1);
});

test("a hold about to lapse warns staff and the customer once", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820055007");
  const staff = await client("9820000001", "staff");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(44, "10:00"), endsAt: when(44, "16:00"), route: "A → B" });
  await inbox(c, 1); await inbox(staff, 1);
  await seed((db) => setDoc(doc(db, `bookings/${hold.bookingId}`), { holdExpiresAt: Timestamp.fromMillis(Date.now() + 3 * 60000) }, { merge: true }));

  const { warnExpiringHolds } = require("../functions/lib/bookingEvents.js");
  assert.equal(await warnExpiringHolds(), 1);
  assert.equal(await warnExpiringHolds(), 0, "each hold is warned about once");

  const mine = await inbox(c, 2);
  assert.ok(mine.some((n) => n.kind === "hold-expiring" && /3 minutes/.test(n.body)));
  const theirs = await inbox(staff, 2);
  assert.ok(theirs.some((n) => n.kind === "staff-hold-expiring" && n.body.includes(hold.reference)));
});

test("an expired hold tells the customer", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820055008");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(45, "10:00"), endsAt: when(45, "16:00"), route: "A → B" });
  await inbox(c, 1);
  await seed((db) => setDoc(doc(db, `bookings/${hold.bookingId}`), { holdExpiresAt: Timestamp.fromMillis(Date.now() - 1000) }, { merge: true }));
  const { releaseLapsedHolds } = require("../functions/lib/bookings.js");
  assert.equal(await releaseLapsedHolds(), 1);
  const mine = await inbox(c, 2);
  assert.ok(mine.some((n) => n.kind === "hold-expired"));
});

test("cancellation: a customer asks, staff are told, approval refunds and cancels, and a second decision is refused", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820055009");
  const staff = await client("9820000001", "staff");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(46, "10:00"), endsAt: when(46, "16:00"), route: "A → B" });
  const act = (action, extra = {}) => staff.call("bookingAction", { bookingId: hold.bookingId, action, ...extra });
  await act("confirmCost", { fare: 18000 });
  await act("recordAdvance", { amount: 4500 });

  await setDoc(doc(c.db, "cancellations/req-1"), {
    bookingId: hold.bookingId, requestedBy: c.uid, reason: "Plans changed", status: "pending", createdAt: serverTimestamp(),
  });
  const staffInbox = await inbox(staff, 2);
  assert.ok(staffInbox.some((n) => n.kind === "staff-cancellation-request" && /Plans changed/.test(n.body)));

  await rejectsWith(act("cancel", { requestId: "req-1", refundAmount: 9999 }), "failed-precondition");
  await rejectsWith(act("cancel", { requestId: "req-nope", refundAmount: 0 }), "not-found");
  await act("cancel", { requestId: "req-1", refundAmount: 3000, mode: "UPI", reference: "R-1", reason: "Customer asked" });

  const booking = (await read(`bookings/${hold.bookingId}`)).data();
  assert.equal(booking.stage, "cancelled");
  assert.equal(booking.amountPaid, 1500);
  assert.equal(booking.refundedAmount, 3000);
  const req = (await read("cancellations/req-1")).data();
  assert.equal(req.status, "approved");
  assert.equal(req.refundAmount, 3000);
  assert.equal(req.decidedBy, "Priya");
  const payments = await seed((db) => getDocs(query(collection(db, "payments"), where("bookingId", "==", hold.bookingId))));
  assert.deepEqual(payments.docs.map((d) => `${d.data().kind}:${d.data().amount}`).sort(), ["advance:4500", "refund:3000"]);

  const mine = await inbox(c, 4);
  const cancelled = mine.find((n) => n.kind === "cancelled");
  assert.match(cancelled.body, /cancelled\. A refund of ₹3,000 has been recorded\./);

  await rejectsWith(act("cancel", { requestId: "req-1" }), "failed-precondition"); // already cancelled
  // the bus is free again
  assert.deepEqual((await c.call("searchBuses", { startsAt: when(46, "10:00"), endsAt: when(46, "16:00") })).busIds, ["b1"]);
});

test("cancellation: declining keeps the booking and tells the customer why; it cannot be declined twice", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820055010");
  const staff = await client("9820000001", "staff");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(47, "10:00"), endsAt: when(47, "16:00"), route: "A → B" });
  const act = (action, extra = {}) => staff.call("bookingAction", { bookingId: hold.bookingId, action, ...extra });
  await act("confirmCost", { fare: 10000 });
  await act("recordAdvance", { amount: 2500 });
  await setDoc(doc(c.db, "cancellations/req-2"), { bookingId: hold.bookingId, requestedBy: c.uid, reason: "x", status: "pending", createdAt: serverTimestamp() });

  await act("declineCancellation", { requestId: "req-2", note: "The vendor already scheduled the driver." });
  assert.equal((await read(`bookings/${hold.bookingId}`)).data().stage, "confirmed");
  assert.equal((await read("cancellations/req-2")).data().status, "declined");
  const mine = await inbox(c, 4);
  const declined = mine.find((n) => n.kind === "cancellation-declined");
  assert.ok(declined);
  assert.match(declined.body, /The vendor already scheduled the driver\./);
  await rejectsWith(act("declineCancellation", { requestId: "req-2" }), "failed-precondition", "That request has already been decided.");
  await rejectsWith(c.call("bookingAction", { bookingId: hold.bookingId, action: "declineCancellation", requestId: "req-2" }), "permission-denied");
});

test("deleting an account: refused with a booking in progress", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820055011");
  await c.call("createHold", { busId: "b1", startsAt: when(48, "10:00"), endsAt: when(48, "16:00"), route: "A → B" });
  await rejectsWith(c.call("deleteAccount", {}), "failed-precondition", "You have bookings in progress. Once they are completed or cancelled you can delete your account.");
  assert.ok((await read(`users/${c.uid}`)) !== undefined);
});

test("deleting an account erases the person, anonymises their bookings, and keeps the money", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820055012");
  const staff = await client("9820000001", "staff");
  await put(`users/${c.uid}`, { name: "Rohan Deshmukh", email: "r@example.com", phone: "98200 55012" });
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(49, "10:00"), endsAt: when(49, "16:00"), route: "A → B", pickupLandmark: "Behind the red temple" });
  const act = (action, extra = {}) => staff.call("bookingAction", { bookingId: hold.bookingId, action, ...extra });
  await act("confirmCost", { fare: 12000 });
  await act("recordAdvance", { amount: 3000 });
  await act("startTrip"); await act("completeTrip"); await act("recordBalance", { amount: 9000 });
  await setDoc(doc(c.db, "ratings/rate-1"), { bookingId: hold.bookingId, bus: 5, driver: 5, overall: 5, feedback: "Lovely, call me on 98200 55012", customerId: c.uid, createdAt: serverTimestamp() });
  await setDoc(doc(c.db, `users/${c.uid}/recents/loc-1`), { at: serverTimestamp() });
  await inbox(c, 5);

  await c.call("deleteAccount", {});

  const booking = (await read(`bookings/${hold.bookingId}`)).data();
  assert.equal(booking.customerId, "deleted");
  assert.equal(booking.customerName, "Deleted customer");
  assert.equal(booking.customerPhone, "");
  assert.equal(booking.pickupLandmark, null);
  assert.equal(booking.stage, "settled");
  assert.equal(booking.totalFare, 12000);
  assert.equal(booking.amountPaid, 12000);
  assert.equal(booking.reference, hold.reference);

  const payments = await seed((db) => getDocs(query(collection(db, "payments"), where("bookingId", "==", hold.bookingId))));
  assert.deepEqual(payments.docs.map((d) => d.data().amount).sort((a, b) => a - b), [3000, 9000]);

  assert.equal((await read(`users/${c.uid}`)).exists(), false);
  assert.equal((await read(`users/${c.uid}/recents/loc-1`)).exists(), false);
  const rating = (await read("ratings/rate-1")).data();
  assert.equal(rating.customerId, "deleted");
  assert.equal(rating.feedback, "");
  assert.equal(rating.overall, 5);
  const notes = await seed((db) => getDocs(query(collection(db, "notifications"), where("userId", "==", c.uid))));
  assert.equal(notes.size, 0);
  // and the login itself is gone: signing in with the same number makes a brand-new, empty account
  const again = await client("9820055012");
  assert.equal((await read(`users/${again.uid}`)).exists(), false);
});

test("staff cannot delete their account this way", async () => {
  await reset();
  const staff = await client("9820000001", "staff");
  await rejectsWith(staff.call("deleteAccount", {}), "permission-denied");
});
