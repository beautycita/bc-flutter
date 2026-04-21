// =============================================================================
// arco-request — LFPDPPP ARCO rights endpoint (Acceso, Rectificación, Cancelación, Oposición)
// =============================================================================
// User submits an ARCO request → row inserted in arco_requests → admin
// notified via email → 20-business-day SLA clock starts.
//
// For 'access' requests: enqueues a user-data-export job (handled by separate
// function). For 'cancellation', flags for human review (account deletion has
// downstream effects: bookings, reviews, saldo balance).
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LEGAL_EMAIL = Deno.env.get("LEGAL_EMAIL") ?? "soporte@beautycita.com";

const VALID_TYPES = ["access", "rectification", "cancellation", "opposition"] as const;
type RequestType = typeof VALID_TYPES[number];

// Rate limit: max 3 ARCO submissions per user per 24h (anti-abuse).
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
function checkRateLimit(userId: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(userId);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(userId, { count: 1, resetAt: now + 86_400_000 });
    return true;
  }
  if (entry.count >= 3) return false;
  entry.count++;
  return true;
}

let _req: Request;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

  // Auth — user must be signed in to file an ARCO request (identity binding)
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  if (!token) return json({ error: "Authorization required" }, 401);

  const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
  if (authErr || !user) return json({ error: "Invalid token" }, 401);

  if (!checkRateLimit(user.id)) {
    return json({ error: "Demasiadas solicitudes. Espera 24h e intenta de nuevo." }, 429);
  }

  let body: { request_type?: string; details?: Record<string, unknown> };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const requestType = (body.request_type ?? "").toLowerCase() as RequestType;
  if (!VALID_TYPES.includes(requestType)) {
    return json({
      error: `request_type must be one of: ${VALID_TYPES.join(", ")}`,
      valid_types: VALID_TYPES,
    }, 400);
  }

  const details = body.details ?? {};

  // Validate request-specific shape
  if (requestType === "rectification") {
    if (!details.field || !details.new_value) {
      return json({
        error: "Rectification requires details.field + details.new_value",
      }, 400);
    }
  }
  if (requestType === "opposition") {
    if (!details.processing_type) {
      return json({
        error: "Opposition requires details.processing_type (e.g. 'behavioral_analytics')",
      }, 400);
    }
  }

  // Insert ARCO request row
  const { data: arcoRow, error: insertErr } = await supabase
    .from("arco_requests")
    .insert({
      user_id: user.id,
      request_type: requestType,
      details,
      user_email: user.email ?? null,
    })
    .select("id, due_at")
    .single();

  if (insertErr || !arcoRow) {
    console.error("[ARCO] Insert error:", insertErr);
    return json({ error: "Failed to record request" }, 500);
  }

  // For 'access' type: trigger immediate user-data-export (non-blocking)
  if (requestType === "access") {
    supabase.functions.invoke("user-data-export", {
      body: { arco_request_id: arcoRow.id, user_id: user.id },
    }).catch((e) => console.error("[ARCO] data-export trigger failed:", e));
  }

  // For 'opposition' to 'behavioral_analytics': flip the user's analytics_opt_out flag immediately
  if (requestType === "opposition" && details.processing_type === "behavioral_analytics") {
    await supabase
      .from("profiles")
      .update({ analytics_opt_out: true })
      .eq("id", user.id);
  }

  // Notify legal via email
  try {
    await supabase.functions.invoke("send-email", {
      body: {
        to: LEGAL_EMAIL,
        subject: `[ARCO ${requestType.toUpperCase()}] Solicitud ${arcoRow.id.slice(0, 8)} — usuario ${user.email ?? user.id}`,
        text:
          `Nueva solicitud ARCO recibida.\n\n` +
          `ID: ${arcoRow.id}\n` +
          `Tipo: ${requestType}\n` +
          `Usuario: ${user.email ?? user.id}\n` +
          `Vencimiento (20 días hábiles): ${arcoRow.due_at}\n\n` +
          `Detalles:\n${JSON.stringify(details, null, 2)}\n\n` +
          `Atender en panel admin antes del vencimiento para mantener cumplimiento LFPDPPP.`,
      },
    });
  } catch (e) {
    console.error("[ARCO] Email notify failed (non-fatal):", e);
  }

  return json({
    success: true,
    arco_request_id: arcoRow.id,
    request_type: requestType,
    due_at: arcoRow.due_at,
    sla_message: "Te responderemos dentro de 20 días hábiles conforme al artículo 32 de la LFPDPPP.",
  }, 201);
});
