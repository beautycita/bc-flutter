// =============================================================================
// create-payment-intent — Create Stripe PaymentIntent for booking
// =============================================================================
// Creates a PaymentIntent for booking a service, with support for:
// - Deposit-only payments (if service requires deposit)
// - Full payments
// - Split payments to provider's Stripe Connect account
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

interface PaymentIntentRequest {
  service_id: string;
  staff_id?: string;
  scheduled_at: string; // ISO timestamp
  payment_type?: "full" | "deposit_only"; // default: full
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

    const body: PaymentIntentRequest = await req.json();
    const { service_id, staff_id, scheduled_at, payment_type = "full" } = body;

    if (!service_id || !scheduled_at) {
      return json({ error: "service_id and scheduled_at are required" }, 400);
    }

    // Fetch service with business info
    const { data: service, error: serviceError } = await supabase
      .from("services")
      .select(`
        id,
        name,
        price,
        duration_minutes,
        deposit_required,
        deposit_percentage,
        business_id,
        businesses!inner (
          id,
          name,
          stripe_account_id,
          onboarding_complete
        )
      `)
      .eq("id", service_id)
      .eq("is_active", true)
      .single();

    if (serviceError || !service) {
      return json({ error: "Service not found" }, 404);
    }

    const business = service.businesses as {
      id: string;
      name: string;
      stripe_account_id: string | null;
      onboarding_complete: boolean;
    };

    // Verify business is fully onboarded
    if (!business.onboarding_complete) {
      return json({ error: "This business is not yet accepting online payments" }, 400);
    }

    if (!business.stripe_account_id) {
      return json({ error: "Business has not set up payment processing" }, 400);
    }

    // Calculate amounts
    const servicePrice = service.price ?? 0;

    if (servicePrice <= 0) {
      return json({ error: "Service price is not configured" }, 400);
    }

    let chargeAmount: number;
    let depositAmount = 0;

    if (service.deposit_required) {
      depositAmount = Math.round(servicePrice * (service.deposit_percentage / 100) * 100) / 100;

      if (payment_type === "deposit_only") {
        chargeAmount = depositAmount;
      } else {
        chargeAmount = servicePrice;
      }
    } else {
      chargeAmount = servicePrice;
    }

    // Platform fee (3% of the charge amount)
    const platformFee = Math.round(chargeAmount * PLATFORM_FEE_PERCENT * 100); // in centavos

    // Amount in centavos for Stripe
    const amountCentavos = Math.round(chargeAmount * 100);

    // Get or create Stripe customer
    let stripeCustomerId: string | undefined;

    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", user.id)
      .single();

    if (profile?.stripe_customer_id) {
      stripeCustomerId = profile.stripe_customer_id;
    } else {
      // Create Stripe customer
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: {
          supabase_user_id: user.id,
        },
      });
      stripeCustomerId = customer.id;

      // Save customer ID
      await supabase
        .from("profiles")
        .update({ stripe_customer_id: customer.id })
        .eq("id", user.id);
    }

    // Create PaymentIntent with Connect destination charge
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCentavos,
      currency: "mxn",
      customer: stripeCustomerId,
      automatic_payment_methods: {
        enabled: true,
      },
      // Transfer to connected account, minus platform fee
      transfer_data: {
        destination: business.stripe_account_id,
      },
      application_fee_amount: platformFee,
      metadata: {
        service_id,
        service_name: service.name,
        business_id: business.id,
        business_name: business.name,
        staff_id: staff_id ?? "",
        scheduled_at,
        user_id: user.id,
        payment_type,
        deposit_amount: depositAmount.toString(),
        full_price: servicePrice.toString(),
      },
    });

    console.log(`[PAYMENT] Created PaymentIntent ${paymentIntent.id}`);
    console.log(`  Amount: $${chargeAmount} MXN (${amountCentavos} centavos)`);
    console.log(`  Platform fee: $${platformFee / 100} MXN`);
    console.log(`  To provider: $${(amountCentavos - platformFee) / 100} MXN`);

    return json({
      client_secret: paymentIntent.client_secret,
      payment_intent_id: paymentIntent.id,
      amount: chargeAmount,
      deposit_amount: depositAmount,
      platform_fee: platformFee / 100,
      provider_receives: (amountCentavos - platformFee) / 100,
      currency: "mxn",
      service: {
        id: service.id,
        name: service.name,
        full_price: servicePrice,
        duration_minutes: service.duration_minutes,
        deposit_required: service.deposit_required,
        deposit_percentage: service.deposit_percentage,
      },
      business: {
        id: business.id,
        name: business.name,
      },
    });

  } catch (err) {
    console.error("[PAYMENT] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
