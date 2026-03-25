// =============================================================================
// bpi-admin — Beautypi Daemon Administration (superadmin only)
// =============================================================================
// POST /bpi-admin
// Proxies admin actions (restart, diagnose, logs, repair) to beautypi's
// bpi_status.py daemon on port 3210.
// Requires superadmin JWT auth.
// =============================================================================

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
});

let _req: Request;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(_req),
      "Content-Type": "application/json",
    },
  });
}

const VALID_ACTIONS = ["restart", "diagnose", "logs", "repair"] as const;
type Action = typeof VALID_ACTIONS[number];

const VALID_SERVICES = [
  "guestkey",
  "wa-enrichment",
  "ig-enrichment",
  "lead-generator",
  "wa-validator",
  "bpi-status",
] as const;

Deno.serve(async (req) => {
  _req = req;
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // ---------------------------------------------------------------------------
  // Auth: require superadmin
  // ---------------------------------------------------------------------------
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  const client = createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: authError,
  } = await client.auth.getUser();

  if (authError || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  const { data: profile } = await client
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (profile?.role !== "superadmin") {
    return json({ error: "Forbidden" }, 403);
  }

  // ---------------------------------------------------------------------------
  // Parse and validate request body
  // ---------------------------------------------------------------------------
  let body: { action?: string; service?: string };
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const { action, service } = body;

  if (!action || !VALID_ACTIONS.includes(action as Action)) {
    return json(
      { error: `Invalid action. Must be one of: ${VALID_ACTIONS.join(", ")}` },
      400,
    );
  }

  if (!service || !VALID_SERVICES.includes(service as typeof VALID_SERVICES[number])) {
    return json(
      { error: `Invalid service. Must be one of: ${VALID_SERVICES.join(", ")}` },
      400,
    );
  }

  // ---------------------------------------------------------------------------
  // Proxy to beautypi
  // ---------------------------------------------------------------------------
  const bpiUrl = Deno.env.get("BPI_STATUS_URL") || "http://172.22.0.1:3210";
  const bpiToken = Deno.env.get("BPI_ADMIN_TOKEN") || "bc-bpi-admin-2026";

  try {
    const res = await fetch(`${bpiUrl}/api/bpi/action`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${bpiToken}`,
      },
      body: JSON.stringify({ action, service }),
      signal: AbortSignal.timeout(30000),
    });

    const resBody = await res.text();

    // Try to parse as JSON, fall back to text
    let parsed: unknown;
    try {
      parsed = JSON.parse(resBody);
    } catch (_) {
      parsed = { raw: resBody };
    }

    return json(
      {
        ok: res.ok,
        status: res.status,
        action,
        service,
        result: parsed,
      },
      res.ok ? 200 : 502,
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return json(
      {
        ok: false,
        action,
        service,
        error: `Failed to reach beautypi: ${message}`,
      },
      502,
    );
  }
});
