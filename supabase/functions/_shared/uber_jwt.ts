// Shared Uber auth utilities for all edge functions.
// Uses client_secret for token exchange (simpler than RSA JWT assertion).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Environment variables
// ---------------------------------------------------------------------------

const UBER_CLIENT_ID = Deno.env.get("UBER_CLIENT_ID") ?? "";
const UBER_CLIENT_SECRET = Deno.env.get("UBER_CLIENT_SECRET") ?? "";
const UBER_SANDBOX = Deno.env.get("UBER_SANDBOX") === "true";
const UBER_REDIRECT_URI = Deno.env.get("UBER_REDIRECT_URI") ?? "https://beautycita.com/auth/uber-callback";

// ---------------------------------------------------------------------------
// URL helpers
// Auth always uses production URLs (sandbox doesn't support token generation).
// Only ride/API requests use sandbox endpoints.
// ---------------------------------------------------------------------------

export function getUberTokenUrl(): string {
  return "https://login.uber.com/oauth/v2/token";
}

export function getUberLoginBase(): string {
  return "https://login.uber.com";
}

export function getUberApiBase(): string {
  return UBER_SANDBOX
    ? "https://sandbox-api.uber.com"
    : "https://api.uber.com";
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
  const resp = await fetch(getUberTokenUrl(), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: UBER_CLIENT_ID,
      client_secret: UBER_CLIENT_SECRET,
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
  const resp = await fetch(getUberTokenUrl(), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: UBER_CLIENT_ID,
      client_secret: UBER_CLIENT_SECRET,
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
