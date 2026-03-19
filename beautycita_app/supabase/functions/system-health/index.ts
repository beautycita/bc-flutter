// =============================================================================
// system-health — BeautyCita System Status (public API)
// =============================================================================
// GET /system-health
// Returns live status from UptimeRobot monitors + Supabase self-ping.
// Public endpoint — no auth required. Cached 60 seconds.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type OverallStatus = "operational" | "degraded" | "down" | "unknown";

interface ServiceStatus {
  status: OverallStatus;
  uptime: string;
}

interface HealthResponse {
  overall: OverallStatus;
  services: Record<string, ServiceStatus>;
  checked_at: string;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=60",
    },
  });
}

// Map UptimeRobot status codes to our status strings
function mapUptimeRobotStatus(code: number): OverallStatus {
  switch (code) {
    case 2:
      return "operational";
    case 8:
      return "degraded";
    case 9:
      return "down";
    default:
      // 0=paused, 1=not checked yet
      return "unknown";
  }
}

// Determine overall status from individual statuses
function computeOverall(statuses: OverallStatus[]): OverallStatus {
  if (statuses.length === 0) return "unknown";
  if (statuses.some((s) => s === "down")) return "down";
  if (statuses.some((s) => s === "degraded")) return "degraded";
  if (statuses.every((s) => s === "operational")) return "operational";
  return "unknown";
}

// ---------------------------------------------------------------------------
// Fetch UptimeRobot monitors
// ---------------------------------------------------------------------------
async function fetchUptimeRobot(
  apiKey: string,
): Promise<Record<string, ServiceStatus>> {
  const services: Record<string, ServiceStatus> = {};

  try {
    const res = await fetch(
      "https://api.uptimerobot.com/v2/getMonitors",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          api_key: apiKey,
          format: "json",
          custom_uptime_ratios: "30",
        }),
      },
    );

    if (!res.ok) return services;

    const data = await res.json();
    const monitors = data.monitors || [];

    for (const m of monitors) {
      const status = mapUptimeRobotStatus(m.status);
      const uptime = m.custom_uptime_ratio
        ? parseFloat(m.custom_uptime_ratio).toFixed(2)
        : "—";
      services[m.friendly_name] = { status, uptime };
    }
  } catch (_) {
    // Silently fail — we still return the DB ping
  }

  return services;
}

// ---------------------------------------------------------------------------
// Supabase self-ping
// ---------------------------------------------------------------------------
async function supabasePing(): Promise<ServiceStatus> {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const client = createClient(supabaseUrl, supabaseKey);

    const start = performance.now();
    await client.from("app_config").select("key").limit(1).single();
    const elapsed = Math.round(performance.now() - start);

    return { status: "operational", uptime: `${elapsed}ms` };
  } catch (_) {
    return { status: "down", uptime: "—" };
  }
}

// ---------------------------------------------------------------------------
// WhatsApp API check (beautypi via wa_relay)
// ---------------------------------------------------------------------------
async function checkWhatsApp(): Promise<ServiceStatus> {
  const waUrl = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
  if (!waUrl) return { status: "unknown", uptime: "not configured" };

  try {
    const start = performance.now();
    const res = await fetch(`${waUrl}/api/wa/status`, {
      signal: AbortSignal.timeout(10000),
    });
    const elapsed = Math.round(performance.now() - start);

    if (!res.ok) return { status: "down", uptime: `${elapsed}ms (HTTP ${res.status})` };

    const data = await res.json();
    if (data.ready === true) {
      return { status: "operational", uptime: `${elapsed}ms` };
    }
    return { status: "degraded", uptime: `${elapsed}ms (not ready)` };
  } catch (_) {
    // Relay may be unreachable from health check isolate but work fine
    // from other edge functions — report degraded, not down
    return { status: "degraded", uptime: "check timeout (relay may still work)" };
  }
}

// ---------------------------------------------------------------------------
// Storage check (Supabase Storage)
// ---------------------------------------------------------------------------
async function checkStorage(): Promise<ServiceStatus> {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const client = createClient(supabaseUrl, supabaseKey);

    const start = performance.now();
    const { error } = await client.storage.listBuckets();
    const elapsed = Math.round(performance.now() - start);

    if (error) return { status: "down", uptime: `${elapsed}ms` };
    return { status: "operational", uptime: `${elapsed}ms` };
  } catch (_) {
    return { status: "down", uptime: "—" };
  }
}

// ---------------------------------------------------------------------------
// Auth check (Supabase Auth)
// ---------------------------------------------------------------------------
async function checkAuth(): Promise<ServiceStatus> {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const start = performance.now();
    // Hit the auth health endpoint
    const res = await fetch(`${supabaseUrl}/auth/v1/health`, {
      headers: { apikey: supabaseKey },
      signal: AbortSignal.timeout(5000),
    });
    const elapsed = Math.round(performance.now() - start);

    if (res.ok) return { status: "operational", uptime: `${elapsed}ms` };
    return { status: "degraded", uptime: `${elapsed}ms (HTTP ${res.status})` };
  } catch (_) {
    return { status: "down", uptime: "—" };
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------
Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const checkedAt = new Date().toISOString();

  try {
    const apiKey = Deno.env.get("UPTIMEROBOT_API_KEY") ?? "";

    // Run all checks in parallel
    const [uptimeServices, dbStatus, waStatus, storageStatus, authStatus] = await Promise.all([
      apiKey ? fetchUptimeRobot(apiKey) : Promise.resolve({}),
      supabasePing(),
      checkWhatsApp(),
      checkStorage(),
      checkAuth(),
    ]);

    // Combine all services
    const services: Record<string, ServiceStatus> = {
      ...uptimeServices,
      "Base de Datos": dbStatus,
      "WhatsApp API": waStatus,
      "Storage": storageStatus,
      "Auth": authStatus,
    };

    // Compute overall from all statuses
    const allStatuses = Object.values(services).map((s) => s.status);
    const overall = computeOverall(allStatuses);

    const body: HealthResponse = { overall, services, checked_at: checkedAt };
    return json(body);
  } catch (_) {
    // Always return 200 so the status page renders
    return json({
      overall: "unknown",
      services: {},
      checked_at: checkedAt,
    });
  }
});
