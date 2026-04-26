// =============================================================================
// ship-tracking-nudge — Cron: nudge salons that haven't shipped paid orders
// =============================================================================
// Pushes a single notification per (order, daysSinceCreated ∈ {3,5,7,10,13}).
// Replaces the old D3/D7/D14 escalation that auto-refunded — never auto-refunds.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";

const NUDGE_DAYS = [3, 5, 7, 10, 13];

serve(async (req) => {
  const cors = handleCorsPreflightIfOptions(req);
  if (cors) return cors;
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), {
      status: s,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });

  const cronHeader = req.headers.get("X-Cron-Secret") ?? "";
  const authHeader = req.headers.get("Authorization") ?? "";
  const isService = authHeader === `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`;
  if (!isService && (!CRON_SECRET || cronHeader !== CRON_SECRET)) {
    return json({ error: "Unauthorized" }, 401);
  }

  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Fetch paid+ship orders without tracking.
  const { data: rows } = await svc
    .from("orders")
    .select("id, business_id, product_name, created_at")
    .eq("status", "paid")
    .eq("fulfillment_method", "ship")
    .is("tracking_number", null)
    .limit(200);

  const now = new Date();
  let nudged = 0;
  for (const o of rows ?? []) {
    const ageDays = Math.floor(
      (now.getTime() - new Date(o.created_at as string).getTime()) / 86400_000,
    );
    if (!NUDGE_DAYS.includes(ageDays)) continue;
    // De-dup via a per-day idempotency on automated_message_log
    const idem = `ship-nudge:${o.id}:d${ageDays}`;
    const { data: existing } = await svc
      .from("automated_message_log")
      .select("id")
      .eq("idempotency_key", idem)
      .maybeSingle();
    if (existing) continue;

    await svc.from("automated_message_log").insert({
      business_id: o.business_id,
      trigger_type: "ship_tracking_nudge",
      idempotency_key: idem,
      status: "pending",
      payload: { order_id: o.id, days: ageDays, product: o.product_name },
    }).catch(() => null);
    nudged++;
  }

  return json({ ok: true, scanned: rows?.length ?? 0, nudged });
});
