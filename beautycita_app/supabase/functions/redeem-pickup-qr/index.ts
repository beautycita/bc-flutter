// =============================================================================
// redeem-pickup-qr — Salon scans buyer's QR; flips order awaiting_pickup→delivered
// =============================================================================
// Caller: salon owner (authenticated; future: staff with staff_can_scan_pickups).
// CAS on status='awaiting_pickup' so concurrent scans don't double-redeem.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

async function sha256Hex(s: string): Promise<string> {
  const buf = new TextEncoder().encode(s);
  const hash = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

serve(async (req) => {
  const cors = handleCorsPreflightIfOptions(req);
  if (cors) return cors;
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), {
      status: s,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });

  try {
    const auth = req.headers.get("Authorization") ?? "";
    const jwt = auth.replace("Bearer ", "");
    if (!jwt) return json({ error: "Unauthorized" }, 401);

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) return json({ error: "Unauthorized" }, 401);

    const body = await req.json();
    const cleartext = body.token as string | undefined;
    if (!cleartext) return json({ error: "token required" }, 400);

    const hash = await sha256Hex(cleartext);
    const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Lookup the order by hash (only unrevoked tokens are indexed).
    const { data: order } = await svc
      .from("orders")
      .select("id, buyer_id, business_id, status, fulfillment_method, pickup_qr_expires_at, picked_up_at, product_name")
      .eq("pickup_qr_token_hash", hash)
      .is("pickup_qr_revoked_at", null)
      .maybeSingle();

    if (!order) return json({ error: "Token not found or revoked" }, 404);

    // Idempotent re-scan: if already redeemed, return a friendly success.
    if (order.picked_up_at && order.status === "delivered") {
      return json({
        ok: true,
        already_redeemed: true,
        order_id: order.id,
        product_name: order.product_name,
      });
    }

    if (order.status !== "awaiting_pickup") {
      return json({ error: `Order status is ${order.status}` }, 409);
    }
    if (order.fulfillment_method !== "pickup") {
      return json({ error: "Order is not a pickup order" }, 409);
    }
    if (order.pickup_qr_expires_at && new Date(order.pickup_qr_expires_at) < new Date()) {
      return json({ error: "QR expired — buyer must regenerate" }, 410);
    }

    // Verify caller is owner of order's business.
    const { data: biz } = await svc
      .from("businesses")
      .select("id, name, owner_id")
      .eq("id", order.business_id)
      .single();
    if (!biz || biz.owner_id !== user.id) {
      return json({ error: "Forbidden — not owner of this salon" }, 403);
    }

    // Read claim window length from app_config.
    const { data: cfg } = await svc
      .from("app_config")
      .select("value")
      .eq("key", "pos_pickup_claim_window_days")
      .single();
    const windowDays = parseInt(cfg?.value ?? "7");
    const now = new Date();
    const claimWindowEndsAt = new Date(now.getTime() + windowDays * 86400_000);

    // CAS on status to prevent races.
    const { data: updated, error: updErr } = await svc
      .from("orders")
      .update({
        status: "delivered",
        picked_up_at: now.toISOString(),
        pickup_qr_revoked_at: now.toISOString(),
        claim_window_ends_at: claimWindowEndsAt.toISOString(),
      })
      .eq("id", order.id)
      .eq("status", "awaiting_pickup")
      .select("id")
      .maybeSingle();

    if (updErr) {
      return json({ error: `Redeem failed: ${updErr.message}` }, 500);
    }
    if (!updated) {
      // Lost the race; another scan got there first.
      return json({
        ok: true,
        already_redeemed: true,
        order_id: order.id,
        product_name: order.product_name,
      });
    }

    // Audit log
    await svc.from("audit_log").insert({
      admin_id: user.id,
      action: "redeem_pickup_qr",
      target_type: "order",
      target_id: order.id,
      details: { business_id: biz.id, product_name: order.product_name },
    }).catch(() => null);

    return json({
      ok: true,
      order_id: order.id,
      product_name: order.product_name,
      business_name: biz.name,
      claim_window_ends_at: claimWindowEndsAt.toISOString(),
      picked_up_at: now.toISOString(),
    });
  } catch (e) {
    console.error("[redeem-pickup-qr]", e);
    return json({ error: String(e).slice(0, 200) }, 500);
  }
});
