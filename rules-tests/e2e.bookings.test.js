// Search, holds, the staff lifecycle and hold expiry, end to end against the
// emulators (auth + functions + firestore). The important test is the race:
// many customers trying to hold the same bus at once, exactly one wins.
const { test, before, after } = require("node:test");
const assert = require("node:assert");
const { initializeApp, deleteApp } = require("firebase/app");
const { getAuth, connectAuthEmulator, signInWithCustomToken } = require("firebase/auth");
const { getFirestore, connectFirestoreEmulator, doc, getDoc, getDocs, collection, query, where } = require("firebase/firestore");
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require("firebase/functions");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");
const { Timestamp } = require("firebase/firestore");

let env;
const apps = [];
let counter = 0;

/** A signed-in client of the given kind: its own app, auth, firestore, functions. */
async function client(phone, audience = "customer") {
  const app = initializeApp({ projectId: "driveon-charter", apiKey: "fake" }, `c${counter++}`);
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

const dayOffset = (n) => {
  const d = new Date(Date.now() + 5.5 * 3600 * 1000 + n * 86400 * 1000); // India date
  return d.toISOString().slice(0, 10);
};
const when = (n, hhmm) => `${dayOffset(n)}T${hhmm}`;

const allDays = Array.from({ length: 7 }, () => ({ available: true, start: 6 * 60, end: 23 * 60 }));
const bus = (id, extra = {}) => ({
  regNumber: `REG-${id}`, vendorId: "ven-ok", vendorName: "Vendor", capacity: 20, seatType: "x", ac: true, baseCity: "Thane",
  driverName: "Driver", active: true, weeklyAvailability: allDays, amenities: [], photoCount: 0, updatedBy: "system:seed", ...extra,
});

const seed = async (fn) => {
  let out;
  await env.withSecurityRulesDisabled(async (ctx) => {
    out = await fn(ctx.firestore());
  });
  return out;
};
const { setDoc, deleteDoc } = require("firebase/firestore");
const put = (path, data) => seed((db) => setDoc(doc(db, path), data));
const readDoc = (path) => seed((db) => getDoc(doc(db, path)));
const clearCollection = (name) => seed(async (db) => { for (const d of (await getDocs(collection(db, name))).docs) await deleteDoc(d.ref); });

async function reset() {
  await env.clearFirestore();
  await put("staff/919820000001", { name: "Priya", active: true });
  await put("vendors/ven-ok", { name: "Vendor", active: true, updatedBy: "system:seed" });
  await put("vendors/ven-off", { name: "Closed Vendor", active: false, updatedBy: "system:seed" });
}

before(async () => {
  env = await initializeTestEnvironment({ projectId: "driveon-charter", firestore: { host: "127.0.0.1", port: 8085 } });
});
after(async () => {
  await env.cleanup();
  await Promise.all(apps.map(deleteApp));
});

const rejectsWith = (promise, code, message) =>
  assert.rejects(promise, (e) => e.code === `functions/${code}` && (message === undefined || e.message === message), `expected ${code} ${message ?? ""}`);

test("search returns only buses that are really free for the trip", async () => {
  await reset();
  await put("buses/free", bus("free"));
  await put("buses/inactive", bus("inactive", { active: false }));
  await put("buses/offvendor", bus("offvendor", { vendorId: "ven-off" }));
  await put("buses/small", bus("small", { capacity: 10 }));
  await put("buses/closed", bus("closed", { weeklyAvailability: allDays.map(() => ({ available: false, start: 360, end: 1380 })) }));
  await put("buses/black", bus("black"));
  await put("blackouts/b1", { busId: "black", busReg: "x", reason: "Service", from: Timestamp.fromDate(new Date(`${dayOffset(20)}T00:00:00+05:30`)), to: Timestamp.fromDate(new Date(`${dayOffset(20)}T00:00:00+05:30`)), updatedBy: "system:seed" });
  await put("buses/late", bus("late", { weeklyAvailability: allDays.map(() => ({ available: true, start: 14 * 60, end: 22 * 60 })) }));

  const c = await client("9820011001");
  const out = await c.call("searchBuses", { startsAt: when(20, "10:00"), endsAt: when(20, "18:00"), capacity: 15 });
  assert.deepEqual(out.busIds.sort(), ["free"]); // 'late' opens at 14:00, 'small' is too small, others are ruled out

  const wide = await c.call("searchBuses", { startsAt: when(20, "15:00"), endsAt: when(20, "20:00") });
  assert.deepEqual(wide.busIds.sort(), ["free", "late", "small"]); // blackout, closed, inactive and the closed vendor stay out
});

test("a search that finds nothing is logged for the failed-searches report", async () => {
  await reset();
  const c = await client("9820011002");
  const out = await c.call("searchBuses", { startsAt: when(21, "10:00"), endsAt: when(21, "12:00") });
  assert.deepEqual(out.busIds, []);
  const misses = await seed((db) => getDocs(collection(db, "searchMisses")));
  assert.equal(misses.size, 1);
});

test("holding a bus creates a stamped hold the customer can read, and takes it out of search", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  await put("users/cust_919820011003", { name: "Rohan", email: "", phone: "98200 11003" });
  const c = await client("9820011003");

  const hold = await c.call("createHold", { busId: "b1", startsAt: when(22, "10:00"), endsAt: when(22, "16:00"), route: "Thane West → Lonavala", pickupLandmark: "Near the station" });
  assert.match(hold.reference, /^CB-\d{8}-0001$/);

  const snap = await getDoc(doc(c.db, `bookings/${hold.bookingId}`));
  const b = snap.data();
  assert.equal(b.stage, "requested");
  assert.equal(b.customerId, c.uid);
  assert.equal(b.customerName, "Rohan");
  assert.equal(b.busReg, "REG-b1");
  assert.equal(b.route, "Thane West → Lonavala");
  const minutesLeft = (b.holdExpiresAt.toMillis() - Date.now()) / 60000;
  assert.ok(minutesLeft > 28 && minutesLeft <= 30, `hold should run about 30 minutes, ran ${minutesLeft}`);

  const other = await client("9820011004");
  assert.deepEqual((await other.call("searchBuses", { startsAt: when(22, "12:00"), endsAt: when(22, "14:00") })).busIds, []);
  assert.deepEqual((await other.call("searchBuses", { startsAt: when(22, "16:00"), endsAt: when(22, "20:00") })).busIds, ["b1"]); // back to back is fine
  assert.deepEqual((await other.call("searchBuses", { startsAt: when(23, "10:00"), endsAt: when(23, "16:00") })).busIds, ["b1"]);

  await assert.rejects(getDoc(doc(other.db, `bookings/${hold.bookingId}`))); // not their booking
});

test("references count up through the day", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  await put("buses/b2", bus("b2"));
  const c = await client("9820011005");
  const first = await c.call("createHold", { busId: "b1", startsAt: when(24, "10:00"), endsAt: when(24, "12:00"), route: "A → B" });
  const second = await c.call("createHold", { busId: "b2", startsAt: when(24, "10:00"), endsAt: when(24, "12:00"), route: "A → B" });
  assert.match(first.reference, /-0001$/);
  assert.match(second.reference, /-0002$/);
});

test("THE RACE: eight customers hold the same bus at the same moment, exactly one gets it", async () => {
  await reset();
  await put("buses/contested", bus("contested"));
  const customers = await Promise.all(Array.from({ length: 8 }, (_, i) => client(`98200220${String(i).padStart(2, "0")}`)));

  const results = await Promise.allSettled(
    customers.map((c) => c.call("createHold", { busId: "contested", startsAt: when(25, "10:00"), endsAt: when(25, "16:00"), route: "A → B" })),
  );

  const won = results.filter((r) => r.status === "fulfilled");
  const lost = results.filter((r) => r.status === "rejected");
  assert.equal(won.length, 1, `exactly one hold should succeed, ${won.length} did`);
  assert.equal(lost.length, 7);
  for (const r of lost) {
    assert.equal(r.reason.code, "functions/failed-precondition");
    assert.equal(r.reason.message, "bus-unavailable");
  }
  const bookings = await seed((db) => getDocs(query(collection(db, "bookings"), where("busId", "==", "contested"))));
  assert.equal(bookings.size, 1, "only one booking exists for the bus");
});

test("THE RACE, with overlapping (not identical) windows: still exactly one", async () => {
  await reset();
  await put("buses/contested", bus("contested"));
  const customers = await Promise.all(Array.from({ length: 6 }, (_, i) => client(`98200330${String(i).padStart(2, "0")}`)));
  const windows = [["08:00", "12:00"], ["11:00", "15:00"], ["14:00", "18:00"], ["09:00", "17:00"], ["10:00", "11:30"], ["12:00", "13:00"]];
  const results = await Promise.allSettled(
    customers.map((c, i) => c.call("createHold", { busId: "contested", startsAt: when(26, windows[i][0]), endsAt: when(26, windows[i][1]), route: "A → B" })),
  );
  // Some windows do not overlap each other, so more than one can win, but the winners must never overlap.
  const winners = results.map((r, i) => (r.status === "fulfilled" ? windows[i] : null)).filter(Boolean);
  assert.ok(winners.length >= 1);
  for (let i = 0; i < winners.length; i++)
    for (let j = i + 1; j < winners.length; j++) {
      const [aS, aE] = winners[i], [bS, bE] = winners[j];
      assert.ok(!(aS < bE && bS < aE), `winners ${winners[i]} and ${winners[j]} overlap`);
    }
});

test("a customer can hold only a few buses at once", async () => {
  await reset();
  for (const id of ["a", "b", "c", "d"]) await put(`buses/${id}`, bus(id));
  const c = await client("9820011006");
  for (const id of ["a", "b", "c"]) await c.call("createHold", { busId: id, startsAt: when(27, "10:00"), endsAt: when(27, "12:00"), route: "A → B" });
  await rejectsWith(c.call("createHold", { busId: "d", startsAt: when(27, "10:00"), endsAt: when(27, "12:00"), route: "A → B" }), "resource-exhausted");
});

test("bad requests are refused", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820011007");
  await rejectsWith(c.call("createHold", { busId: "missing", startsAt: when(28, "10:00"), endsAt: when(28, "12:00"), route: "x" }), "not-found");
  await rejectsWith(c.call("createHold", { busId: "b1", startsAt: when(28, "12:00"), endsAt: when(28, "10:00"), route: "x" }), "invalid-argument");
  await rejectsWith(c.call("createHold", { busId: "b1", startsAt: when(-3, "10:00"), endsAt: when(-3, "12:00"), route: "x" }), "invalid-argument");
  await rejectsWith(c.call("createHold", { busId: "b1", startsAt: "nonsense", endsAt: "nonsense", route: "x" }), "invalid-argument");
  await rejectsWith(c.call("createHold", { busId: "b1", startsAt: when(28, "03:00"), endsAt: when(28, "12:00"), route: "x" }), "failed-precondition", "bus-unavailable"); // before the window opens
});

test("a deactivated vendor's bus cannot be held even if the app still shows it", async () => {
  await reset();
  await put("buses/off", bus("off", { vendorId: "ven-off" }));
  const c = await client("9820011008");
  await rejectsWith(c.call("createHold", { busId: "off", startsAt: when(29, "10:00"), endsAt: when(29, "12:00"), route: "x" }), "failed-precondition", "bus-unavailable");
});

test("staff cannot hold a bus; customers cannot run staff actions", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const staff = await client("9820000001", "staff");
  await rejectsWith(staff.call("createHold", { busId: "b1", startsAt: when(30, "10:00"), endsAt: when(30, "12:00"), route: "x" }), "permission-denied");
  const c = await client("9820011009");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(30, "10:00"), endsAt: when(30, "12:00"), route: "x" });
  await rejectsWith(c.call("bookingAction", { bookingId: hold.bookingId, action: "confirmCost", fare: 1 }), "permission-denied");
});

test("the lifecycle runs in order, and every skipped step is refused", async () => {
  await reset();
  await put("buses/b1", bus("b1", { driverId: "drv-1" }));
  await put("drivers/drv-1", { name: "Driver", phone: "+91 90000 11122", vendorId: "ven-ok", updatedBy: "system:seed" });
  await put("busAdmin/b1", { gpsLink: "https://track.example.com/b1", updatedBy: "system:seed" });
  const c = await client("9820011010");
  const staff = await client("9820000001", "staff");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(31, "10:00"), endsAt: when(31, "16:00"), route: "A → B" });
  const act = (action, extra = {}) => staff.call("bookingAction", { bookingId: hold.bookingId, action, ...extra });
  const stage = async () => (await readDoc(`bookings/${hold.bookingId}`)).data().stage;

  await rejectsWith(act("startTrip"), "failed-precondition"); // cannot start a request
  await rejectsWith(act("recordAdvance", { amount: 4500 }), "failed-precondition", "Set the cost first.");
  await rejectsWith(act("confirmCost", { fare: -5 }), "invalid-argument");
  await rejectsWith(act("confirmCost", { fare: 12.5 }), "invalid-argument");
  await rejectsWith(act("nonsense"), "invalid-argument");

  await act("confirmCost", { fare: 18000 });
  assert.equal(await stage(), "costConfirmed");
  assert.equal((await readDoc(`bookings/${hold.bookingId}`)).data().holdExpiresAt, null);

  await rejectsWith(act("completeTrip"), "failed-precondition");
  await act("recordAdvance", { amount: 4500, mode: "UPI", reference: "UPI123" });
  assert.equal(await stage(), "confirmed");
  assert.equal((await readDoc(`bookings/${hold.bookingId}`)).data().amountPaid, 4500);
  // Confirming shares the driver's number and the tracking link with the customer.
  const shared = (await getDoc(doc(c.db, `bookings/${hold.bookingId}`))).data();
  assert.equal(shared.driverPhone, "+91 90000 11122");
  assert.equal(shared.gpsLink, "https://track.example.com/b1");

  await rejectsWith(act("recordBalance", { amount: 1 }), "failed-precondition");
  await act("startTrip");
  await act("completeTrip");
  assert.equal(await stage(), "completed");
  await act("recordBalance", { amount: 13500, mode: "Cash" });
  const final = (await readDoc(`bookings/${hold.bookingId}`)).data();
  assert.equal(final.stage, "settled");
  assert.equal(final.amountPaid, 18000);
  await rejectsWith(act("cancel"), "failed-precondition"); // too late to cancel a settled booking

  const payments = await seed((db) => getDocs(query(collection(db, "payments"), where("bookingId", "==", hold.bookingId))));
  assert.deepEqual(payments.docs.map((d) => `${d.data().kind}:${d.data().amount}`).sort(), ["advance:4500", "balance:13500"]);
  assert.equal(payments.docs[0].data().recordedBy, "Admin · Priya");

  // the customer sees the payments on their own booking
  const mine = await getDocs(query(collection(c.db, "payments"), where("bookingId", "==", hold.bookingId)));
  assert.equal(mine.size, 2);

  const audits = (await seed((db) => getDocs(collection(db, "auditLog")))).docs.map((d) => d.data().action);
  for (const expected of ["Booking cost set", "Booking confirmed", "Trip started", "Trip completed", "Booking settled"]) {
    assert.ok(audits.includes(expected), `audit has ${expected}: ${audits}`);
  }
});

test("a lapsed hold: the bus is free again at once, staff cannot confirm it, and the sweeper marks it expired", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820011011");
  const staff = await client("9820000001", "staff");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(32, "10:00"), endsAt: when(32, "16:00"), route: "A → B" });
  await seed((db) => setDoc(doc(db, `bookings/${hold.bookingId}`), { holdExpiresAt: Timestamp.fromMillis(Date.now() - 60000) }, { merge: true }));

  const other = await client("9820011012");
  assert.deepEqual((await other.call("searchBuses", { startsAt: when(32, "10:00"), endsAt: when(32, "16:00") })).busIds, ["b1"]);
  await rejectsWith(staff.call("bookingAction", { bookingId: hold.bookingId, action: "confirmCost", fare: 100 }), "failed-precondition", "This hold has expired; the bus has been released.");

  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8085";
  // Use the functions package's own copy of firebase-admin, the one lib/bookings.js uses.
  const fnRequire = require("node:module").createRequire(require("node:path").join(__dirname, "../functions/package.json"));
  const { initializeApp: initAdmin, getApps: adminApps } = fnRequire("firebase-admin/app");
  if (adminApps().length === 0) initAdmin({ projectId: "driveon-charter" });
  const { releaseLapsedHolds } = require("../functions/lib/bookings.js");
  assert.equal(await releaseLapsedHolds(), 1);
  assert.equal((await readDoc(`bookings/${hold.bookingId}`)).data().stage, "expired");
  // and the new customer can now hold it
  await other.call("createHold", { busId: "b1", startsAt: when(32, "10:00"), endsAt: when(32, "16:00"), route: "A → B" });
});

test("cancelling frees the bus", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  const c = await client("9820011013");
  const staff = await client("9820000001", "staff");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(33, "10:00"), endsAt: when(33, "16:00"), route: "A → B" });
  assert.deepEqual((await c.call("searchBuses", { startsAt: when(33, "10:00"), endsAt: when(33, "16:00") })).busIds, []);
  await staff.call("bookingAction", { bookingId: hold.bookingId, action: "cancel", reason: "Customer asked" });
  assert.equal((await readDoc(`bookings/${hold.bookingId}`)).data().stage, "cancelled");
  assert.deepEqual((await c.call("searchBuses", { startsAt: when(33, "10:00"), endsAt: when(33, "16:00") })).busIds, ["b1"]);
});

test("reallocation moves a booking to a free bus and refuses a busy one", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  await put("buses/b2", bus("b2", { driverName: "Other Driver" }));
  await put("buses/b3", bus("b3"));
  const c = await client("9820011014");
  const d = await client("9820011015");
  const staff = await client("9820000001", "staff");
  const mine = await c.call("createHold", { busId: "b1", startsAt: when(34, "10:00"), endsAt: when(34, "16:00"), route: "A → B" });
  await d.call("createHold", { busId: "b3", startsAt: when(34, "12:00"), endsAt: when(34, "14:00"), route: "A → B" });

  await rejectsWith(staff.call("bookingAction", { bookingId: mine.bookingId, action: "reallocate", newBusId: "b3" }), "failed-precondition", "bus-unavailable");
  await staff.call("bookingAction", { bookingId: mine.bookingId, action: "reallocate", newBusId: "b2" });
  const moved = (await readDoc(`bookings/${mine.bookingId}`)).data();
  assert.equal(moved.busId, "b2");
  assert.equal(moved.busReg, "REG-b2");
  assert.equal(moved.driverName, "Other Driver");
  assert.deepEqual((await c.call("searchBuses", { startsAt: when(34, "10:00"), endsAt: when(34, "16:00") })).busIds, ["b1"]); // b1 is free again
});

test("two customers cannot hold the same bus even when the holds arrive one after the other, repeatedly", async () => {
  await reset();
  await put("buses/solo", bus("solo"));
  const customers = await Promise.all(Array.from({ length: 4 }, (_, i) => client(`98200440${String(i).padStart(2, "0")}`)));
  let wins = 0;
  for (const c of customers) {
    try {
      await c.call("createHold", { busId: "solo", startsAt: when(35, "10:00"), endsAt: when(35, "16:00"), route: "A → B" });
      wins++;
    } catch (e) {
      assert.equal(e.message, "bus-unavailable");
    }
  }
  assert.equal(wins, 1);
});

test("reallocation keeps its reason, can revise the fare, refuses a fare below what was paid, and the customer is told", async () => {
  await reset();
  await put("buses/b1", bus("b1"));
  await put("buses/b2", bus("b2", { driverName: "Ramesh Jadhav" }));
  await put("buses/b3", bus("b3"));
  const c = await client("9820077001");
  const staff = await client("9820000001", "staff");
  const hold = await c.call("createHold", { busId: "b1", startsAt: when(60, "10:00"), endsAt: when(60, "16:00"), route: "A → B" });
  const act = (action, extra = {}) => staff.call("bookingAction", { bookingId: hold.bookingId, action, ...extra });
  await act("confirmCost", { fare: 18000 });
  await act("recordAdvance", { amount: 6000 });

  await rejectsWith(act("reallocate", { newBusId: "b2", reason: "Mechanical issue", revisedFare: 5000 }), "failed-precondition", "The fare cannot be less than the ₹6000 already paid.");
  await rejectsWith(act("reallocate", { newBusId: "b2", revisedFare: 12.5 }), "invalid-argument");
  await rejectsWith(act("reallocate", { newBusId: "b2", revisedFare: 0 }), "invalid-argument");
  assert.equal((await readDoc(`bookings/${hold.bookingId}`)).data().busId, "b1", "a refused change moves nothing");

  await act("reallocate", { newBusId: "b2", reason: "Mechanical issue", revisedFare: 20000 });
  const moved = (await readDoc(`bookings/${hold.bookingId}`)).data();
  assert.equal(moved.busId, "b2");
  assert.equal(moved.totalFare, 20000);
  assert.equal(moved.reallocationReason, "Mechanical issue");
  assert.equal(moved.reallocatedFrom, "REG-b1");
  assert.ok(moved.reallocatedAt);

  const audits = (await seed((db) => getDocs(collection(db, "auditLog")))).docs.map((d) => d.data()).filter((e) => e.action === "Booking moved to another bus");
  assert.equal(audits.length, 1);
  assert.match(audits[0].detail, /REG-b1 → REG-b2 · Mechanical issue · fare ₹18000 → ₹20000/);

  // The notification is written by a trigger a moment after the change.
  let changed;
  for (let i = 0; i < 40 && !changed; i++) {
    const notes = await getDocs(query(collection(c.db, "notifications"), where("userId", "==", c.uid)));
    changed = notes.docs.map((d) => d.data()).find((n) => n.kind === "reallocated");
    if (!changed) await new Promise((r) => setTimeout(r, 250));
  }
  assert.ok(changed, "customer is told");
  assert.match(changed.body, /Your total fare is now ₹20,000\./);

  // a move with no reason or fare change still works, and leaves the fare alone
  await act("reallocate", { newBusId: "b3" });
  const again = (await readDoc(`bookings/${hold.bookingId}`)).data();
  assert.equal(again.busId, "b3");
  assert.equal(again.totalFare, 20000);
  assert.equal(again.reallocationReason, "");
});
