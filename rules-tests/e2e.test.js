// End to end against the emulators (auth + functions + firestore), the same
// steps the app takes. Run with `npm run e2e`. The MSG91 call itself is
// replaced by the emulator-only fake-token branch in verifyMsg91Token.
const { test, before, after } = require("node:test");
const assert = require("node:assert");
const { initializeApp, deleteApp } = require("firebase/app");
const { getAuth, connectAuthEmulator, signInWithCustomToken, signOut } = require("firebase/auth");
const { getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, updateDoc, serverTimestamp } = require("firebase/firestore");
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require("firebase/functions");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

let app, auth, db, fns, env;

before(async () => {
  // The staff allow-list is closed to clients, so seed it past the rules,
  // the way the console or an admin tool would.
  env = await initializeTestEnvironment({ projectId: "driveon-charter", firestore: { host: "127.0.0.1", port: 8085 } });
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "staff/919820000001"), { name: "Priya", active: true });
    await setDoc(doc(ctx.firestore(), "staff/919820000002"), { name: "Former staff", active: false });
  });

  app = initializeApp({ projectId: "driveon-charter", apiKey: "fake" });
  auth = getAuth(app);
  connectAuthEmulator(auth, "http://127.0.0.1:9099", { disableWarnings: true });
  db = getFirestore(app);
  connectFirestoreEmulator(db, "127.0.0.1", 8085);
  fns = getFunctions(app, "asia-south1");
  connectFunctionsEmulator(fns, "127.0.0.1", 5001);
});

after(async () => {
  await env.cleanup();
  await deleteApp(app);
});

const call = (name, data) => httpsCallable(fns, name)(data).then((r) => r.data);

test("OTP token -> custom token -> customer session with a server-set role", async () => {
  const { customToken } = await call("verifyMsg91Token", { accessToken: "fake-access-token-1", phone: "9820011223" });
  const cred = await signInWithCustomToken(auth, customToken);
  assert.equal(cred.user.uid, "cust_919820011223");
  const token = await cred.user.getIdTokenResult();
  assert.equal(token.claims.role, "customer");
});

test("a real-looking token is refused (not the emulator fake)", async () => {
  await assert.rejects(call("verifyMsg91Token", { accessToken: "some-real-token", phone: "9820011223" }));
});

test("the app's profile writes pass the rules, and a role field does not", async () => {
  const uid = auth.currentUser.uid;
  await setDoc(doc(db, `users/${uid}`), {
    name: "", email: "", phone: "98200 11223", createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  await updateDoc(doc(db, `users/${uid}`), { name: "Rohan", email: "r@example.com", updatedAt: serverTimestamp() });
  assert.equal((await getDoc(doc(db, `users/${uid}`))).data().name, "Rohan");
  await assert.rejects(updateDoc(doc(db, `users/${uid}`), { role: "admin", updatedAt: serverTimestamp() }));
});

test("a customer cannot read other collections or change roles", async () => {
  await assert.rejects(getDoc(doc(db, "buses/bus-1")));
  await assert.rejects(call("setUserRole", { uid: "cust_919999999999", role: "admin" }));
});

test("deleting the account erases the profile and the sign-in", async () => {
  const uid = auth.currentUser.uid;
  await call("deleteAccount", {});
  await signOut(auth);
  await assert.rejects(signInWithCustomToken(auth, (await call("verifyMsg91Token", { accessToken: "fake-access-token-2", phone: "9820011223" })).customToken).then(async () => {
    // A fresh sign-in recreates the account; the old profile must be gone.
    const snap = await getDoc(doc(db, `users/${uid}`));
    assert.equal(snap.exists(), false);
    throw new Error("profile-gone");
  }), /profile-gone/);
});

const staffToken = (phone) =>
  call("verifyMsg91Token", { accessToken: "fake-access-token-s", phone, audience: "staff" });

test("a number on the staff list signs in as an admin, in its own account", async () => {
  await signOut(auth);
  const { customToken } = await staffToken("9820000001");
  const cred = await signInWithCustomToken(auth, customToken);
  assert.equal(cred.user.uid, "staff_919820000001");
  assert.equal(cred.user.displayName, "Priya");
  assert.equal((await cred.user.getIdTokenResult()).claims.role, "admin");
});

test("the same number as a customer is only a customer", async () => {
  await signOut(auth);
  const { customToken } = await call("verifyMsg91Token", { accessToken: "fake-access-token-c", phone: "9820000001" });
  const cred = await signInWithCustomToken(auth, customToken);
  assert.equal(cred.user.uid, "cust_919820000001");
  assert.equal((await cred.user.getIdTokenResult()).claims.role, "customer");
});

test("a verified number that is not on the staff list is refused", async () => {
  await assert.rejects(staffToken("9820011223"), (e) => e.code === "functions/permission-denied");
});

test("a deactivated staff member is refused", async () => {
  await assert.rejects(staffToken("9820000002"), (e) => e.code === "functions/permission-denied");
});

test("a signed-in customer or staff member cannot read the staff list", async () => {
  await assert.rejects(getDoc(doc(db, "staff/919820000001")));
  await signOut(auth);
  const { customToken } = await staffToken("9820000001");
  await signInWithCustomToken(auth, customToken);
  await assert.rejects(getDoc(doc(db, "staff/919820000001")));
});
