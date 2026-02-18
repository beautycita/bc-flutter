// =============================================================================
// google-risc-receiver — Cross-Account Protection (RISC) event receiver
// =============================================================================
// Receives security event tokens (SETs) from Google when a user's Google
// account is compromised, disabled, or has sessions/tokens revoked.
// See: https://developers.google.com/identity/protocols/risc
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { decode as base64Decode } from "https://deno.land/std@0.177.0/encoding/base64.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Google's RISC issuer
const GOOGLE_ISSUER = "https://accounts.google.com/";
const GOOGLE_JWKS_URI = "https://www.googleapis.com/oauth2/v3/certs";

// Our OAuth client IDs (audience validation)
const VALID_AUDIENCES = [
  "925456539297-48gjim6slsnke7e9lc5h4ca9dhhpqb1e.apps.googleusercontent.com",
  "925456539297-bif3artsdt25nn53mbqfd57eurm5vnvh.apps.googleusercontent.com",
];

interface JWKKey {
  kid: string;
  n: string;
  e: string;
  kty: string;
  alg: string;
}

/** Fetch Google's JWKS keys */
async function getGoogleKeys(): Promise<JWKKey[]> {
  const res = await fetch(GOOGLE_JWKS_URI);
  const data = await res.json();
  return data.keys;
}

/** Decode JWT without verification (to get header/payload) */
function decodeJwtParts(token: string) {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Invalid JWT format");

  const header = JSON.parse(new TextDecoder().decode(base64Decode(parts[0].replace(/-/g, "+").replace(/_/g, "/"))));
  const payload = JSON.parse(new TextDecoder().decode(base64Decode(parts[1].replace(/-/g, "+").replace(/_/g, "/"))));

  return { header, payload };
}

/** Import RSA public key from JWK for verification */
async function importKey(jwk: JWKKey): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "jwk",
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: jwk.alg, ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
}

/** Verify JWT signature */
async function verifyJwtSignature(token: string, key: CryptoKey): Promise<boolean> {
  const parts = token.split(".");
  const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const signature = base64Decode(parts[2].replace(/-/g, "+").replace(/_/g, "/"));
  return await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, signature, data);
}

/** Validate and decode the security event token */
async function validateSecurityEventToken(token: string) {
  const { header, payload } = decodeJwtParts(token);

  // Validate issuer
  if (payload.iss !== GOOGLE_ISSUER) {
    throw new Error(`Invalid issuer: ${payload.iss}`);
  }

  // Validate audience
  const aud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!aud.some((a: string) => VALID_AUDIENCES.includes(a))) {
    throw new Error(`Invalid audience: ${payload.aud}`);
  }

  // Get signing key
  const keys = await getGoogleKeys();
  const key = keys.find((k) => k.kid === header.kid);
  if (!key) {
    throw new Error(`Signing key not found: ${header.kid}`);
  }

  // Verify signature
  const cryptoKey = await importKey(key);
  const valid = await verifyJwtSignature(token, cryptoKey);
  if (!valid) {
    throw new Error("Invalid signature");
  }

  return payload;
}

serve(async (req) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const body = await req.text();

    // Google sends the SET as a form-encoded or JSON body
    let token: string;
    try {
      // Try JSON first
      const json = JSON.parse(body);
      token = json.token || json;
    } catch {
      // Try form-encoded
      const params = new URLSearchParams(body);
      token = params.get("token") ?? body;
    }

    if (!token || typeof token !== "string") {
      return new Response("Missing token", { status: 400 });
    }

    // Validate and decode
    const payload = await validateSecurityEventToken(token);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Process security events
    const events = payload.events || {};

    for (const [eventType, eventData] of Object.entries(events)) {
      const data = eventData as Record<string, unknown>;
      const subject = data.subject as Record<string, string> | undefined;
      const googleSub = subject?.sub;

      console.log(`[RISC] Event: ${eventType}, subject: ${googleSub}, jti: ${payload.jti}`);

      // Log the event in audit_log
      await supabase.from("audit_log").insert({
        admin_id: null,
        action: "google_risc_event",
        target_type: "user",
        target_id: googleSub,
        details: {
          event_type: eventType,
          jti: payload.jti,
          reason: (data as Record<string, unknown>).reason,
        },
      });

      // Find the user by their Google provider ID
      if (googleSub) {
        // Look up user in auth.users by provider sub
        const { data: authUsers } = await supabase.auth.admin.listUsers();
        const affectedUser = authUsers?.users?.find((u) =>
          u.identities?.some(
            (i) => i.provider === "google" && i.identity_data?.sub === googleSub,
          ),
        );

        if (affectedUser) {
          const userId = affectedUser.id;

          switch (eventType) {
            case "https://schemas.openid.net/secevent/risc/event-type/sessions-revoked":
            case "https://schemas.openid.net/secevent/oauth/event-type/tokens-revoked":
              // Sign out the user from all sessions
              await supabase.auth.admin.signOut(userId, "global");
              console.log(`[RISC] Signed out user ${userId}`);
              break;

            case "https://schemas.openid.net/secevent/risc/event-type/account-disabled":
              // Disable the user's account
              await supabase.auth.admin.updateUserById(userId, {
                ban_duration: "876000h", // ~100 years
              });
              // Also update profile status
              await supabase
                .from("profiles")
                .update({ status: "suspended" })
                .eq("id", userId);
              console.log(`[RISC] Disabled user ${userId}, reason: ${(data as Record<string, unknown>).reason}`);
              break;

            case "https://schemas.openid.net/secevent/risc/event-type/account-enabled":
              // Re-enable the user
              await supabase.auth.admin.updateUserById(userId, {
                ban_duration: "none",
              });
              await supabase
                .from("profiles")
                .update({ status: "active" })
                .eq("id", userId);
              console.log(`[RISC] Re-enabled user ${userId}`);
              break;

            case "https://schemas.openid.net/secevent/risc/event-type/account-credential-change-required":
              // Log it — user should re-authenticate next time
              console.log(`[RISC] Credential change required for user ${userId}`);
              break;

            case "https://schemas.openid.net/secevent/risc/event-type/verification":
              // Test token — just log it
              console.log(`[RISC] Verification token received, state: ${(data as Record<string, unknown>).state}`);
              break;

            default:
              console.log(`[RISC] Unhandled event type: ${eventType}`);
          }
        } else {
          console.log(`[RISC] No user found for Google sub: ${googleSub}`);
        }
      }
    }

    // Google expects 202 Accepted
    return new Response("Accepted", { status: 202 });
  } catch (error) {
    console.error(`[RISC] Error: ${error}`);
    return new Response(`Error: ${error}`, { status: 400 });
  }
});
