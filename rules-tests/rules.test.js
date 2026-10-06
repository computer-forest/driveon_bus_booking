// Run with `npm test` (starts the Firestore emulator; needs Java).
const { test, before, after, beforeEach } = require("node:test");
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

test("every other collection is closed to customers and admins alike", async () => {
  for (const db of [customer("cust_919820011223"), admin()]) {
    await assertFails(getDocs(collection(db, "buses")));
    await assertFails(setDoc(doc(db, "buses/bus-1"), { regNumber: "MH 12" }));
    await assertFails(getDocs(collection(db, "bookings")));
    await assertFails(getDocs(collection(db, "staff")));
    await assertFails(setDoc(doc(db, "staff/919820000009"), { name: "Me", active: true }));
  }
});
