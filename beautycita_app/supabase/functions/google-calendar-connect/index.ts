// google-calendar-connect edge function
// Handles Google Calendar OAuth token exchange and account connection.
// Actions: oauth_url, connect, disconnect
//
// Environment secrets required:
//   GOOGLE_CLIENT_ID
//   GOOGLE_CLIENT_SECRET

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID") ?? "";
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET") ?? "";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const DEFAULT_REDIRECT_URI = "https://beautycita.com/auth/google-calendar-callback";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, content-type, x-client-info, apikey",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers":
          "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    return json({ error: "Google Calendar not configured" }, 500);
  }

  // Authenticate the calling user
  const authHeader = req.headers.get("authorization") ?? "";
  const supabase = createClient(supabaseUrl, serviceKey);

  // Verify the user's JWT
  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const body = await req.json();
    const action = body.action ?? "connect";

    // ---------------------------------------------------------------------------
    // ACTION: oauth_url - Generate OAuth authorization URL
    // ---------------------------------------------------------------------------
    if (action === "oauth_url") {
      const redirectUri = body.redirect_uri ?? DEFAULT_REDIRECT_URI;
      const scopes = "https://www.googleapis.com/auth/calendar.readonly";

      // Include state parameter with user ID for security
      const state = btoa(JSON.stringify({ user_id: user.id, ts: Date.now() }));

      const authUrl = new URL("https://accounts.google.com/o/oauth2/v2/auth");
      authUrl.searchParams.set("client_id", GOOGLE_CLIENT_ID);
      authUrl.searchParams.set("redirect_uri", redirectUri);
      authUrl.searchParams.set("response_type", "code");
      authUrl.searchParams.set("scope", scopes);
      authUrl.searchParams.set("access_type", "offline");
      authUrl.searchParams.set("prompt", "consent");
      authUrl.searchParams.set("state", state);

      return json({ url: authUrl.toString() });
    }

    // ---------------------------------------------------------------------------
    // ACTION: connect - Exchange auth code for tokens and store connection
    // ---------------------------------------------------------------------------
    if (action === "connect") {
      const authCode = body.code;
      const redirectUri = body.redirect_uri ?? DEFAULT_REDIRECT_URI;

      if (!authCode) {
        return json({ error: "code required" }, 400);
      }

      // Get the staff record for this user
      const { data: staffRecord, error: staffError } = await supabase
        .from("staff")
        .select("id, business_id")
        .eq("user_id", user.id)
        .single();

      if (staffError || !staffRecord) {
        return json({ error: "No staff record found. Only business owners can connect calendars." }, 403);
      }

      // Exchange authorization code for tokens
      const tokenResp = await fetch(GOOGLE_TOKEN_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: GOOGLE_CLIENT_ID,
          client_secret: GOOGLE_CLIENT_SECRET,
          code: authCode,
          grant_type: "authorization_code",
          redirect_uri: redirectUri,
        }),
      });

      if (!tokenResp.ok) {
        const errText = await tokenResp.text();
        console.error("Google token exchange failed:", tokenResp.status, errText);
        return json({ error: "Failed to exchange authorization code" }, 502);
      }

      const tokens = await tokenResp.json();

      if (!tokens.access_token) {
        console.error("Google token response missing access_token:", tokens);
        return json({ error: "Invalid token response from Google" }, 502);
      }

      // Calculate token expiration
      const expiresAt = new Date(
        Date.now() + (tokens.expires_in ?? 3600) * 1000
      ).toISOString();

      // Upsert calendar connection record
      const { error: upsertError } = await supabase
        .from("calendar_connections")
        .upsert(
          {
            staff_id: staffRecord.id,
            provider: "google",
            access_token: tokens.access_token,
            refresh_token: tokens.refresh_token ?? null,
            token_expires_at: expiresAt,
            sync_enabled: true,
            sync_error: null,
            updated_at: new Date().toISOString(),
          },
          {
            onConflict: "staff_id,provider",
          }
        );

      if (upsertError) {
        console.error("Failed to store calendar connection:", upsertError);
        return json({ error: "Failed to store connection" }, 500);
      }

      return json({
        connected: true,
        expires_at: expiresAt,
        has_refresh_token: !!tokens.refresh_token,
      });
    }

    // ---------------------------------------------------------------------------
    // ACTION: disconnect - Remove calendar connection
    // ---------------------------------------------------------------------------
    if (action === "disconnect") {
      // Get the staff record for this user
      const { data: staffRecord } = await supabase
        .from("staff")
        .select("id")
        .eq("user_id", user.id)
        .single();

      if (!staffRecord) {
        return json({ error: "No staff record found" }, 403);
      }

      // Delete the calendar connection
      const { error: deleteError } = await supabase
        .from("calendar_connections")
        .delete()
        .eq("staff_id", staffRecord.id)
        .eq("provider", "google");

      if (deleteError) {
        console.error("Failed to delete calendar connection:", deleteError);
        return json({ error: "Failed to disconnect" }, 500);
      }

      // Also delete any synced external appointments from Google Calendar
      await supabase
        .from("external_appointments")
        .delete()
        .eq("staff_id", staffRecord.id)
        .eq("source", "google_calendar");

      return json({ disconnected: true });
    }

    // ---------------------------------------------------------------------------
    // ACTION: status - Get connection status
    // ---------------------------------------------------------------------------
    if (action === "status") {
      // Get the staff record for this user
      const { data: staffRecord } = await supabase
        .from("staff")
        .select("id")
        .eq("user_id", user.id)
        .single();

      if (!staffRecord) {
        return json({
          connected: false,
          is_staff: false,
        });
      }

      // Get the calendar connection
      const { data: connection } = await supabase
        .from("calendar_connections")
        .select("id, sync_enabled, last_synced_at, sync_error, token_expires_at")
        .eq("staff_id", staffRecord.id)
        .eq("provider", "google")
        .single();

      if (!connection) {
        return json({
          connected: false,
          is_staff: true,
        });
      }

      return json({
        connected: true,
        is_staff: true,
        sync_enabled: connection.sync_enabled,
        last_synced_at: connection.last_synced_at,
        sync_error: connection.sync_error,
        token_valid: connection.token_expires_at
          ? new Date(connection.token_expires_at) > new Date()
          : false,
      });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("google-calendar-connect error:", err);
    return json({ error: String(err) }, 500);
  }
});
