// Run with `npm test` (starts the Firestore emulator; needs Java).
const { test, before, after, beforeEach } = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, collection, getDocs } = require("firebase/firestore");

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "driveon-charter",
    firestore: { rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8") },
  });
});

after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

const customer = (uid) => env.authenticatedContext(uid, { role: "customer" }).firestore();
const admin = () => env.authenticatedContext("adm-1", { role: "admin" }).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const newProfile = () => ({
  name: "Rohan",
  email: "r@example.com",
  phone: "98200 11223",
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

const seedProfile = (uid) =>
  env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${uid}`), {
      name: "Rohan",
      email: "r@example.com",
      phone: "98200 11223",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });

test("a customer can create and read their own profile", async () => {
  const db = customer("cust_919820011223");
  await assertSucceeds(setDoc(doc(db, "users/cust_919820011223"), newProfile()));
  await assertSucceeds(getDoc(doc(db, "users/cust_919820011223")));
});

test("a customer cannot read or write another customer's profile", async () => {
  await seedProfile("cust_919820011223");
  const other = customer("cust_919999999999");
  await assertFails(getDoc(doc(other, "users/cust_919820011223")));
  await assertFails(updateDoc(doc(other, "users/cust_919820011223"), { name: "Hacked", updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(other, "users/cust_919820011223"), newProfile()));
});

test("a customer can edit name and email but nothing else", async () => {
  await seedProfile("cust_919820011223");
  const db = customer("cust_919820011223");
  await assertSucceeds(updateDoc(doc(db, "users/cust_919820011223"), { name: "Rohan D", updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, "users/cust_919820011223"), { phone: "1", updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, "users/cust_919820011223"), { role: "admin", updatedAt: serverTimestamp() }));
});

test("a profile cannot carry a role or other unknown fields", async () => {
  const db = customer("cust_919820011223");
  await assertFails(setDoc(doc(db, "users/cust_919820011223"), { ...newProfile(), role: "admin" }));
});

test("a customer cannot delete their profile from the client", async () => {
  await seedProfile("cust_919820011223");
  await assertFails(deleteDoc(doc(customer("cust_919820011223"), "users/cust_919820011223")));
});

test("an admin can read any profile but not write one", async () => {
  await seedProfile("cust_919820011223");
  await assertSucceeds(getDoc(doc(admin(), "users/cust_919820011223")));
  await assertFails(updateDoc(doc(admin(), "users/cust_919820011223"), { name: "X", updatedAt: serverTimestamp() }));
});

test("signed-out visitors can read nothing", async () => {
  await seedProfile("cust_919820011223");
  await assertFails(getDoc(doc(anon(), "users/cust_919820011223")));
});

test("collections that are not open yet stay closed to customers and admins alike", async () => {
  for (const db of [customer("cust_919820011223"), admin()]) {
    for (const name of ["busLocks", "counters"]) {
      await assertFails(getDocs(collection(db, name)));
      await assertFails(setDoc(doc(db, `${name}/x`), { a: 1 }));
    }
    await assertFails(getDocs(collection(db, "staff")));
    await assertFails(setDoc(doc(db, "staff/919820000009"), { name: "Me", active: true }));
  }
});

// --- Stage 2: master data ------------------------------------------------

const { Timestamp } = require("firebase/firestore");

const stamp = () => ({ updatedBy: "adm-1", updatedAt: serverTimestamp() });

const validBus = () => ({
  regNumber: "MH-04-BT-7781",
  vendorId: "ven-neeta",
  capacity: 20,
  active: true,
  weeklyAvailability: Array.from({ length: 7 }, () => ({ available: true, start: 360, end: 1320 })),
  ...stamp(),
});

const seedDoc = (path, data) =>
  env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), path), data));

test("anyone signed in can read buses, locations, packages, faqs and config", async () => {
  for (const [path, data] of [
    ["buses/bus-1", { regNumber: "X" }],
    ["locations/loc-1", { city: "Thane", area: "West" }],
    ["packages/mumbai", { city: "Mumbai", packages: [] }],
    ["faqs/f1", { question: "q", answer: "a" }],
    ["config/app", { holdMinutes: 30 }],
    ["blackouts/b1", { busId: "bus-1" }],
  ]) {
    await seedDoc(path, data);
    await assertSucceeds(getDoc(doc(customer("cust_919820011223"), path)));
    await assertFails(getDoc(doc(anon(), path)));
  }
});

test("vendors, drivers, templates, GPS links and the audit log are staff-only to read", async () => {
  for (const [path, data] of [
    ["vendors/v1", { name: "V" }],
    ["drivers/d1", { name: "D" }],
    ["templates/t1", { name: "T" }],
    ["busAdmin/bus-1", { gpsLink: "https://gps" }],
    ["auditLog/a1", { actor: "x" }],
  ]) {
    await seedDoc(path, data);
    await assertFails(getDoc(doc(customer("cust_919820011223"), path)));
    await assertSucceeds(getDoc(doc(admin(), path)));
  }
});

test("customers cannot write any master data", async () => {
  const db = customer("cust_919820011223");
  await assertFails(setDoc(doc(db, "buses/bus-1"), validBus()));
  await assertFails(setDoc(doc(db, "locations/l1"), { city: "A", area: "B", updatedBy: "cust_919820011223", updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(db, "config/app"), { holdMinutes: 1, defaultAdvancePercent: 1, capacities: [], updatedBy: "x", updatedAt: serverTimestamp() }));
});

test("staff can write a valid bus, but only stamped with their own id and the server time", async () => {
  const db = admin();
  await assertSucceeds(setDoc(doc(db, "buses/bus-1"), validBus()));
  const { updatedBy, updatedAt, ...unstamped } = validBus();
  await assertFails(setDoc(doc(db, "buses/bus-2"), unstamped));
  await assertFails(setDoc(doc(db, "buses/bus-3"), { ...validBus(), updatedBy: "someone-else" }));
  await assertFails(setDoc(doc(db, "buses/bus-4"), { ...validBus(), updatedAt: Timestamp.fromDate(new Date("2020-01-01")) }));
});

test("a bus must be well formed", async () => {
  const db = admin();
  await assertFails(setDoc(doc(db, "buses/b"), { ...validBus(), capacity: 0 }));
  await assertFails(setDoc(doc(db, "buses/b"), { ...validBus(), capacity: 500 }));
  await assertFails(setDoc(doc(db, "buses/b"), { ...validBus(), weeklyAvailability: [] }));
  await assertFails(setDoc(doc(db, "buses/b"), { ...validBus(), active: "yes" }));
});

test("buses, vendors, drivers and templates are never deleted", async () => {
  await seedDoc("buses/bus-1", { regNumber: "X" });
  await seedDoc("vendors/v1", { name: "V" });
  await assertFails(deleteDoc(doc(admin(), "buses/bus-1")));
  await assertFails(deleteDoc(doc(admin(), "vendors/v1")));
});

test("staff can remove a location or a blackout; customers cannot", async () => {
  await seedDoc("locations/l1", { city: "A", area: "B" });
  await seedDoc("blackouts/b1", { busId: "bus-1" });
  await assertFails(deleteDoc(doc(customer("cust_919820011223"), "locations/l1")));
  await assertSucceeds(deleteDoc(doc(admin(), "locations/l1")));
  await assertSucceeds(deleteDoc(doc(admin(), "blackouts/b1")));
});

test("a blackout must end after it starts", async () => {
  const db = admin();
  const base = { busId: "bus-1", busReg: "X", reason: "r", ...stamp() };
  await assertSucceeds(setDoc(doc(db, "blackouts/ok"), { ...base, from: Timestamp.fromDate(new Date("2026-09-01")), to: Timestamp.fromDate(new Date("2026-09-02")) }));
  await assertFails(setDoc(doc(db, "blackouts/bad"), { ...base, from: Timestamp.fromDate(new Date("2026-09-03")), to: Timestamp.fromDate(new Date("2026-09-02")) }));
});

test("config accepts sane values and refuses a 0-minute or 9999-minute hold", async () => {
  const cfg = { holdMinutes: 30, defaultAdvancePercent: 25, capacities: [17, 20], ...stamp() };
  await assertSucceeds(setDoc(doc(admin(), "config/app"), cfg));
  await assertFails(setDoc(doc(admin(), "config/app"), { ...cfg, holdMinutes: 0 }));
  await assertFails(setDoc(doc(admin(), "config/app"), { ...cfg, holdMinutes: 9999 }));
  await assertFails(setDoc(doc(admin(), "config/app"), { ...cfg, defaultAdvancePercent: 150 }));
});

test("nobody can write the audit log from the app, not even staff", async () => {
  await assertFails(setDoc(doc(admin(), "auditLog/a1"), { actor: "me", action: "x", detail: "y" }));
});

test("a customer keeps their own recent searches and nobody else's", async () => {
  const db = customer("cust_919820011223");
  await assertSucceeds(setDoc(doc(db, "users/cust_919820011223/recents/loc-1"), { at: serverTimestamp() }));
  await assertSucceeds(getDoc(doc(db, "users/cust_919820011223/recents/loc-1")));
  await assertFails(getDoc(doc(customer("cust_919999999999"), "users/cust_919820011223/recents/loc-1")));
  await assertFails(setDoc(doc(db, "users/cust_919820011223/recents/loc-2"), { at: serverTimestamp(), extra: 1 }));
});

// --- Stage 4/5: bookings and money ---------------------------------------

const booking = (customerId) => ({
  reference: "CB-20261010-0001", customerId, customerName: "Rohan", customerPhone: "+91 98200 11223",
  route: "A -> B", capacity: 20, busId: "bus-1", busReg: "X", totalFare: 0, amountPaid: 0, stage: "requested",
  start: new Date("2026-10-10T10:00:00Z"), end: new Date("2026-10-10T15:00:00Z"),
});

test("a customer reads only their own bookings; staff read all", async () => {
  await seedDoc("bookings/bk-1", booking("cust_919820011223"));
  await seedDoc("bookings/bk-2", booking("cust_919999999999"));
  const me = customer("cust_919820011223");
  await assertSucceeds(getDoc(doc(me, "bookings/bk-1")));
  await assertFails(getDoc(doc(me, "bookings/bk-2")));
  await assertSucceeds(getDoc(doc(admin(), "bookings/bk-2")));
  await assertFails(getDoc(doc(anon(), "bookings/bk-1")));
});

test("the customer's own bookings query works, a query for everyone's does not", async () => {
  await seedDoc("bookings/bk-1", booking("cust_919820011223"));
  await seedDoc("bookings/bk-2", booking("cust_919999999999"));
  const me = customer("cust_919820011223");
  const { query, where } = require("firebase/firestore");
  const mine = await assertSucceeds(getDocs(query(collection(me, "bookings"), where("customerId", "==", "cust_919820011223"))));
  assert.equal(mine.size, 1);
  await assertFails(getDocs(collection(me, "bookings")));
  await assertSucceeds(getDocs(collection(admin(), "bookings")));
});

test("nobody can write a booking from the app, not even staff or the owner", async () => {
  await seedDoc("bookings/bk-1", booking("cust_919820011223"));
  for (const db of [customer("cust_919820011223"), admin()]) {
    await assertFails(setDoc(doc(db, "bookings/bk-new"), booking("cust_919820011223")));
    await assertFails(updateDoc(doc(db, "bookings/bk-1"), { stage: "confirmed" }));
    await assertFails(deleteDoc(doc(db, "bookings/bk-1")));
  }
});

test("payments are visible to staff and to the customer who owns the booking, and never writable", async () => {
  await seedDoc("bookings/bk-1", booking("cust_919820011223"));
  await seedDoc("payments/p1", { bookingId: "bk-1", kind: "advance", amount: 4500 });
  await assertSucceeds(getDoc(doc(customer("cust_919820011223"), "payments/p1")));
  await assertFails(getDoc(doc(customer("cust_919999999999"), "payments/p1")));
  await assertSucceeds(getDoc(doc(admin(), "payments/p1")));
  await assertFails(setDoc(doc(admin(), "payments/p2"), { bookingId: "bk-1", kind: "advance", amount: 1 }));
  await assertFails(setDoc(doc(customer("cust_919820011223"), "payments/p2"), { bookingId: "bk-1", kind: "advance", amount: 1 }));
});

test("a customer can rate only their own booking, once stamped honestly", async () => {
  await seedDoc("bookings/bk-1", booking("cust_919820011223"));
  const rating = (extra = {}) => ({ bookingId: "bk-1", bus: 5, driver: 4, overall: 5, feedback: "Great", customerId: "cust_919820011223", createdAt: serverTimestamp(), ...extra });
  await assertSucceeds(setDoc(doc(customer("cust_919820011223"), "ratings/r1"), rating()));
  await assertFails(setDoc(doc(customer("cust_919999999999"), "ratings/r2"), rating({ customerId: "cust_919999999999" }))); // not their booking
  await assertFails(setDoc(doc(customer("cust_919820011223"), "ratings/r3"), rating({ overall: 9 })));
  await assertFails(setDoc(doc(customer("cust_919820011223"), "ratings/r4"), rating({ customerId: "cust_919999999999" })));
  await assertFails(setDoc(doc(customer("cust_919820011223"), "ratings/r5"), rating({ extra: 1 })));
  await assertFails(updateDoc(doc(customer("cust_919820011223"), "ratings/r1"), { overall: 1 }));
  await assertFails(getDoc(doc(customer("cust_919820011223"), "ratings/r1"))); // staff read the ratings
  await assertSucceeds(getDoc(doc(admin(), "ratings/r1")));
});

test("a customer can ask to cancel their own booking, as pending, and see only their requests", async () => {
  await seedDoc("bookings/bk-1", booking("cust_919820011223"));
  const req = (extra = {}) => ({ bookingId: "bk-1", requestedBy: "cust_919820011223", reason: "Plans changed", status: "pending", createdAt: serverTimestamp(), ...extra });
  const me = customer("cust_919820011223");
  await assertSucceeds(setDoc(doc(me, "cancellations/c1"), req()));
  await assertFails(setDoc(doc(me, "cancellations/c2"), req({ status: "approved" })));
  await assertFails(setDoc(doc(customer("cust_919999999999"), "cancellations/c3"), req({ requestedBy: "cust_919999999999" })));
  await assertSucceeds(getDoc(doc(me, "cancellations/c1")));
  await assertFails(getDoc(doc(customer("cust_919999999999"), "cancellations/c1")));
  await assertSucceeds(getDoc(doc(admin(), "cancellations/c1")));
  await assertFails(updateDoc(doc(admin(), "cancellations/c1"), { status: "approved" })); // decided by a staff action, not a client write
});

// --- notifications, devices, search log ------------------------------------

test("a person reads only their own notifications and can only mark them read", async () => {
  await seedDoc("notifications/n1", { userId: "cust_919820011223", title: "t", body: "b", read: false });
  await seedDoc("notifications/n2", { userId: "cust_919999999999", title: "t", body: "b", read: false });
  const me = customer("cust_919820011223");
  await assertSucceeds(getDoc(doc(me, "notifications/n1")));
  await assertFails(getDoc(doc(me, "notifications/n2")));
  await assertFails(getDoc(doc(admin(), "notifications/n1"))); // not even staff read other people's inbox
  await assertSucceeds(updateDoc(doc(me, "notifications/n1"), { read: true }));
  await assertFails(updateDoc(doc(me, "notifications/n1"), { read: false }));
  await assertFails(updateDoc(doc(me, "notifications/n1"), { title: "forged", read: true }));
  await assertFails(updateDoc(doc(customer("cust_919999999999"), "notifications/n1"), { read: true }));
  await assertFails(setDoc(doc(me, "notifications/n3"), { userId: "cust_919820011223", title: "x", body: "y", read: false }));
  await assertFails(deleteDoc(doc(me, "notifications/n1")));
});

test("the inbox query for one's own notifications works, a query for everyone's does not", async () => {
  await seedDoc("notifications/n1", { userId: "cust_919820011223", title: "t", body: "b", read: false, createdAt: new Date() });
  await seedDoc("notifications/n2", { userId: "cust_919999999999", title: "t", body: "b", read: false, createdAt: new Date() });
  const { query, where } = require("firebase/firestore");
  const me = customer("cust_919820011223");
  const mine = await assertSucceeds(getDocs(query(collection(me, "notifications"), where("userId", "==", "cust_919820011223"))));
  assert.equal(mine.size, 1);
  await assertFails(getDocs(collection(me, "notifications")));
});

test("a person registers and removes their own phone for push, no one else's", async () => {
  const me = customer("cust_919820011223");
  await assertSucceeds(setDoc(doc(me, "users/cust_919820011223/devices/tok-1"), { platform: "android", updatedAt: serverTimestamp() }));
  await assertSucceeds(getDoc(doc(me, "users/cust_919820011223/devices/tok-1")));
  await assertFails(setDoc(doc(me, "users/cust_919820011223/devices/tok-2"), { platform: "android", updatedAt: serverTimestamp(), extra: 1 }));
  await assertFails(setDoc(doc(customer("cust_919999999999"), "users/cust_919820011223/devices/tok-3"), { platform: "android", updatedAt: serverTimestamp() }));
  await assertFails(getDoc(doc(customer("cust_919999999999"), "users/cust_919820011223/devices/tok-1")));
  await assertSucceeds(deleteDoc(doc(me, "users/cust_919820011223/devices/tok-1")));
});

test("only staff read the failed-search log, and nobody writes it", async () => {
  await seedDoc("searchMisses/m1", { customerId: "cust_919820011223", startsAt: "2026-10-10T10:00" });
  await assertSucceeds(getDoc(doc(admin(), "searchMisses/m1")));
  await assertFails(getDoc(doc(customer("cust_919820011223"), "searchMisses/m1")));
  await assertFails(setDoc(doc(admin(), "searchMisses/m2"), { a: 1 }));
});
