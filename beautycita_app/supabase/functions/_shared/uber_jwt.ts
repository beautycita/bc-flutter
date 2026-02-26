// Shared Uber auth utilities for all edge functions.
// Supports two auth modes:
//   1. JWT assertion (UBER_PRIVATE_KEY set) — Uber's recommended approach
//   2. Client secret (UBER_CLIENT_SECRET set) — legacy fallback

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Environment variables
// ---------------------------------------------------------------------------

const UBER_CLIENT_ID = Deno.env.get("UBER_CLIENT_ID") ?? "";
const UBER_CLIENT_SECRET = Deno.env.get("UBER_CLIENT_SECRET") ?? "";
const UBER_KEY_ID = Deno.env.get("UBER_KEY_ID") ?? "";
const UBER_PRIVATE_KEY = (Deno.env.get("UBER_PRIVATE_KEY") ?? "").replace(
  /\\n/g,
  "\n",
);
const UBER_SANDBOX = Deno.env.get("UBER_SANDBOX") === "true";
const UBER_REDIRECT_URI =
  Deno.env.get("UBER_REDIRECT_URI") ??
  "https://beautycita.com/auth/uber-callback";

const USE_JWT_ASSERTION = UBER_PRIVATE_KEY.length > 0;

// ---------------------------------------------------------------------------
// URL helpers
// Sandbox apps must use sandbox-login.uber.com for both auth and token endpoints.
// Only production apps use login.uber.com.
// ---------------------------------------------------------------------------

export function getUberTokenUrl(): string {
  return UBER_SANDBOX
    ? "https://sandbox-login.uber.com/oauth/v2/token"
    : "https://login.uber.com/oauth/v2/token";
}

export function getUberLoginBase(): string {
  return UBER_SANDBOX
    ? "https://sandbox-login.uber.com"
    : "https://login.uber.com";
}

export function getUberApiBase(): string {
  return UBER_SANDBOX
    ? "https://sandbox-api.uber.com"
    : "https://api.uber.com";
}

// ---------------------------------------------------------------------------
// JWT assertion helpers (RS256)
// ---------------------------------------------------------------------------

function base64url(data: Uint8Array | string): string {
  const raw =
    typeof data === "string"
      ? btoa(data)
      : btoa(String.fromCharCode(...data));
  return raw.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN .*-----/g, "")
    .replace(/-----END .*-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function createJwtAssertion(): Promise<string> {
  const header = JSON.stringify({
    alg: "RS256",
    typ: "JWT",
    kid: UBER_KEY_ID,
  });
  const now = Math.floor(Date.now() / 1000);
  const payload = JSON.stringify({
    iss: UBER_CLIENT_ID,
    sub: UBER_CLIENT_ID,
    aud: "auth.uber.com",
    iat: now,
    exp: now + 300,
    jti: crypto.randomUUID(),
  });

  const signingInput = `${base64url(header)}.${base64url(payload)}`;

  // Import RSA private key (PKCS#8 format)
  const keyData = pemToArrayBuffer(UBER_PRIVATE_KEY);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

// ---------------------------------------------------------------------------
// Build token request params (handles both auth modes)
// ---------------------------------------------------------------------------

async function buildTokenParams(
  extra: Record<string, string>,
): Promise<URLSearchParams> {
  const params: Record<string, string> = {
    client_id: UBER_CLIENT_ID,
    ...extra,
  };

  if (USE_JWT_ASSERTION) {
    params["client_assertion_type"] =
      "urn:ietf:params:oauth:client-assertion-type:jwt-bearer";
    params["client_assertion"] = await createJwtAssertion();
  } else {
    params["client_secret"] = UBER_CLIENT_SECRET;
  }

  return new URLSearchParams(params);
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
  const body = await buildTokenParams({
    grant_type: "authorization_code",
    redirect_uri: redirectUri ?? UBER_REDIRECT_URI,
    code: authCode,
  });

  const resp = await fetch(getUberTokenUrl(), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
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
  const body = await buildTokenParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  });

  const resp = await fetch(getUberTokenUrl(), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
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
      uber_refresh_token:
        tokens.refresh_token ?? profile.uber_refresh_token,
      uber_token_expires_at: newExpiresAt,
    })
    .eq("id", userId);

  return tokens.access_token;
}
