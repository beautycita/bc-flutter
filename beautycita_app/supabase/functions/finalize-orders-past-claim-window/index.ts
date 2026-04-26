// =============================================================================
// finalize-orders-past-claim-window — Cron: shipped/delivered → completed
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";

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

  // Pull candidates: status in shipped/delivered, claim window expired,
  // no open dispute.
  const now = new Date().toISOString();
  const { data: candidates } = await svc
    .from("orders")
    .select("id")
    .in("status", ["shipped", "delivered"])
    .lt("claim_window_ends_at", now)
    .limit(100);

  let finalized = 0;
  const errors: string[] = [];
  for (const o of candidates ?? []) {
    try {
      // Skip if there's an open/escalated dispute on this order.
      const { data: dispute } = await svc
        .from("disputes")
        .select("id")
        .eq("order_id", o.id)
        .in("status", ["open", "escalated"])
        .maybeSingle();
      if (dispute) continue;

      const { data: cas } = await svc
        .from("orders")
        .update({
          status: "completed",
          completed_at: new Date().toISOString(),
        })
        .eq("id", o.id)
        .in("status", ["shipped", "delivered"])
        .lt("claim_window_ends_at", new Date().toISOString())
        .select("id")
        .maybeSingle();
      if (cas) finalized++;
    } catch (e) {
      errors.push(`${o.id}: ${String(e).slice(0, 120)}`);
    }
  }

  return json({ ok: true, processed: candidates?.length ?? 0, finalized, errors });
});
