// =============================================================================
// process-no-show — Handle appointment no-shows with partial refunds
// =============================================================================
// When a customer doesn't show up:
// 1. Mark appointment as no_show
// 2. Calculate refund: full_payment - deposit - 3% BC platform fee
// 3. Process refund via Stripe
// 4. Record payout to provider (they keep the deposit)
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

// BeautyCita platform fee: 3%
const PLATFORM_FEE_PERCENT = 0.03;

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

interface NoShowRequest {
  appointment_id: string;
  marked_by?: "business" | "system"; // who marked it as no-show
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Auth check - only business owners or admins can mark no-shows
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const body: NoShowRequest = await req.json();
    const { appointment_id, marked_by = "business" } = body;

    if (!appointment_id) {
      return json({ error: "appointment_id is required" }, 400);
    }

    // Fetch the appointment with related data
    const { data: appointment, error: fetchError } = await supabase
      .from("appointments")
      .select(`
        id,
        user_id,
        business_id,
        service_id,
        price,
        deposit_amount,
        payment_status,
        payment_intent_id,
        status,
        businesses!inner (
          id,
          name,
          owner_id,
          stripe_account_id
        ),
        services (
          deposit_required,
          deposit_percentage
        )
      `)
      .eq("id", appointment_id)
      .single();

    if (fetchError || !appointment) {
      return json({ error: "Appointment not found" }, 404);
    }

    // Verify caller is the business owner or admin
    const business = appointment.businesses as { id: string; name: string; owner_id: string; stripe_account_id: string };
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    const isAdmin = profile?.role === "admin" || profile?.role === "superadmin";
    const isOwner = business.owner_id === user.id;

    if (!isAdmin && !isOwner) {
      return json({ error: "Only the business owner can mark appointments as no-show" }, 403);
    }

    // Check appointment status
    if (appointment.status === "no_show") {
      return json({ error: "Appointment is already marked as no-show" }, 400);
    }

    if (appointment.status !== "confirmed") {
      return json({ error: "Only confirmed appointments can be marked as no-show" }, 400);
    }

    if (appointment.payment_status !== "paid") {
      return json({ error: "Appointment has not been paid" }, 400);
    }

    // Calculate refund amounts
    const totalPaid = appointment.price ?? 0;
    const service = appointment.services as { deposit_required: boolean; deposit_percentage: number } | null;

    let depositAmount = appointment.deposit_amount ?? 0;

    // If deposit wasn't pre-calculated, calculate from service settings
    if (depositAmount === 0 && service?.deposit_required) {
      depositAmount = (totalPaid * (service.deposit_percentage / 100));
    }

    // Platform fee is 3% of the total transaction
    const platformFee = Math.round(totalPaid * PLATFORM_FEE_PERCENT * 100) / 100;

    // Refund amount = total paid - deposit - platform fee
    // Customer gets back what they paid minus the deposit (kept by provider) and platform fee
    const refundAmount = Math.max(0, totalPaid - depositAmount - platformFee);

    // Provider payout = deposit amount (they keep this for the no-show)
    const providerPayout = depositAmount;

    console.log(`[NO-SHOW] Appointment ${appointment_id}:`);
    console.log(`  Total paid: $${totalPaid}`);
    console.log(`  Deposit: $${depositAmount}`);
    console.log(`  Platform fee (3%): $${platformFee}`);
    console.log(`  Refund to customer: $${refundAmount}`);
    console.log(`  Provider keeps: $${providerPayout}`);

    // Process the refund via Stripe
    let stripeRefund = null;
    if (refundAmount > 0 && appointment.payment_intent_id) {
      try {
        // Convert to centavos for Stripe
        const refundAmountCentavos = Math.round(refundAmount * 100);

        stripeRefund = await stripe.refunds.create({
          payment_intent: appointment.payment_intent_id,
          amount: refundAmountCentavos,
          reason: "requested_by_customer", // Stripe's closest option
          metadata: {
            appointment_id,
            reason: "no_show",
            deposit_amount: depositAmount.toString(),
            platform_fee: platformFee.toString(),
          },
        });

        console.log(`[NO-SHOW] Stripe refund created: ${stripeRefund.id}`);
      } catch (stripeErr) {
        console.error(`[NO-SHOW] Stripe refund failed:`, stripeErr);
        return json({
          error: "Failed to process refund",
          details: (stripeErr as Error).message
        }, 500);
      }
    }

    // Update the appointment
    const { error: updateError } = await supabase
      .from("appointments")
      .update({
        status: "no_show",
        payment_status: refundAmount > 0 ? "partial_refund" : "paid",
        refund_amount: refundAmount,
        platform_fee: platformFee,
        provider_payout: providerPayout,
        refunded_at: refundAmount > 0 ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", appointment_id);

    if (updateError) {
      console.error(`[NO-SHOW] Failed to update appointment:`, updateError);
      return json({ error: "Failed to update appointment status" }, 500);
    }

    // Record payment transactions
    const paymentRecords = [];

    // Record platform fee
    paymentRecords.push({
      appointment_id,
      amount: Math.round(platformFee * 100), // in centavos
      currency: "mxn",
      status: "succeeded",
      type: "platform_fee",
      metadata: { reason: "no_show" },
    });

    // Record refund
    if (refundAmount > 0) {
      paymentRecords.push({
        appointment_id,
        stripe_payment_intent_id: appointment.payment_intent_id,
        stripe_charge_id: stripeRefund?.charge as string | undefined,
        amount: -Math.round(refundAmount * 100), // negative for refund
        currency: "mxn",
        status: "succeeded",
        type: "refund",
        metadata: {
          reason: "no_show",
          stripe_refund_id: stripeRefund?.id,
        },
      });
    }

    // Record provider payout (what they keep)
    if (providerPayout > 0) {
      paymentRecords.push({
        appointment_id,
        amount: Math.round(providerPayout * 100), // in centavos
        currency: "mxn",
        status: "succeeded",
        type: "payout",
        metadata: {
          reason: "no_show_deposit",
          provider_stripe_account: business.stripe_account_id,
        },
      });
    }

    if (paymentRecords.length > 0) {
      await supabase.from("payments").insert(paymentRecords);
    }

    // Notify the customer
    try {
      const { data: customerProfile } = await supabase
        .from("profiles")
        .select("fcm_token")
        .eq("id", appointment.user_id)
        .single();

      if (customerProfile?.fcm_token) {
        await supabase.functions.invoke("send-push-notification", {
          body: {
            token: customerProfile.fcm_token,
            title: "Cita marcada como no asistida",
            body: refundAmount > 0
              ? `Se ha procesado un reembolso de $${refundAmount.toFixed(2)} MXN.`
              : `Tu deposito de $${depositAmount.toFixed(2)} MXN no sera reembolsado.`,
            data: {
              type: "no_show",
              appointment_id,
              refund_amount: refundAmount.toString(),
            },
          },
        });
      }

      // Create notification record
      await supabase.from("notifications").insert({
        user_id: appointment.user_id,
        type: "no_show",
        title: "Cita marcada como no asistida",
        body: refundAmount > 0
          ? `Se ha procesado un reembolso de $${refundAmount.toFixed(2)} MXN. El deposito de $${depositAmount.toFixed(2)} y la comision de servicio no son reembolsables.`
          : `No hubo reembolso porque el deposito cubre el costo del servicio.`,
        data: {
          appointment_id,
          refund_amount: refundAmount,
          deposit_retained: depositAmount,
          platform_fee: platformFee,
        },
      });
    } catch (notifyErr) {
      console.error(`[NO-SHOW] Failed to notify customer:`, notifyErr);
      // Don't fail the whole operation for notification errors
    }

    return json({
      success: true,
      appointment_id,
      total_paid: totalPaid,
      deposit_retained: depositAmount,
      platform_fee: platformFee,
      refund_amount: refundAmount,
      provider_payout: providerPayout,
      stripe_refund_id: stripeRefund?.id ?? null,
    });

  } catch (err) {
    console.error("[NO-SHOW] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
