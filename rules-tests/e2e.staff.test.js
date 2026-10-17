// Managing who has staff access, end to end in the emulators.
const { test, before, after } = require("node:test");
const assert = require("node:assert");
const { initializeApp, deleteApp } = require("firebase/app");
const { getAuth, connectAuthEmulator, signInWithCustomToken } = require("firebase/auth");
const { getFirestore, connectFirestoreEmulator, doc, getDoc, getDocs, collection, setDoc } = require("firebase/firestore");
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require("firebase/functions");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");

let env;
const apps = [];
let counter = 0;

async function client(phone, audience = "customer") {
  const app = initializeApp({ projectId: "driveon-charter", apiKey: "fake" }, `s${counter++}`);
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

const seed = async (fn) => {
  let out;
  await env.withSecurityRulesDisabled(async (ctx) => { out = await fn(ctx.firestore()); });
  return out;
};
const readDoc = (path) => seed((db) => getDoc(doc(db, path)));
const manage = (c, data) => c.call("manageStaff", data);
const rejectsWith = (p, code, message) =>
  assert.rejects(p, (e) => e.code === `functions/${code}` && (message === undefined || e.message === message), `expected ${code} ${message ?? ""}`);

async function reset() {
  await env.clearFirestore();
  await seed((db) => setDoc(doc(db, "staff/919820000001"), { name: "Priya", active: true }));
}

before(async () => {
  env = await initializeTestEnvironment({ projectId: "driveon-charter", firestore: { host: "127.0.0.1", port: 8085 } });
});
after(async () => {
  await env.cleanup();
  await Promise.all(apps.map(deleteApp));
});

test("a customer cannot manage staff", async () => {
  await reset();
  const c = await client("9820066001");
  await rejectsWith(manage(c, { action: "add", phone: "9820066002", name: "Mallory" }), "permission-denied");
  assert.equal((await readDoc("staff/919820066002")).exists(), false);
});

test("staff add a person by their 10-digit number, who can then sign in as staff", async () => {
  await reset();
  const priya = await client("9820000001", "staff");
  await manage(priya, { action: "add", phone: "98200 66003", name: "  Asha   Kulkarni " });
  const added = (await readDoc("staff/919820066003")).data();
  assert.equal(added.name, "Asha Kulkarni");
  assert.equal(added.active, true);
  assert.equal(added.addedBy, priya.uid);

  const asha = await client("9820066003", "staff");
  assert.equal(asha.uid, "staff_919820066003");
});

test("numbers are normalised, and bad ones are refused", async () => {
  await reset();
  const priya = await client("9820000001", "staff");
  await manage(priya, { action: "add", phone: "+91 98200 66004", name: "Dev" });
  await manage(priya, { action: "add", phone: "098200 66005", name: "Esha" });
  assert.ok((await readDoc("staff/919820066004")).exists());
  assert.ok((await readDoc("staff/919820066005")).exists());
  for (const bad of ["12345", "1234567890", "", "abcdefghij", "98200660041"]) {
    await rejectsWith(manage(priya, { action: "add", phone: bad, name: "X Y" }), "invalid-argument");
  }
  await rejectsWith(manage(priya, { action: "add", phone: "9820066006", name: " " }), "invalid-argument", "Enter the person's name.");
});

test("adding someone who already has access is refused; a former member can be added back", async () => {
  await reset();
  const priya = await client("9820000001", "staff");
  await rejectsWith(manage(priya, { action: "add", phone: "9820000001", name: "Priya" }), "already-exists");
  await seed((db) => setDoc(doc(db, "staff/919820066007"), { name: "Old Name", active: false }));
  await manage(priya, { action: "add", phone: "9820066007", name: "Back Again" });
  const back = (await readDoc("staff/919820066007")).data();
  assert.equal(back.active, true);
  assert.equal(back.name, "Back Again");
});

test("switching someone off ends their access: they cannot sign in as staff again, and the audit log says who did it", async () => {
  await reset();
  const priya = await client("9820000001", "staff");
  await manage(priya, { action: "add", phone: "9820066008", name: "Temp Worker" });
  const temp = await client("9820066008", "staff");
  assert.equal((await temp.auth.currentUser.getIdTokenResult()).claims.role, "admin");

  await manage(priya, { action: "setActive", phone: "9820066008", active: false });
  assert.equal((await readDoc("staff/919820066008")).data().active, false);
  await assert.rejects(client("9820066008", "staff"), (e) => e.code === "functions/permission-denied");

  await manage(priya, { action: "setActive", phone: "9820066008", active: true });
  await client("9820066008", "staff"); // signs in again

  const log = (await seed((db) => getDocs(collection(db, "auditLog")))).docs.map((d) => d.data());
  const removed = log.find((e) => e.action === "Staff access removed");
  assert.ok(removed, JSON.stringify(log.map((l) => l.action)));
  assert.equal(removed.actor, "Priya");
  assert.match(removed.detail, /Temp Worker · \+91 98200 66008/);
  assert.ok(log.some((e) => e.action === "Staff added"));
  assert.ok(log.some((e) => e.action === "Staff access restored"));
});

test("you cannot switch yourself off, and the last active person cannot be switched off", async () => {
  await reset();
  const priya = await client("9820000001", "staff");
  await rejectsWith(manage(priya, { action: "setActive", phone: "9820000001", active: false }), "failed-precondition", "You cannot switch off your own access.");

  await manage(priya, { action: "add", phone: "9820066009", name: "Second Person" });
  const second = await client("9820066009", "staff");
  // Priya switches the second person off, leaving only herself: fine. Then the second person cannot act.
  await manage(priya, { action: "setActive", phone: "9820066009", active: false });
  // The last active member cannot be removed, even by someone else holding an old session.
  await rejectsWith(manage(second, { action: "setActive", phone: "9820000001", active: false }), "failed-precondition", "At least one person must keep staff access.");
  assert.equal((await readDoc("staff/919820000001")).data().active, true);
});

test("an unknown number cannot be switched or renamed; rename and unknown actions behave", async () => {
  await reset();
  const priya = await client("9820000001", "staff");
  await rejectsWith(manage(priya, { action: "setActive", phone: "9820066010", active: false }), "not-found");
  await rejectsWith(manage(priya, { action: "rename", phone: "9820066010", name: "Nobody" }), "not-found");
  await rejectsWith(manage(priya, { action: "setActive", phone: "9820000001", active: "yes" }), "invalid-argument");
  await rejectsWith(manage(priya, { action: "delete", phone: "9820000001" }), "invalid-argument", "Unknown action.");
  await manage(priya, { action: "rename", phone: "9820000001", name: "Priya Sharma" });
  assert.equal((await readDoc("staff/919820000001")).data().name, "Priya Sharma");
});

test("staff can read the list through the app, which shows who has access", async () => {
  await reset();
  const priya = await client("9820000001", "staff");
  const names = (await getDocs(collection(priya.db, "staff"))).docs.map((d) => d.data().name);
  assert.deepEqual(names, ["Priya"]);
});
