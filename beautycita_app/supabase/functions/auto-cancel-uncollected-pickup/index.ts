// =============================================================================
// auto-cancel-uncollected-pickup — Cron: refund pickup orders not collected in 14d
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { processRefund } from "../_shared/refund.ts";

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

  // Cron auth
  const cronHeader = req.headers.get("X-Cron-Secret") ?? "";
  const authHeader = req.headers.get("Authorization") ?? "";
  const isService = authHeader === `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`;
  if (!isService && (!CRON_SECRET || cronHeader !== CRON_SECRET)) {
    return json({ error: "Unauthorized" }, 401);
  }

  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: cfg } = await svc
    .from("app_config")
    .select("value")
    .eq("key", "pos_pickup_uncollected_days")
    .single();
  const days = parseInt(cfg?.value ?? "14");
  const cutoff = new Date(Date.now() - days * 86400_000);

  const { data: stale } = await svc
    .from("orders")
    .select("id, buyer_id, business_id, total_amount, payment_method")
    .eq("status", "awaiting_pickup")
    .lt("created_at", cutoff.toISOString())
    .limit(50);

  let refunded = 0;
  const errors: string[] = [];
  for (const o of stale ?? []) {
    try {
      // CAS to status=refunded; bail if another worker already grabbed it.
      const { data: cas } = await svc
        .from("orders")
        .update({
          status: "refunded",
          refund_reason: "pickup_uncollected",
          refunded_at: new Date().toISOString(),
          pickup_qr_revoked_at: new Date().toISOString(),
        })
        .eq("id", o.id)
        .eq("status", "awaiting_pickup")
        .select("id")
        .maybeSingle();
      if (!cas) continue;

      await processRefund({
        supabase: svc,
        buyerId: o.buyer_id,
        businessId: o.business_id,
        grossAmount: Number(o.total_amount),
        orderId: o.id,
        paymentMethod: o.payment_method,
        reason: "pickup_uncollected",
        idempotencyKey: `pickup-uncollected-${o.id}`,
      });
      refunded++;
    } catch (e) {
      errors.push(`${o.id}: ${String(e).slice(0, 120)}`);
    }
  }

  return json({ ok: true, processed: stale?.length ?? 0, refunded, errors });
});
