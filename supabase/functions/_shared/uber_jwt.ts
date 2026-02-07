// Shared Uber JWT assertion utilities for all edge functions.
// Generates RS256-signed JWTs for Uber's asymmetric key authentication.

import * as jose from "https://deno.land/x/jose@v5.2.0/index.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Environment variables
// ---------------------------------------------------------------------------

const UBER_CLIENT_ID = Deno.env.get("UBER_CLIENT_ID") ?? "";
const UBER_APP_ID = Deno.env.get("UBER_APP_ID") ?? "";
const UBER_ASYMMETRIC_UUID = Deno.env.get("UBER_ASYMMETRIC_UUID") ?? "";
const UBER_RSA_PRIVATE_KEY = (Deno.env.get("UBER_RSA_PRIVATE_KEY") ?? "").replace(
  /\\n/g,
  "\n",
);
const UBER_SANDBOX = Deno.env.get("UBER_SANDBOX") === "true";
const UBER_REDIRECT_URI = Deno.env.get("UBER_REDIRECT_URI") ?? "beautycita://uber-callback";

// ---------------------------------------------------------------------------
// URL helpers
// ---------------------------------------------------------------------------

export function getUberTokenUrl(): string {
  return UBER_SANDBOX
    ? "https://sandbox-login.uber.com/oauth/v2/token"
    : "https://login.uber.com/oauth/v2/token";
}

export function getUberApiBase(): string {
  return UBER_SANDBOX
    ? "https://test-api.uber.com"
    : "https://api.uber.com";
}

// ---------------------------------------------------------------------------
// JWT assertion generation
// ---------------------------------------------------------------------------

export async function generateUberJwtAssertion(): Promise<string> {
  if (!UBER_RSA_PRIVATE_KEY || !UBER_ASYMMETRIC_UUID || !UBER_APP_ID) {
    throw new Error(
      "Missing Uber JWT config: UBER_RSA_PRIVATE_KEY, UBER_APP_ID, or UBER_ASYMMETRIC_UUID",
    );
  }

  const privateKey = await jose.importPKCS8(UBER_RSA_PRIVATE_KEY, "RS256");

  const jwt = await new jose.SignJWT({
    iss: UBER_APP_ID,
    sub: UBER_APP_ID,
    aud: "auth.uber.com",
    jti: crypto.randomUUID(),
  })
    .setProtectedHeader({
      alg: "RS256",
      typ: "JWT",
      kid: UBER_ASYMMETRIC_UUID,
    })
    .setExpirationTime("5m")
    .sign(privateKey);

  return jwt;
}

// ---------------------------------------------------------------------------
// Token exchange (auth code → access token)
// ---------------------------------------------------------------------------

export async function exchangeUberTokens(
  authCode: string,
  redirectUri?: string,
): Promise<{
  access_token: string;
  refresh_token: string;
  expires_in: number;
  scope: string;
} | null> {
  const assertion = await generateUberJwtAssertion();

  const resp = await fetch(getUberTokenUrl(), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: UBER_CLIENT_ID,
      client_assertion: assertion,
      client_assertion_type:
        "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      grant_type: "authorization_code",
      redirect_uri: redirectUri ?? UBER_REDIRECT_URI,
      code: authCode,
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    console.error("Uber token exchange failed:", resp.status, errText);
    return null;
  }

  return resp.json();
}

// ---------------------------------------------------------------------------
// Token refresh
// ---------------------------------------------------------------------------

export async function refreshUberTokens(
  refreshToken: string,
): Promise<{
  access_token: string;
  refresh_token?: string;
  expires_in: number;
} | null> {
  const assertion = await generateUberJwtAssertion();

  const resp = await fetch(getUberTokenUrl(), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: UBER_CLIENT_ID,
      client_assertion: assertion,
      client_assertion_type:
        "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    console.error("Uber token refresh failed:", resp.status, errText);
    return null;
  }

  return resp.json();
}

// ---------------------------------------------------------------------------
// Get valid access token with auto-refresh
// ---------------------------------------------------------------------------

export async function getValidUberAccessToken(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<string | null> {
  const { data: profile } = await supabase
    .from("profiles")
    .select(
      "uber_access_token, uber_refresh_token, uber_token_expires_at, uber_linked",
    )
    .eq("id", userId)
    .single();

  if (!profile?.uber_linked || !profile.uber_access_token) return null;

  // Token still valid (5 minute buffer)
  const expiresAt = new Date(profile.uber_token_expires_at).getTime();
  if (Date.now() <= expiresAt - 300_000) {
    return profile.uber_access_token;
  }

  // Token expired — attempt auto-refresh
  if (!profile.uber_refresh_token) return null;

  console.log("Auto-refreshing Uber token for user", userId);
  const tokens = await refreshUberTokens(profile.uber_refresh_token);

  if (!tokens) {
    // Refresh failed — unlink account
    await supabase
      .from("profiles")
      .update({
        uber_linked: false,
        uber_access_token: null,
        uber_refresh_token: null,
        uber_token_expires_at: null,
      })
      .eq("id", userId);
    return null;
  }

  const newExpiresAt = new Date(
    Date.now() + (tokens.expires_in ?? 3600) * 1000,
  ).toISOString();

  await supabase
    .from("profiles")
    .update({
      uber_access_token: tokens.access_token,
      uber_refresh_token: tokens.refresh_token ?? profile.uber_refresh_token,
      uber_token_expires_at: newExpiresAt,
    })
    .eq("id", userId);

  return tokens.access_token;
}
