// link-uber edge function
// Handles Uber OAuth token exchange and account linking.
// Uses JWT assertion (RS256 asymmetric key) for Uber auth.
// Supports: link (auth_code exchange), unlink, refresh.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { exchangeUberTokens, refreshUberTokens, getUberApiBase } from "../_shared/uber_jwt.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const UBER_REDIRECT_URI = Deno.env.get("UBER_REDIRECT_URI") ?? "";

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

    if (action === "oauth_url") {
      const redirectUri = body.redirect_uri ?? UBER_REDIRECT_URI;
      const scopes =
        body.scopes ??
        Deno.env.get("UBER_SCOPES") ??
        "profile request places history";
      const UBER_CLIENT_ID = Deno.env.get("UBER_CLIENT_ID") ?? "";
      const UBER_SANDBOX = Deno.env.get("UBER_SANDBOX") === "true";
      const loginBase = UBER_SANDBOX
        ? "https://sandbox-login.uber.com"
        : "https://login.uber.com";
      const authUrl = `${loginBase}/oauth/v2/authorize?client_id=${encodeURIComponent(UBER_CLIENT_ID)}&redirect_uri=${encodeURIComponent(redirectUri)}&response_type=code&scope=${encodeURIComponent(scopes)}`;
      return json({ url: authUrl });
    }

    if (action === "unlink") {
      // Call Uber unlink-account endpoint first (best-effort)
      const { data: profile } = await supabase
        .from("profiles")
        .select("uber_access_token")
        .eq("id", user.id)
        .single();

      if (profile?.uber_access_token) {
        try {
          const unlinkResp = await fetch(
            `${getUberApiBase()}/v1/identity/unlink-account`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${profile.uber_access_token}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({}),
            },
          );
          if (!unlinkResp.ok) {
            console.error(
              "Uber unlink-account:",
              unlinkResp.status,
              await unlinkResp.text(),
            );
          }
        } catch (e) {
          console.error("Uber unlink-account error:", e);
        }
      }

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

      // Exchange auth code for tokens via JWT assertion
      const redirectUri = body.redirect_uri ?? UBER_REDIRECT_URI;
      const tokens = await exchangeUberTokens(authCode, redirectUri);

      if (!tokens) {
        return json(
          { error: "Failed to link Uber account. Please try again." },
          502,
        );
      }

      // Complete partner loyalty linking via Uber Identity API
      const linkResp = await fetch(
        `${getUberApiBase()}/v1/identity/link-account`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${tokens.access_token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({}),
        },
      );

      if (!linkResp.ok) {
        const linkErr = await linkResp.text();
        console.error(
          "Uber link-account call:",
          linkResp.status,
          linkErr,
        );
        // Log but don't fail — tokens are valid, linking may still work
      } else {
        console.log("Uber link-account succeeded");
      }

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

      const refreshedTokens = await refreshUberTokens(profile.uber_refresh_token);

      if (!refreshedTokens) {
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

      const refreshExpiresAt = new Date(
        Date.now() + (refreshedTokens.expires_in ?? 3600) * 1000,
      ).toISOString();

      await supabase
        .from("profiles")
        .update({
          uber_access_token: refreshedTokens.access_token,
          uber_refresh_token: refreshedTokens.refresh_token ?? profile.uber_refresh_token,
          uber_token_expires_at: refreshExpiresAt,
        })
        .eq("id", user.id);

      return json({
        refreshed: true,
        expires_at: refreshExpiresAt,
      });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("link-uber error:", err);
    return json({ error: String(err) }, 500);
  }
});
