import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

// Set with:  firebase functions:secrets:set MSG91_AUTHKEY
// The Authkey exists only here. It is never sent to, or built into, the app.
const msg91Authkey = defineSecret("MSG91_AUTHKEY");

const VERIFY_URL = "https://control.msg91.com/api/v5/widget/verifyAccessToken";

/** Where MSG91 puts the verified number is not formally documented, so look
 *  in the places it is known to appear. Returns digits only, or null. */
function verifiedNumber(body: Record<string, unknown>): string | null {
  const data = (body.data ?? {}) as Record<string, unknown>;
  const candidates = [body.identifier, body.mobile, data.identifier, data.mobile, body.message];
  for (const c of candidates) {
    const digits = typeof c === "string" || typeof c === "number" ? String(c).replace(/\D/g, "") : "";
    if (digits.length >= 10 && digits.length <= 13) return digits;
  }
  return null;
}

/**
 * Exchanges an MSG91 OTP-widget access token for a Firebase custom token.
 *
 *   in:  { accessToken: string, audience?: "customer" | "staff", phone?: string }
 *        (phone is read only by the local emulator)
 *   out: { customToken: string }
 *
 * The number comes from MSG91's own response, never from the client, so a
 * caller cannot sign in as a number they have not verified.
 *
 * audience "staff" additionally requires the number to be on the allow-list
 * (`staff/{91XXXXXXXXXX}` with `active: true`, kept in Firestore and closed
 * to clients). A verified number that is not on it gets permission-denied.
 * Staff and customers are separate accounts (`staff_...` vs `cust_...`), so a
 * staff number signing in as a customer never gets the admin role.
 */
export const verifyMsg91Token = onCall({ secrets: [msg91Authkey] }, async (request) => {
  const accessToken = request.data?.accessToken;
  if (typeof accessToken !== "string" || accessToken.length === 0) {
    throw new HttpsError("invalid-argument", "accessToken is required.");
  }
  const staff = request.data?.audience === "staff";

  let number: string | null;
  if (process.env.FUNCTIONS_EMULATOR === "true" && accessToken.startsWith("fake-access-token-")) {
    // Local development only: the app's MSG91_FAKE mode has no real token, so
    // trust the number it sends. This branch cannot run in production,
    // where FUNCTIONS_EMULATOR is never set.
    number = String(request.data?.phone ?? "").replace(/\D/g, "") || null;
  } else {
    number = await verifyWithMsg91(accessToken);
  }
  if (!number) {
    throw new HttpsError("unauthenticated", "We couldn't verify your number.");
  }

  // Ten-digit Indian numbers get the country code; anything longer already has one.
  const full = number.length === 10 ? `91${number}` : number;
  const auth = getAuth();

  let uid: string;
  let role: "admin" | "customer";
  let displayName: string | undefined;
  if (staff) {
    const entry = await getFirestore().doc(`staff/${full}`).get();
    if (!entry.exists || entry.data()?.active !== true) {
      logger.warn("Staff sign-in refused: number not on the allow-list", { number: `***${full.slice(-4)}` });
      throw new HttpsError("permission-denied", "This number is not registered for staff access.");
    }
    uid = `staff_${full}`;
    role = "admin";
    displayName = typeof entry.data()?.name === "string" ? entry.data()?.name : undefined;
  } else {
    uid = `cust_${full}`;
    role = "customer";
  }

  // No phoneNumber on the account: the number is already in the uid, and a
  // staff and a customer account for the same number must be able to coexist.
  try {
    await auth.getUser(uid);
    if (displayName) await auth.updateUser(uid, { displayName });
  } catch {
    await auth.createUser({ uid, ...(displayName ? { displayName } : {}) });
  }
  // Role is a server-set claim; the client cannot grant itself one.
  await auth.setCustomUserClaims(uid, { role });

  return { customToken: await auth.createCustomToken(uid, { role }) };
});

/** The verified number, or a thrown HttpsError. Never trusts the client. */
async function verifyWithMsg91(accessToken: string): Promise<string> {
  let body: Record<string, unknown>;
  try {
    const res = await fetch(VERIFY_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ authkey: msg91Authkey.value(), "access-token": accessToken }),
    });
    body = (await res.json()) as Record<string, unknown>;
  } catch (e) {
    logger.error("MSG91 verifyAccessToken unreachable", e);
    throw new HttpsError("unavailable", "Could not reach the verification service.");
  }

  // Log the full response once in development to confirm where the verified
  // number is returned. Remove or lower once confirmed.
  if (process.env.FUNCTIONS_EMULATOR === "true") logger.info("MSG91 verifyAccessToken response", body);

  if (String(body.type ?? "").toLowerCase() !== "success") {
    throw new HttpsError("unauthenticated", "We couldn't verify your number.");
  }
  const number = verifiedNumber(body);
  if (!number) {
    // Fail closed rather than trust a number supplied by the client.
    logger.error("MSG91 verified the token but returned no mobile number", { keys: Object.keys(body) });
    throw new HttpsError("internal", "Verification succeeded but no number was returned.");
  }
  return number;
}
