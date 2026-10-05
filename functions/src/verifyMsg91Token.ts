import { getAuth } from "firebase-admin/auth";
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
 *   in:  { accessToken: string }
 *   out: { customToken: string }
 *
 * The number comes from MSG91's own response, never from the client, so a
 * caller cannot sign in as a number they have not verified.
 */
export const verifyMsg91Token = onCall({ secrets: [msg91Authkey] }, async (request) => {
  const accessToken = request.data?.accessToken;
  if (typeof accessToken !== "string" || accessToken.length === 0) {
    throw new HttpsError("invalid-argument", "accessToken is required.");
  }

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

  // Ten-digit Indian numbers get the country code; anything longer already has one.
  const full = number.length === 10 ? `91${number}` : number;
  const uid = `cust_${full}`;
  const auth = getAuth();

  try {
    await auth.getUser(uid);
  } catch {
    await auth.createUser({ uid, phoneNumber: `+${full}` });
  }
  // Role is a server-set claim; the client cannot grant itself one.
  await auth.setCustomUserClaims(uid, { role: "customer" });

  return { customToken: await auth.createCustomToken(uid, { role: "customer" }) };
});
