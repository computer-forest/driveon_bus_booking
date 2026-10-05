/**
 * Creates (or updates) a staff account and gives it the admin role.
 *
 *   npm run create-admin -- you@example.com "Full Name" 'a-strong-password'
 *
 * Against the emulator set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099.
 * Against the real project set GOOGLE_APPLICATION_CREDENTIALS to a service
 * account key (Firebase console > Project settings > Service accounts) and
 * delete the key afterwards.
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

async function main() {
  const [email, name, password] = process.argv.slice(2);
  if (!email || !name || !password) {
    console.error('Usage: npm run create-admin -- <email> "<name>" <password>');
    process.exit(1);
  }
  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "driveon-charter" });
  const auth = getAuth();
  let uid: string;
  try {
    const existing = await auth.getUserByEmail(email);
    uid = existing.uid;
    await auth.updateUser(uid, { displayName: name, password });
  } catch {
    uid = (await auth.createUser({ email, displayName: name, password, emailVerified: true })).uid;
  }
  await auth.setCustomUserClaims(uid, { role: "admin" });
  console.log(`Admin ready: ${email} (uid ${uid})`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
