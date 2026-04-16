// =============================================================================
// process-dispute-refund — Process Stripe refund for resolved disputes
// =============================================================================
// Handles BOTH appointment disputes and product order disputes.
// When a dispute resolves with a refund (admin, salon full_refund, or client
// accepts partial_refund):
// 1. Validate dispute has pending refund
// 2. Detect dispute type (appointment vs order)
// 3. Look up payment_intent_id from the correct source
// 4. Call stripe.refunds.create()
// 5. For orders: partial application fee refund (keep 3%, return 7%)
// 6. Update dispute refund_status → processed
// 7. Update source record (appointment or order)
// 8. Record commission reversal for orders
// 9. Notify client
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { requireFeature } from "../_shared/check-toggle.ts";
import { corsHeaders as dynamicCors } from "../_shared/cors.ts";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

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

    // Admin role check — only admin/superadmin can process dispute refunds
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

    // Fetch dispute base data (without nested joins — we detect type first)
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

    // Detect dispute type and get payment intent
    const isOrderDispute = !!dispute.order_id && !dispute.appointment_id;
    let paymentIntentId: string | null = null;
    let sourcePrice = 0;
    let commissionAmount = 0;

    if (isOrderDispute) {
      // --- ORDER DISPUTE ---
      const { data: order } = await supabase
        .from("orders")
        .select("id, total_amount, commission_amount, stripe_payment_intent_id, status")
        .eq("id", dispute.order_id)
        .single();

      if (!order) return json({ error: "Order not found" }, 404);

      paymentIntentId = order.stripe_payment_intent_id;
      sourcePrice = order.total_amount;
      commissionAmount = order.commission_amount ?? 0;
      console.log(`[DISPUTE-REFUND] Order dispute: order ${order.id}, PI ${paymentIntentId}`);
    } else {
      // --- APPOINTMENT DISPUTE ---
      const { data: appointment } = await supabase
        .from("appointments")
        .select("id, price, payment_intent_id, payment_status")
        .eq("id", dispute.appointment_id)
        .single();

      if (!appointment) return json({ error: "Appointment not found" }, 404);

      paymentIntentId = appointment.payment_intent_id;
      sourcePrice = appointment.price ?? 0;
      console.log(`[DISPUTE-REFUND] Appointment dispute: appt ${appointment.id}, PI ${paymentIntentId}`);
    }

    // No payment_intent_id — unpaid/test
    if (!paymentIntentId) {
      await supabase.from("disputes").update({ refund_status: "not_applicable" }).eq("id", dispute_id);
      return json({ success: true, refund_amount: 0, stripe_refund_id: null, skipped: "no_payment_intent" });
    }

    // Process the Stripe refund
    const refundAmountCentavos = Math.round(refundAmount * 100);
    const isFullRefund = refundAmount >= sourcePrice;

    console.log(`[DISPUTE-REFUND] Dispute ${dispute_id}: $${refundAmount} (${refundAmountCentavos} centavos), full=${isFullRefund}`);

    let stripeRefund;
    try {
      stripeRefund = await stripe.refunds.create({
        payment_intent: paymentIntentId,
        amount: refundAmountCentavos,
        reason: "requested_by_customer",
        metadata: {
          dispute_id,
          ...(isOrderDispute ? { order_id: dispute.order_id } : { appointment_id: dispute.appointment_id }),
          resolution: dispute.resolution ?? "dispute_refund",
        },
      }, { idempotencyKey: `dispute-refund-${dispute_id}` });
      console.log(`[DISPUTE-REFUND] Stripe refund created: ${stripeRefund.id}`);
    } catch (stripeErr) {
      console.error(`[DISPUTE-REFUND] Stripe refund failed:`, stripeErr);
      return json({ error: "Failed to process Stripe refund", details: (stripeErr as Error).message }, 500);
    }

    // For order disputes: partial application fee refund (keep 3%, return 7%)
    if (isOrderDispute && isFullRefund && commissionAmount > 0) {
      const keepRate = 0.03;
      const keepAmount = Math.round(sourcePrice * keepRate * 100) / 100;
      const returnCentavos = Math.round(Math.max(commissionAmount - keepAmount, 0) * 100);

      if (returnCentavos > 0) {
        try {
          const charges = await stripe.charges.list({ payment_intent: paymentIntentId, limit: 1 });
          const feeId = charges.data[0]?.application_fee as string;
          if (feeId) {
            await stripe.applicationFees.createRefund(feeId, { amount: returnCentavos });
            console.log(`[DISPUTE-REFUND] Returned ${returnCentavos} centavos commission to seller`);
          }
        } catch (feeErr) {
          console.error(`[DISPUTE-REFUND] Commission return failed:`, (feeErr as Error).message);
        }

        // Record commission reversal
        await supabase.from("commission_records").insert({
          business_id: dispute.business_id,
          order_id: dispute.order_id,
          amount: -(Math.round((commissionAmount - keepAmount) * 100) / 100),
          rate: 0.07,
          source: "product_sale_reversal",
          period_month: new Date().getMonth() + 1,
          period_year: new Date().getFullYear(),
          status: "collected",
        }).then(null, (e: Error) => console.error(`[DISPUTE-REFUND] Commission reversal record failed: ${e.message}`));
      }
    }

    // Update dispute: refund_status → processed
    await supabase.from("disputes").update({ refund_status: "processed" }).eq("id", dispute_id)
      .then(null, (e: Error) => console.error("[DISPUTE-REFUND] Failed to update dispute:", e.message));

    // Update source record
    if (isOrderDispute) {
      const returnToSeller = commissionAmount > 0
        ? Math.round((commissionAmount - Math.round(sourcePrice * 0.03 * 100) / 100) * 100) / 100
        : 0;
      await supabase.from("orders").update({
        status: "refunded",
        refunded_at: new Date().toISOString(),
        commission_refund_amount: returnToSeller,
      }).eq("id", dispute.order_id);
    } else {
      const newPaymentStatus = isFullRefund ? "refunded" : "partial_refund";
      await supabase.from("appointments").update({
        payment_status: newPaymentStatus,
        refund_amount: refundAmount,
        refunded_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", dispute.appointment_id);

      // Record in payments table (appointment refunds only)
      await supabase.from("payments").insert({
        appointment_id: dispute.appointment_id,
        stripe_payment_intent_id: paymentIntentId,
        stripe_charge_id: stripeRefund.charge as string | undefined,
        amount: -Math.round(refundAmount * 100),
        currency: "mxn",
        status: "succeeded",
        type: "refund",
        metadata: {
          reason: "dispute_refund",
          dispute_id,
          stripe_refund_id: stripeRefund.id,
          resolution: dispute.resolution,
        },
      });
    }

    // Notify client
    try {
      const { data: customerProfile } = await supabase
        .from("profiles")
        .select("fcm_token")
        .eq("id", dispute.user_id)
        .single();

      const refType = isOrderDispute ? "pedido" : "cita";

      await supabase.from("notifications").insert({
        user_id: dispute.user_id,
        type: "dispute_refund",
        title: "Reembolso procesado",
        body: `Se ha procesado tu reembolso de $${refundAmount.toFixed(2)} MXN por la disputa de tu ${refType}.`,
        data: {
          dispute_id,
          ...(isOrderDispute ? { order_id: dispute.order_id } : { appointment_id: dispute.appointment_id }),
          refund_amount: refundAmount,
          stripe_refund_id: stripeRefund.id,
        },
      });

      if (customerProfile?.fcm_token) {
        await supabase.functions.invoke("send-push-notification", {
          body: {
            token: customerProfile.fcm_token,
            title: "Reembolso procesado",
            body: `Se ha procesado un reembolso de $${refundAmount.toFixed(2)} MXN.`,
            data: {
              type: "dispute_refund",
              dispute_id,
              refund_amount: refundAmount.toString(),
            },
          },
        });
      }
    } catch (notifyErr) {
      console.error("[DISPUTE-REFUND] Failed to notify client:", notifyErr);
    }

    return json({
      success: true,
      refund_amount: refundAmount,
      stripe_refund_id: stripeRefund.id,
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
