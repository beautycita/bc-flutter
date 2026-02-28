// =============================================================================
// process-dispute-refund — Process Stripe refund for resolved disputes
// =============================================================================
// When a dispute resolves with a refund (admin, salon full_refund, or client
// accepts partial_refund):
// 1. Validate dispute has pending refund
// 2. Look up appointment payment_intent_id and business stripe_account_id
// 3. Call stripe.refunds.create()
// 4. Update dispute refund_status → processed
// 5. Update appointment payment_status + refunded_at
// 6. Record in payments table
// 7. Notify client
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Auth check
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body: DisputeRefundRequest = await req.json();
    const { dispute_id } = body;

    if (!dispute_id) {
      return json({ error: "dispute_id is required" }, 400);
    }

    // Fetch dispute with appointment and business data
    const { data: dispute, error: fetchError } = await supabase
      .from("disputes")
      .select(`
        id,
        user_id,
        appointment_id,
        refund_amount,
        refund_status,
        resolution,
        status,
        appointments!inner (
          id,
          user_id,
          business_id,
          price,
          payment_intent_id,
          payment_status,
          businesses!inner (
            id,
            name,
            owner_id,
            stripe_account_id
          )
        )
      `)
      .eq("id", dispute_id)
      .single();

    if (fetchError || !dispute) {
      console.error("[DISPUTE-REFUND] Fetch error:", fetchError);
      return json({ error: "Dispute not found" }, 404);
    }

    // Already processed — return early with success
    if (dispute.refund_status === "processed") {
      return json({ success: true, already_processed: true });
    }

    // Must be pending
    if (dispute.refund_status !== "pending") {
      return json({ error: `Refund status is '${dispute.refund_status}', expected 'pending'` }, 400);
    }

    const refundAmount = dispute.refund_amount as number;
    if (!refundAmount || refundAmount <= 0) {
      return json({ error: "No refund amount set on dispute" }, 400);
    }

    // Verify caller is admin, business owner, or the dispute's client
    const appointment = dispute.appointments as {
      id: string;
      user_id: string;
      business_id: string;
      price: number;
      payment_intent_id: string | null;
      payment_status: string;
      businesses: {
        id: string;
        name: string;
        owner_id: string;
        stripe_account_id: string | null;
      };
    };

    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    const isAdmin = profile?.role === "admin" || profile?.role === "superadmin";
    const isOwner = appointment.businesses.owner_id === user.id;
    const isClient = dispute.user_id === user.id;

    if (!isAdmin && !isOwner && !isClient) {
      return json({ error: "Not authorized to process this refund" }, 403);
    }

    // No payment_intent_id — unpaid/test appointment
    if (!appointment.payment_intent_id) {
      console.log(`[DISPUTE-REFUND] No payment_intent_id for dispute ${dispute_id}, marking not_applicable`);

      await supabase
        .from("disputes")
        .update({ refund_status: "not_applicable" })
        .eq("id", dispute_id);

      return json({
        success: true,
        refund_amount: 0,
        stripe_refund_id: null,
        skipped: "no_payment_intent",
      });
    }

    // Process the Stripe refund
    const refundAmountCentavos = Math.round(refundAmount * 100);
    const isFullRefund = refundAmount >= (appointment.price ?? 0);

    console.log(`[DISPUTE-REFUND] Dispute ${dispute_id}:`);
    console.log(`  Refund amount: $${refundAmount} (${refundAmountCentavos} centavos)`);
    console.log(`  Payment intent: ${appointment.payment_intent_id}`);
    console.log(`  Full refund: ${isFullRefund}`);

    let stripeRefund;
    try {
      stripeRefund = await stripe.refunds.create({
        payment_intent: appointment.payment_intent_id,
        amount: refundAmountCentavos,
        reason: "requested_by_customer",
        metadata: {
          dispute_id,
          appointment_id: appointment.id,
          resolution: dispute.resolution ?? "dispute_refund",
        },
      });

      console.log(`[DISPUTE-REFUND] Stripe refund created: ${stripeRefund.id}`);
    } catch (stripeErr) {
      console.error(`[DISPUTE-REFUND] Stripe refund failed:`, stripeErr);
      return json({
        error: "Failed to process Stripe refund",
        details: (stripeErr as Error).message,
      }, 500);
    }

    // Update dispute: refund_status → processed
    const { error: disputeUpdateError } = await supabase
      .from("disputes")
      .update({ refund_status: "processed" })
      .eq("id", dispute_id);

    if (disputeUpdateError) {
      console.error("[DISPUTE-REFUND] Failed to update dispute:", disputeUpdateError);
    }

    // Update appointment: payment_status + refund fields
    const newPaymentStatus = isFullRefund ? "refunded" : "partial_refund";
    const { error: apptUpdateError } = await supabase
      .from("appointments")
      .update({
        payment_status: newPaymentStatus,
        refund_amount: refundAmount,
        refunded_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", appointment.id);

    if (apptUpdateError) {
      console.error("[DISPUTE-REFUND] Failed to update appointment:", apptUpdateError);
    }

    // Record in payments table
    await supabase.from("payments").insert({
      appointment_id: appointment.id,
      stripe_payment_intent_id: appointment.payment_intent_id,
      stripe_charge_id: stripeRefund.charge as string | undefined,
      amount: -Math.round(refundAmount * 100), // negative for refund
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

    // Notify client
    try {
      const { data: customerProfile } = await supabase
        .from("profiles")
        .select("fcm_token")
        .eq("id", dispute.user_id)
        .single();

      // In-app notification
      await supabase.from("notifications").insert({
        user_id: dispute.user_id,
        type: "dispute_refund",
        title: "Reembolso procesado",
        body: `Se ha procesado tu reembolso de $${refundAmount.toFixed(2)} MXN por la disputa resuelta.`,
        data: {
          dispute_id,
          appointment_id: appointment.id,
          refund_amount: refundAmount,
          stripe_refund_id: stripeRefund.id,
        },
      });

      // Push notification if FCM token exists
      if (customerProfile?.fcm_token) {
        await supabase.functions.invoke("send-push-notification", {
          body: {
            token: customerProfile.fcm_token,
            title: "Reembolso procesado",
            body: `Se ha procesado un reembolso de $${refundAmount.toFixed(2)} MXN.`,
            data: {
              type: "dispute_refund",
              dispute_id,
              appointment_id: appointment.id,
              refund_amount: refundAmount.toString(),
            },
          },
        });
      }
    } catch (notifyErr) {
      console.error("[DISPUTE-REFUND] Failed to notify client:", notifyErr);
      // Don't fail the whole operation for notification errors
    }

    return json({
      success: true,
      refund_amount: refundAmount,
      stripe_refund_id: stripeRefund.id,
      payment_status: newPaymentStatus,
    });

  } catch (err) {
    console.error("[DISPUTE-REFUND] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
