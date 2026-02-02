// link-uber edge function
// Handles Uber OAuth token exchange and account linking.
// Keeps client_secret server-side (never on device).
// Supports: link (auth_code exchange), unlink, refresh.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const UBER_CLIENT_ID = Deno.env.get("UBER_CLIENT_ID") ?? "";
const UBER_CLIENT_SECRET = Deno.env.get("UBER_CLIENT_SECRET") ?? "";
const UBER_REDIRECT_URI = Deno.env.get("UBER_REDIRECT_URI") ?? "";
const UBER_TOKEN_URL = "https://login.uber.com/oauth/v2/token";

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
    const action = body.action ?? "link";

    if (action === "unlink") {
      // Clear Uber tokens from profile
      const { error } = await supabase
        .from("profiles")
        .update({
          uber_linked: false,
          uber_access_token: null,
          uber_refresh_token: null,
          uber_token_expires_at: null,
        })
        .eq("id", user.id);

      if (error) return json({ error: error.message }, 500);
      return json({ unlinked: true });
    }

    if (action === "link") {
      const authCode = body.auth_code;
      if (!authCode) {
        return json({ error: "auth_code required" }, 400);
      }

      if (!UBER_CLIENT_ID || !UBER_CLIENT_SECRET) {
        return json(
          { error: "Uber API not configured. Contact support." },
          503,
        );
      }

      // Exchange auth code for tokens
      const tokenResp = await fetch(UBER_TOKEN_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: UBER_CLIENT_ID,
          client_secret: UBER_CLIENT_SECRET,
          grant_type: "authorization_code",
          redirect_uri: UBER_REDIRECT_URI,
          code: authCode,
        }),
      });

      if (!tokenResp.ok) {
        const errText = await tokenResp.text();
        console.error("Uber token exchange failed:", errText);
        return json(
          { error: "Failed to link Uber account. Please try again." },
          502,
        );
      }

      const tokens = await tokenResp.json();
      const expiresAt = new Date(
        Date.now() + (tokens.expires_in ?? 3600) * 1000,
      ).toISOString();

      // Store tokens in profile
      const { error } = await supabase
        .from("profiles")
        .update({
          uber_linked: true,
          uber_access_token: tokens.access_token,
          uber_refresh_token: tokens.refresh_token,
          uber_token_expires_at: expiresAt,
        })
        .eq("id", user.id);

      if (error) return json({ error: error.message }, 500);

      return json({
        linked: true,
        expires_at: expiresAt,
      });
    }

    if (action === "refresh") {
      // Refresh an expired token
      const { data: profile } = await supabase
        .from("profiles")
        .select("uber_refresh_token")
        .eq("id", user.id)
        .single();

      if (!profile?.uber_refresh_token) {
        return json({ error: "No refresh token found" }, 400);
      }

      const tokenResp = await fetch(UBER_TOKEN_URL, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          client_id: UBER_CLIENT_ID,
          client_secret: UBER_CLIENT_SECRET,
          grant_type: "refresh_token",
          refresh_token: profile.uber_refresh_token,
        }),
      });

      if (!tokenResp.ok) {
        // Refresh failed — unlink account
        await supabase
          .from("profiles")
          .update({
            uber_linked: false,
            uber_access_token: null,
            uber_refresh_token: null,
            uber_token_expires_at: null,
          })
          .eq("id", user.id);

        return json(
          { error: "Uber session expired. Please re-link your account." },
          401,
        );
      }

      const tokens = await tokenResp.json();
      const expiresAt = new Date(
        Date.now() + (tokens.expires_in ?? 3600) * 1000,
      ).toISOString();

      await supabase
        .from("profiles")
        .update({
          uber_access_token: tokens.access_token,
          uber_refresh_token: tokens.refresh_token ?? profile.uber_refresh_token,
          uber_token_expires_at: expiresAt,
        })
        .eq("id", user.id);

      return json({
        refreshed: true,
        expires_at: expiresAt,
      });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("link-uber error:", err);
    return json({ error: String(err) }, 500);
  }
});
