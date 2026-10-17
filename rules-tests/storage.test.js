// Storage security rules, in the Storage emulator. Run with `npm run test:storage`.
const { test, before, after } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getBytes, deleteObject } = require("firebase/storage");

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: "driveon-charter",
    storage: { rules: fs.readFileSync(path.join(__dirname, "..", "storage.rules"), "utf8"), host: "127.0.0.1", port: 9199 },
  });
});
after(async () => env.cleanup());

const customer = () => env.authenticatedContext("cust_919820011223", { role: "customer" }).storage();
const admin = () => env.authenticatedContext("staff_919820000001", { role: "admin" }).storage();
const anon = () => env.unauthenticatedContext().storage();

const jpeg = (bytes = 50 * 1024) => new Uint8Array(bytes).fill(7);
const meta = (contentType = "image/jpeg") => ({ contentType });

async function seed(file, bytes = jpeg()) {
  await env.withSecurityRulesDisabled(async (ctx) => uploadBytes(ref(ctx.storage(), file), bytes, meta()));
}

test("staff can upload a small JPEG for a bus, both sizes", async () => {
  await assertSucceeds(uploadBytes(ref(admin(), "buses/bus-1/ph-abc123.jpg"), jpeg(300 * 1024), meta()));
  await assertSucceeds(uploadBytes(ref(admin(), "buses/bus-1/ph-abc123_thumb.jpg"), jpeg(30 * 1024), meta()));
});

test("customers can look at photos but cannot add, change or delete any", async () => {
  await seed("buses/bus-1/ph-seen.jpg");
  await assertSucceeds(getBytes(ref(customer(), "buses/bus-1/ph-seen.jpg")));
  await assertFails(uploadBytes(ref(customer(), "buses/bus-1/ph-mine.jpg"), jpeg(), meta()));
  await assertFails(deleteObject(ref(customer(), "buses/bus-1/ph-seen.jpg")));
});

test("signed-out visitors can see nothing", async () => {
  await seed("buses/bus-1/ph-hidden.jpg");
  await assertFails(getBytes(ref(anon(), "buses/bus-1/ph-hidden.jpg")));
  await assertFails(uploadBytes(ref(anon(), "buses/bus-1/ph-anon.jpg"), jpeg(), meta()));
});

test("staff must send a JPEG: other types are refused", async () => {
  await assertFails(uploadBytes(ref(admin(), "buses/bus-1/ph-png.jpg"), jpeg(), meta("image/png")));
  await assertFails(uploadBytes(ref(admin(), "buses/bus-1/ph-html.jpg"), jpeg(), meta("text/html")));
});

test("an oversized file is refused", async () => {
  await assertFails(uploadBytes(ref(admin(), "buses/bus-1/ph-big.jpg"), jpeg(701 * 1024), meta()));
  await assertSucceeds(uploadBytes(ref(admin(), "buses/bus-1/ph-edge.jpg"), jpeg(699 * 1024), meta()));
});

test("only photo-shaped names under a bus are accepted", async () => {
  await assertFails(uploadBytes(ref(admin(), "buses/bus-1/notes.jpg"), jpeg(), meta()));
  await assertFails(uploadBytes(ref(admin(), "buses/bus-1/ph-abc.exe"), jpeg(), meta()));
  await assertFails(uploadBytes(ref(admin(), "elsewhere/ph-abc.jpg"), jpeg(), meta()));
  await assertFails(uploadBytes(ref(admin(), "buses/ph-abc.jpg"), jpeg(), meta()));
});

test("a file is never rewritten: a second upload to the same name is refused", async () => {
  await seed("buses/bus-1/ph-once.jpg");
  await assertFails(uploadBytes(ref(admin(), "buses/bus-1/ph-once.jpg"), jpeg(), meta()));
});

test("staff can delete a photo", async () => {
  await seed("buses/bus-1/ph-gone.jpg");
  await assertSucceeds(deleteObject(ref(admin(), "buses/bus-1/ph-gone.jpg")));
});

test("nothing outside buses/ is readable or writable by anyone", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => uploadBytes(ref(ctx.storage(), "private/secret.jpg"), jpeg(), meta()));
  for (const s of [customer(), admin()]) {
    await assertFails(getBytes(ref(s, "private/secret.jpg")));
    await assertFails(uploadBytes(ref(s, "private/other.jpg"), jpeg(), meta()));
  }
});
