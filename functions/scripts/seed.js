#!/usr/bin/env node
/**
 * Loads tools/seed/seed.json (the app's sample data) into Firestore.
 *
 *   node scripts/seed.js            # real project (driveon-charter)
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8085 node scripts/seed.js
 *
 * Creates documents that do not exist yet and never overwrites one, so
 * running it again cannot undo a staff edit. Seeded documents carry
 * updatedBy "system:seed", which the audit trigger ignores.
 *
 * Against the real project it uses the Firebase CLI's login
 * (`firebase login`), so no key file is needed. It talks to the Firestore
 * REST API, the same way for the emulator and the real thing.
 */
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const PROJECT = process.env.GCLOUD_PROJECT || "driveon-charter";
const EMULATOR = process.env.FIRESTORE_EMULATOR_HOST;
const BASE = EMULATOR
  ? `http://${EMULATOR}/v1/projects/${PROJECT}/databases/(default)/documents`
  : `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

async function accessToken() {
  if (EMULATOR) return "owner";
  const cliDir = process.env.FIREBASE_TOOLS_DIR || path.join(os.homedir(), ".npm-global/lib/node_modules/firebase-tools");
  const auth = require(path.join(cliDir, "lib/auth.js"));
  const account = auth.getGlobalDefaultAccount();
  return (await auth.getAccessToken(account.tokens.refresh_token, [])).access_token;
}

/** JSON -> Firestore REST value. {"__ts": iso} becomes a timestamp. */
function toValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  if (typeof v === "object") {
    if (typeof v.__ts === "string") return { timestampValue: new Date(v.__ts).toISOString() };
    return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, toValue(x)])) } };
  }
  throw new Error(`Unsupported value: ${v}`);
}

(async () => {
  const token = await accessToken();
  const seed = JSON.parse(fs.readFileSync(path.join(__dirname, "../../tools/seed/seed.json"), "utf8"));
  let created = 0;
  let skipped = 0;
  for (const [collection, docs] of Object.entries(seed)) {
    for (const [id, data] of Object.entries(docs)) {
      const res = await fetch(`${BASE}/${collection}?documentId=${encodeURIComponent(id)}`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ fields: toValue(data).mapValue.fields }),
      });
      if (res.ok) created++;
      else if (res.status === 409) skipped++;
      else throw new Error(`${collection}/${id}: ${res.status} ${await res.text()}`);
    }
  }
  console.log(`${PROJECT}: created ${created}, left ${skipped} existing document(s) untouched.`);
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
