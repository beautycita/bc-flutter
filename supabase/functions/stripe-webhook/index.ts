// =============================================================================
// stripe-webhook — Handle Stripe webhook events for BeautyCita
// =============================================================================
// Handles:
// - account.updated: When Stripe Connect Express account completes onboarding
// - payment_intent.succeeded: When a payment is confirmed
// - checkout.session.completed: For booking payments
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, stripe-signature",
};

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const signature = req.headers.get("stripe-signature");
    if (!signature) {
      return new Response(JSON.stringify({ error: "Missing stripe-signature header" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.text();

    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(body, signature, STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      console.error("Webhook signature verification failed:", (err as Error).message);
      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    console.log(`[STRIPE-WEBHOOK] Processing event: ${event.type}`);

    switch (event.type) {
      // =======================================================================
      // Stripe Connect Express - Account Updates
      // =======================================================================
      case "account.updated": {
        const account = event.data.object as Stripe.Account;

        // Check if onboarding is complete
        const chargesEnabled = account.charges_enabled;
        const payoutsEnabled = account.payouts_enabled;
        const detailsSubmitted = account.details_submitted;

        if (chargesEnabled && payoutsEnabled && detailsSubmitted) {
          console.log(`[STRIPE-WEBHOOK] Account ${account.id} onboarding complete`);

          // Find and update the business
          const { data: business, error: findError } = await supabase
            .from("businesses")
            .select("id, name")
            .eq("stripe_account_id", account.id)
            .single();

          if (findError || !business) {
            console.error(`[STRIPE-WEBHOOK] Business not found for account ${account.id}`);
            break;
          }

          // Mark onboarding as complete
          const { error: updateError } = await supabase
            .from("businesses")
            .update({
              onboarding_complete: true,
              stripe_charges_enabled: true,
              stripe_payouts_enabled: true,
              stripe_details_submitted: true,
              updated_at: new Date().toISOString(),
            })
            .eq("id", business.id);

          if (updateError) {
            console.error(`[STRIPE-WEBHOOK] Failed to update business: ${updateError.message}`);
          } else {
            console.log(`[STRIPE-WEBHOOK] Business ${business.name} marked as onboarding complete`);

            // Send notification to business owner
            await notifyBusinessOnboarded(supabase, business.id, business.name);
          }
        } else {
          // Onboarding not yet complete - update individual flags
          const { data: business } = await supabase
            .from("businesses")
            .select("id")
            .eq("stripe_account_id", account.id)
            .single();

          if (business) {
            await supabase
              .from("businesses")
              .update({
                stripe_charges_enabled: chargesEnabled,
                stripe_payouts_enabled: payoutsEnabled,
                stripe_details_submitted: detailsSubmitted,
                updated_at: new Date().toISOString(),
              })
              .eq("id", business.id);
          }
        }
        break;
      }

      // =======================================================================
      // Payment Intents - Booking Payments
      // =======================================================================
      case "payment_intent.succeeded": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const bookingId = paymentIntent.metadata?.booking_id;

        if (!bookingId) {
          console.log(`[STRIPE-WEBHOOK] payment_intent.succeeded without booking_id metadata`);
          break;
        }

        console.log(`[STRIPE-WEBHOOK] Payment succeeded for booking ${bookingId}`);

        // Update booking payment status
        const { error: updateError } = await supabase
          .from("appointments")
          .update({
            payment_status: "paid",
            payment_intent_id: paymentIntent.id,
            paid_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", bookingId);

        if (updateError) {
          console.error(`[STRIPE-WEBHOOK] Failed to update booking payment: ${updateError.message}`);
        } else {
          // Create payment record
          await supabase.from("payments").insert({
            appointment_id: bookingId,
            stripe_payment_intent_id: paymentIntent.id,
            amount: paymentIntent.amount,
            currency: paymentIntent.currency,
            status: "succeeded",
            created_at: new Date().toISOString(),
          });
        }
        break;
      }

      case "payment_intent.payment_failed": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const bookingId = paymentIntent.metadata?.booking_id;

        if (!bookingId) break;

        console.log(`[STRIPE-WEBHOOK] Payment failed for booking ${bookingId}`);

        await supabase
          .from("appointments")
          .update({
            payment_status: "failed",
            updated_at: new Date().toISOString(),
          })
          .eq("id", bookingId);
        break;
      }

      // =======================================================================
      // Checkout Sessions - For complete booking + payment flow
      // =======================================================================
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const bookingId = session.metadata?.booking_id;

        if (!bookingId) {
          console.log(`[STRIPE-WEBHOOK] checkout.session.completed without booking_id`);
          break;
        }

        console.log(`[STRIPE-WEBHOOK] Checkout completed for booking ${bookingId}`);

        await supabase
          .from("appointments")
          .update({
            payment_status: "paid",
            stripe_checkout_session_id: session.id,
            paid_at: new Date().toISOString(),
            status: "confirmed", // Auto-confirm paid bookings
            confirmed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", bookingId);
        break;
      }

      // =======================================================================
      // Refunds
      // =======================================================================
      case "charge.refunded": {
        const charge = event.data.object as Stripe.Charge;
        const paymentIntentId = charge.payment_intent as string;

        if (!paymentIntentId) break;

        console.log(`[STRIPE-WEBHOOK] Refund processed for payment ${paymentIntentId}`);

        // Find the booking by payment intent
        const { data: booking } = await supabase
          .from("appointments")
          .select("id")
          .eq("payment_intent_id", paymentIntentId)
          .single();

        if (booking) {
          await supabase
            .from("appointments")
            .update({
              payment_status: "refunded",
              refunded_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq("id", booking.id);

          await supabase.from("payments").insert({
            appointment_id: booking.id,
            stripe_payment_intent_id: paymentIntentId,
            amount: -charge.amount_refunded,
            currency: charge.currency,
            status: "refunded",
            created_at: new Date().toISOString(),
          });
        }
        break;
      }

      default:
        console.log(`[STRIPE-WEBHOOK] Unhandled event type: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("[STRIPE-WEBHOOK] Error:", (err as Error).message);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ---------------------------------------------------------------------------
// Helper: Notify business owner when onboarding completes
// ---------------------------------------------------------------------------
async function notifyBusinessOnboarded(
  supabase: ReturnType<typeof createClient>,
  businessId: string,
  businessName: string
) {
  try {
    // Get business owner
    const { data: business } = await supabase
      .from("businesses")
      .select("owner_id")
      .eq("id", businessId)
      .single();

    if (!business?.owner_id) return;

    // Create notification
    await supabase.from("notifications").insert({
      user_id: business.owner_id,
      type: "onboarding_complete",
      title: "Onboarding completado",
      body: `${businessName} ya puede recibir pagos y reservas en BeautyCita.`,
      data: { business_id: businessId },
      created_at: new Date().toISOString(),
    });

    // Get FCM token and send push notification
    const { data: profile } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", business.owner_id)
      .single();

    if (profile?.fcm_token) {
      await supabase.functions.invoke("send-push-notification", {
        body: {
          token: profile.fcm_token,
          title: "Onboarding completado",
          body: `${businessName} ya puede recibir pagos y reservas.`,
          data: { type: "onboarding_complete", business_id: businessId },
        },
      });
    }
  } catch (err) {
    console.error("[STRIPE-WEBHOOK] Failed to notify business owner:", err);
  }
}
