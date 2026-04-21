// =============================================================================
// process-dispute-refund — Process refund for resolved disputes
// =============================================================================
// Handles BOTH appointment disputes and product order disputes.
// All refunds go to buyer saldo + seller debt. Never to card.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireFeature } from "../_shared/check-toggle.ts";
import { corsHeaders as dynamicCors } from "../_shared/cors.ts";
import { processRefund } from "../_shared/refund.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface DisputeRefundRequest {
  dispute_id: string;
}

let _req: Request;

serve(async (req) => {
  _req = req;
  const corsHeaders = dynamicCors(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const blocked = await requireFeature("enable_disputes");
  if (blocked) return blocked;

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Auth check
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    // Admin role check
    const { data: callerProfile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    const callerRole = callerProfile?.role;
    if (callerRole !== "admin" && callerRole !== "superadmin") {
      return json({ error: "Admin access required to process refunds" }, 403);
    }

    const body: DisputeRefundRequest = await req.json();
    const { dispute_id } = body;

    if (!dispute_id) {
      return json({ error: "dispute_id is required" }, 400);
    }

    // Fetch dispute
    const { data: dispute, error: fetchError } = await supabase
      .from("disputes")
      .select("id, user_id, business_id, appointment_id, order_id, refund_amount, refund_status, resolution, status")
      .eq("id", dispute_id)
      .single();

    if (fetchError || !dispute) {
      console.error("[DISPUTE-REFUND] Fetch error:", fetchError);
      return json({ error: "Dispute not found" }, 404);
    }

    if (dispute.refund_status === "processed") {
      return json({ success: true, already_processed: true });
    }

    if (dispute.refund_status !== "pending") {
      return json({ error: `Refund status is '${dispute.refund_status}', expected 'pending'` }, 400);
    }

    const refundAmount = dispute.refund_amount as number;
    if (!refundAmount || refundAmount <= 0) {
      return json({ error: "No refund amount set on dispute" }, 400);
    }

    const isOrderDispute = !!dispute.order_id && !dispute.appointment_id;

    console.log(`[DISPUTE-REFUND] Dispute ${dispute_id}: $${refundAmount}, type=${isOrderDispute ? "order" : "appointment"}`);

    // ── Atomic compare-and-swap on refund_status ──────────────────────
    // Two rapid admin clicks could both pass the read-then-update check
    // above and double-refund. Mark refund_status='processing' BEFORE
    // calling processRefund. The .eq('refund_status', 'pending') filter
    // ensures only one writer wins. The downstream processRefund itself
    // is idempotent via increment_saldo's idempotencyKey, but mutating
    // status first prevents wasted work and makes intent clear.
    const { data: lockedRows, error: lockErr } = await supabase
      .from("disputes")
      .update({ refund_status: "processing" })
      .eq("id", dispute_id)
      .eq("refund_status", "pending")
      .select("id");
    if (lockErr) {
      console.error("[DISPUTE-REFUND] Lock error:", lockErr);
      return json({ error: "Failed to acquire lock on dispute" }, 500);
    }
    if (!lockedRows || lockedRows.length === 0) {
      // Another caller beat us to it
      return json({ success: true, already_processed: true });
    }

    // Look up original order payment method to decide whether commission reversal applies
    let orderPaymentMethod: string | null = null;
    if (isOrderDispute && dispute.order_id) {
      const { data: orderRow } = await supabase
        .from("orders")
        .select("payment_method")
        .eq("id", dispute.order_id)
        .maybeSingle();
      orderPaymentMethod = orderRow?.payment_method ?? null;
    }

    // Process refund: saldo credit to buyer + debt to seller + tax reversal
    const result = await processRefund({
      supabase,
      buyerId: dispute.user_id,
      businessId: dispute.business_id,
      grossAmount: refundAmount,
      appointmentId: dispute.appointment_id ?? undefined,
      orderId: dispute.order_id ?? undefined,
      paymentMethod: orderPaymentMethod,
      reason: `dispute_${dispute_id}`,
      idempotencyKey: `dispute-refund-${dispute_id}`,
    });

    // Update dispute: refund_status → processed
    await supabase.from("disputes").update({ refund_status: "processed" }).eq("id", dispute_id);

    // Update source record
    if (isOrderDispute) {
      await supabase.from("orders").update({
        status: "refunded",
        refunded_at: new Date().toISOString(),
      }).eq("id", dispute.order_id);
    } else {
      await supabase.from("appointments").update({
        payment_status: "refunded_to_saldo",
        refund_amount: refundAmount,
        refunded_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", dispute.appointment_id);
    }

    // Notify client
    try {
      const refType = isOrderDispute ? "pedido" : "cita";

      await supabase.from("notifications").insert({
        user_id: dispute.user_id,
        type: "dispute_refund",
        title: "Reembolso procesado",
        body: `Se agrego $${result.saldoCredit.toFixed(2)} MXN a tu saldo por la disputa de tu ${refType}.`,
        data: {
          dispute_id,
          ...(isOrderDispute ? { order_id: dispute.order_id } : { appointment_id: dispute.appointment_id }),
          saldo_credit: result.saldoCredit,
        },
      });

      // Push notification
      const { data: customerProfile } = await supabase
        .from("profiles")
        .select("fcm_token")
        .eq("id", dispute.user_id)
        .single();

      if (customerProfile?.fcm_token) {
        await supabase.functions.invoke("send-push-notification", {
          body: {
            token: customerProfile.fcm_token,
            title: "Reembolso procesado",
            body: `Se agrego $${result.saldoCredit.toFixed(2)} MXN a tu saldo.`,
            data: { type: "dispute_refund", dispute_id, saldo_credit: result.saldoCredit.toString() },
          },
        });
      }
    } catch (notifyErr) {
      console.error("[DISPUTE-REFUND] Failed to notify client:", notifyErr);
    }

    return json({
      success: true,
      saldo_credit: result.saldoCredit,
      debt_created: result.debtCreated,
      processing_fee: result.processingFee,
      tax_reversed: result.taxReversed,
      dispute_type: isOrderDispute ? "order" : "appointment",
    });

  } catch (err) {
    console.error("[DISPUTE-REFUND] Error:", err);
    return json({ error: "An internal error occurred" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...dynamicCors(_req), "Content-Type": "application/json" },
  });
}
