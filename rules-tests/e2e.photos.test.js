// Bus photo cleanup, end to end in the Auth + Firestore + Storage + Functions
// emulators: removing a photo from a bus deletes its files, and the weekly
// sweep removes abandoned uploads but never a referenced or a fresh one.
const { test, before, after } = require("node:test");
const assert = require("node:assert");
const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");
const { doc, setDoc, updateDoc, deleteDoc, getDoc } = require("firebase/firestore");
const { ref, uploadBytes, getMetadata, getBytes } = require("firebase/storage");

let env;
const BUCKET = "gs://driveon-charter.firebasestorage.app"; // the project's real default bucket name
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const bytes = (n = 20 * 1024) => new Uint8Array(n).fill(9);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "driveon-charter",
    firestore: { host: "127.0.0.1", port: 8085 },
    storage: { host: "127.0.0.1", port: 9199 },
  });
  process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8085";
  process.env.FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:9199";
  process.env.STORAGE_EMULATOR_HOST = "http://127.0.0.1:9199";
});
after(async () => env.cleanup());

const asServer = async (fn) => {
  let out;
  await env.withSecurityRulesDisabled(async (ctx) => {
    out = await fn(ctx);
  });
  return out;
};
const putFile = (name, n, cacheControl) =>
  asServer((ctx) => uploadBytes(ref(ctx.storage(BUCKET), name), bytes(n), { contentType: "image/jpeg", ...(cacheControl ? { cacheControl } : {}) }));
const exists = async (name) => {
  try {
    await asServer((ctx) => getMetadata(ref(ctx.storage(BUCKET), name)));
    return true;
  } catch {
    return false;
  }
};
const waitUntilGone = async (name, ms = 15000) => {
  for (let i = 0; i < ms / 250; i++) {
    if (!(await exists(name))) return true;
    await sleep(250);
  }
  return false;
};
const bus = (photos) => ({
  regNumber: "X", vendorId: "v", vendorName: "V", capacity: 20, seatType: "x", ac: true, baseCity: "T", driverName: "D",
  active: true, weeklyAvailability: Array.from({ length: 7 }, () => ({ available: true, start: 360, end: 1320 })),
  amenities: [], photos, updatedBy: "system:seed",
});
const photo = (id) => ({ id, full: `https://x/${id}.jpg`, thumb: `https://x/${id}_thumb.jpg` });
const setBus = (id, data) => asServer((ctx) => setDoc(doc(ctx.firestore(), `buses/${id}`), data));
const patchBus = (id, data) => asServer((ctx) => updateDoc(doc(ctx.firestore(), `buses/${id}`), data));

test("a stored photo carries the long immutable cache header", async () => {
  await putFile("buses/bus-h/ph-h1.jpg", 10 * 1024, "public, max-age=31536000, immutable");
  const meta = await asServer((ctx) => getMetadata(ref(ctx.storage(BUCKET), "buses/bus-h/ph-h1.jpg")));
  assert.equal(meta.cacheControl, "public, max-age=31536000, immutable");
  assert.equal(meta.contentType, "image/jpeg");
});

test("removing a photo from a bus deletes both of its files and leaves the others", async () => {
  for (const f of ["ph-a.jpg", "ph-a_thumb.jpg", "ph-b.jpg", "ph-b_thumb.jpg"]) await putFile(`buses/bus-1/${f}`, 8 * 1024);
  await setBus("bus-1", bus([photo("ph-a"), photo("ph-b")]));
  await sleep(1500);
  assert.ok(await exists("buses/bus-1/ph-a.jpg"), "saving with both photos deletes nothing");

  await patchBus("bus-1", { photos: [photo("ph-b")] });
  assert.ok(await waitUntilGone("buses/bus-1/ph-a.jpg"), "the removed photo's picture is deleted");
  assert.ok(await waitUntilGone("buses/bus-1/ph-a_thumb.jpg"), "and its thumbnail");
  assert.ok(await exists("buses/bus-1/ph-b.jpg"), "the kept photo is untouched");
  assert.ok(await exists("buses/bus-1/ph-b_thumb.jpg"));
});

test("an upload that is not on the bus yet is never touched by an unrelated bus change", async () => {
  await putFile("buses/bus-2/ph-kept.jpg", 8 * 1024);
  await putFile("buses/bus-2/ph-fresh.jpg", 8 * 1024); // uploaded, form still open
  await setBus("bus-2", bus([photo("ph-kept")]));
  await patchBus("bus-2", { capacity: 30 });
  await sleep(3000);
  assert.ok(await exists("buses/bus-2/ph-fresh.jpg"), "a freshly uploaded, unsaved photo survives");
  assert.ok(await exists("buses/bus-2/ph-kept.jpg"));
});

test("the sweep removes old unreferenced files, keeps referenced and fresh ones", async () => {
  await putFile("buses/bus-3/ph-ref.jpg", 8 * 1024);
  await putFile("buses/bus-3/ph-old.jpg", 8 * 1024);
  await putFile("buses/bus-3/ph-new.jpg", 8 * 1024);
  await setBus("bus-3", bus([photo("ph-ref")]));

  const fnRequire = require("node:module").createRequire(require("node:path").join(__dirname, "../functions/package.json"));
  const { initializeApp, getApps } = fnRequire("firebase-admin/app");
  if (getApps().length === 0) initializeApp({ projectId: "driveon-charter", storageBucket: "driveon-charter.firebasestorage.app" });
  const { deleteUnreferenced, photoIds } = require("../functions/lib/busPhotos.js");

  // Everything is brand new: a one-day grace period spares all of it.
  assert.equal(await deleteUnreferenced("bus-3", new Set(["ph-ref"]), 24 * 60 * 60 * 1000), 0);
  assert.ok(await exists("buses/bus-3/ph-old.jpg"));
  // With no grace period (as if it were a week old) only the unreferenced files go.
  assert.equal(await deleteUnreferenced("bus-3", new Set(["ph-ref"]), 0), 2);
  assert.ok(await exists("buses/bus-3/ph-ref.jpg"), "a referenced photo is never swept");
  assert.equal(await exists("buses/bus-3/ph-old.jpg"), false);
  assert.equal(await exists("buses/bus-3/ph-new.jpg"), false);

  assert.deepEqual([...photoIds({ photos: [photo("ph-x"), { id: 5 }, null] })], ["ph-x"]);
  assert.deepEqual([...photoIds(undefined)], []);
});

test("file names map back to their photo id, and nothing else", () => {
  const { idOfFile } = require("../functions/lib/busPhotos.js");
  assert.equal(idOfFile("buses/bus-1/ph-abc123.jpg"), "ph-abc123");
  assert.equal(idOfFile("buses/bus-1/ph-abc123_thumb.jpg"), "ph-abc123");
  assert.equal(idOfFile("buses/bus-1/notes.jpg"), null);
  assert.equal(idOfFile("other/ph-abc.jpg"), null);
});
