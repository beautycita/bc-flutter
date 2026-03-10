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

    // Run UptimeRobot + DB ping in parallel
    const [uptimeServices, dbStatus] = await Promise.all([
      apiKey ? fetchUptimeRobot(apiKey) : Promise.resolve({}),
      supabasePing(),
    ]);

    // Combine all services
    const services: Record<string, ServiceStatus> = {
      ...uptimeServices,
      "Base de Datos": dbStatus,
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
