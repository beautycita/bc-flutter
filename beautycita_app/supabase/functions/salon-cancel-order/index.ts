// =============================================================================
// salon-cancel-order — Salon-initiated order cancel + refund
// =============================================================================
// F3 fix from POS audit: salons that realize they can't fulfill (out-of-stock
// after payment, item broke, etc.) had no way to cancel without waiting for
// the day-14 auto-refund. Now they can self-cancel any `paid` or `shipped`
// order — buyer gets saldo immediately, seller eats the debt.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { requireFeature } from "../_shared/check-toggle.ts";
import { checkRateLimit } from "../_shared/rate-limit.ts";
import { processRefund } from "../_shared/refund.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

let _req: Request;
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  _req = req;
  const preflight = handleCorsPreflightIfOptions(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const blocked = await requireFeature("enable_pos");
  if (blocked) return blocked;

  // Auth — caller must be a business owner
  const authHeader = req.headers.get("authorization") ?? "";
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) return json({ error: "Unauthorized" }, 401);

  if (!checkRateLimit(`sco:${user.id}`, 10, 60_000)) {
    return json({ error: "Too many requests" }, 429);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const { order_id, reason } = body as Record<string, string | undefined>;
  if (typeof order_id !== "string" || !order_id) {
    return json({ error: "order_id required" }, 400);
  }
  if (typeof reason !== "string" || reason.trim().length < 3) {
    return json({ error: "reason required (>=3 chars)" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Fetch + verify ownership
  const { data: order } = await supabase
    .from("orders")
    .select("id, buyer_id, business_id, product_name, total_amount, payment_method, status, businesses!inner(owner_id, name)")
    .eq("id", order_id)
    .maybeSingle();

  if (!order) return json({ error: "Order not found" }, 404);
  const ownerId = (order.businesses as Record<string, unknown>)?.owner_id as string | undefined;
  if (ownerId !== user.id) return json({ error: "Forbidden" }, 403);

  if (!["paid", "awaiting_pickup", "shipped"].includes(order.status as string)) {
    return json({ error: `Cannot cancel order in status '${order.status}'` }, 409);
  }

  // Atomic status flip — only one caller wins the race. Also revoke any
  // outstanding pickup QR so a stale token can't be redeemed post-cancel.
  const { data: claimed, error: claimErr } = await supabase
    .from("orders")
    .update({
      status: "refunded",
      refund_reason: "salon_cancel",
      refunded_at: new Date().toISOString(),
      pickup_qr_revoked_at: new Date().toISOString(),
    })
    .eq("id", order.id)
    .in("status", ["paid", "awaiting_pickup", "shipped"])
    .select("id");

  if (claimErr) {
    console.error("[salon-cancel-order] claim error:", claimErr);
    return json({ error: "Could not claim order for cancellation" }, 500);
  }
  if (!claimed || claimed.length === 0) {
    return json({ error: "Order was finalized by another call; retry." }, 409);
  }

  // Refund: saldo credit to buyer + debt to seller (no card refund)
  try {
    const result = await processRefund({
      supabase,
      buyerId: order.buyer_id as string,
      businessId: order.business_id as string,
      grossAmount: order.total_amount as number,
      orderId: order.id as string,
      paymentMethod: order.payment_method as string | null,
      reason: `salon_cancel: ${reason.slice(0, 200)}`,
      idempotencyKey: `salon-cancel-${order.id}`,
    });

    // Notify buyer
    const shortId = (order.id as string).slice(0, 8).toUpperCase();
    const productName = (order.product_name as string | null) ?? "producto";
    const businessName = (order.businesses as Record<string, unknown>)?.name as string | undefined ?? "El salon";

    try {
      await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user_id: order.buyer_id,
          notification_type: "new_booking",
          custom_title: "Pedido cancelado por el vendedor",
          custom_body: `${businessName} cancelo tu pedido de ${productName} (#${shortId}). Se credito $${result.saldoCredit.toFixed(2)} a tu saldo.`,
          data: { type: "order_salon_cancelled", order_id: order.id },
        }),
      });
    } catch (e) {
      console.error(`[salon-cancel-order] Buyer push failed: ${(e as Error).message}`);
    }

    return json({
      success: true,
      saldo_credit: result.saldoCredit,
      debt_created: result.debtCreated,
      processing_fee: result.processingFee,
    });
  } catch (err) {
    console.error("[salon-cancel-order] Refund error:", err);
    // Best-effort: unwind the cancel if refund fails so we don't orphan the buyer
    await supabase.from("orders")
      .update({ status: "paid", refunded_at: null })
      .eq("id", order.id);
    return json({ error: "Refund processing failed; cancellation reverted" }, 500);
  }
});
