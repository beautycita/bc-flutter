/**
 * send-screenshot — Sends an annotated screenshot to BC's WhatsApp.
 *
 * POST { image: "<base64>", caption?: "..." }
 *
 * Hardcodes destination to BC's phone. Proxies to beautypi WA API.
 *
 * Env vars:
 *   BEAUTYPI_WA_URL    — e.g. http://100.93.1.103:3200
 *   BEAUTYPI_WA_TOKEN  — Bearer token for WA API
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

const corsHeaders = (req: Request) => ({
  "Access-Control-Allow-Origin": corsOrigin(req),
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
});

const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const BC_PHONE = Deno.env.get("BC_ALERT_PHONE") ?? "";

let _req: Request;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Verify user is authenticated
  const authHeader = req.headers.get("authorization") || "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
  } = await userClient.auth.getUser();
  if (!user) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const { image, caption } = await req.json();
    if (!image) {
      return json({ error: "image (base64) required" }, 400);
    }

    if (!BEAUTYPI_WA_URL) {
      return json({ error: "WA API not configured" }, 500);
    }

    // Get user info for context
    const { data: profile } = await userClient
      .from("profiles")
      .select("username, full_name")
      .eq("id", user.id)
      .single();

    const userName =
      profile?.full_name || profile?.username || user.id.substring(0, 8);
    const screenshotCaption =
      caption || `Screenshot de ${userName} en BeautyCita`;

    if (!BC_PHONE) {
      console.error("[send-screenshot] BC_ALERT_PHONE env var missing — screenshot dropped");
      return json({ sent: false, error: "Alert recipient not configured" }, 500);
    }

    // Image sends bypass the text queue (separate Pi endpoint, image payload).
    // Admin-to-admin only (BC's screenshot tool) — not part of the bulk-block
    // risk surface. Pi-side throttle covers this path. TODO: extend queue with
    // image content_type column to bring this under unified control.
    const waRes = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send-image`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({
        phone: BC_PHONE,
        image,
        mimetype: "image/png",
        caption: screenshotCaption,
        filename: `screenshot_${Date.now()}.png`,
      }),
    });

    const result = await waRes.json();
    return json(result, waRes.status);
  } catch (e) {
    console.error("[send-screenshot] Error:", e);
    return json({ error: (e as Error).message }, 500);
  }
});
