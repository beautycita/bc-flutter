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
import { calculateWithholding, type TaxWithholding } from "../_shared/tax_mx.ts";
import { requireFeature } from "../_shared/check-toggle.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://beautycita.com",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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
  booking_id?: string; // Pre-created booking ID for webhook reconciliation
  staff_id?: string;
  scheduled_at: string; // ISO timestamp
  payment_type?: "full" | "deposit_only"; // default: full
  payment_method?: "card" | "oxxo"; // default: card (bitcoin handled separately)
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Server-side toggle enforcement
  const blocked = await requireFeature("enable_stripe_payments");
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

    // Feature toggle check
    const { data: toggleData } = await supabase
      .from("app_config")
      .select("value")
      .eq("key", "enable_stripe_payments")
      .single();
    if (toggleData?.value !== "true") {
      return json({ error: "This feature is currently disabled" }, 403);
    }

    const body: PaymentIntentRequest = await req.json();
    const { service_id, booking_id, staff_id, scheduled_at, payment_type = "full", payment_method = "card" } = body;

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
          onboarding_complete,
          rfc,
          tax_residency
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
      rfc: string | null;
      tax_residency: string;
    };

    // Verify business is fully onboarded
    if (!business.onboarding_complete) {
      return json({ error: "This business is not yet accepting online payments" }, 400);
    }

    if (!business.stripe_account_id) {
      return json({ error: "Este negocio no tiene pagos en linea configurados" }, 400);
    }

    // Reject fake/test Stripe account IDs before hitting the Stripe API
    if (
      business.stripe_account_id.startsWith("acct_test") ||
      !business.stripe_account_id.startsWith("acct_")
    ) {
      return json({ error: "Este negocio no tiene pagos en linea configurados" }, 400);
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

    // Amount in centavos for Stripe
    const amountCentavos = Math.round(chargeAmount * 100);

    // Check if tax withholding is enabled
    const { data: taxFlag } = await supabase
      .from("app_config")
      .select("value")
      .eq("key", "tax_withholding_enabled")
      .single();
    const taxWithholdingEnabled = taxFlag?.value === "true";

    // Calculate withholdings (or just platform fee)
    let applicationFeeAmount: number; // in centavos
    let taxInfo: TaxWithholding | null = null;

    if (taxWithholdingEnabled) {
      taxInfo = calculateWithholding(
        chargeAmount,
        PLATFORM_FEE_PERCENT,
        business.rfc,
        business.tax_residency ?? "MX",
      );
      // application_fee_amount absorbs platform fee + ISR + IVA
      applicationFeeAmount = Math.round(
        (taxInfo.platformFee + taxInfo.isrWithheld + taxInfo.ivaWithheld) * 100
      );
    } else {
      const platformFee = Math.round(chargeAmount * PLATFORM_FEE_PERCENT * 100);
      applicationFeeAmount = platformFee;
    }

    // Check for outstanding salon debt — collect up to 50% of service fee
    let debtCollected = 0;
    try {
      const { data: debtData } = await supabase
        .from("salon_debts")
        .select("remaining_amount")
        .eq("business_id", business.id)
        .gt("remaining_amount", 0);

      const totalDebt = (debtData ?? []).reduce(
        (sum: number, d: { remaining_amount: number }) => sum + Number(d.remaining_amount), 0
      );

      if (totalDebt > 0) {
        const maxDeduction = Math.min(chargeAmount * 0.50, totalDebt);
        const netAfterFees = chargeAmount - (applicationFeeAmount / 100);
        debtCollected = Math.min(maxDeduction, netAfterFees);
        debtCollected = Math.round(debtCollected * 100) / 100;

        if (debtCollected > 0) {
          applicationFeeAmount += Math.round(debtCollected * 100);
          console.log(`[PAYMENT] Collecting $${debtCollected} debt from ${business.id} (total debt: $${totalDebt})`);
        }
      }
    } catch (debtErr) {
      console.error("[PAYMENT] Debt check error (non-fatal):", debtErr);
    }

    // Get or create Stripe customer
    let stripeCustomerId: string | undefined;

    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", user.id)
      .single();

    if (profile?.stripe_customer_id) {
      // Verify customer exists in current Stripe mode (handles test→live key switch)
      try {
        await stripe.customers.retrieve(profile.stripe_customer_id);
        stripeCustomerId = profile.stripe_customer_id;
      } catch {
        console.error(`Stale Stripe customer ${profile.stripe_customer_id}, recreating`);
        stripeCustomerId = undefined;
      }
    }

    if (!stripeCustomerId) {
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

    // Create ephemeral key for customer (needed by PaymentSheet)
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: stripeCustomerId! },
      { apiVersion: "2023-10-16" },
    );

    // Payment method config: OXXO-only or automatic
    const paymentMethodConfig = payment_method === "oxxo"
      ? { payment_method_types: ["oxxo"] as string[] }
      : { automatic_payment_methods: { enabled: true } };

    // Build metadata — include tax info when withholding is enabled
    const metadata: Record<string, string> = {
      service_id,
      booking_id: booking_id ?? "",
      service_name: service.name,
      business_id: business.id,
      business_name: business.name,
      staff_id: staff_id ?? "",
      scheduled_at,
      user_id: user.id,
      payment_type,
      payment_method,
      deposit_amount: depositAmount.toString(),
      full_price: servicePrice.toString(),
    };

    if (debtCollected > 0) {
      metadata.debt_collected = debtCollected.toString();
    }

    if (taxInfo) {
      metadata.tax_withholding = "true";
      metadata.tax_jurisdiction = taxInfo.jurisdiction;
      metadata.tax_base = taxInfo.taxBase.toString();
      metadata.iva_portion = taxInfo.ivaPortion.toString();
      metadata.platform_fee_amount = taxInfo.platformFee.toString();
      metadata.isr_rate = taxInfo.isrRate.toString();
      metadata.iva_rate = taxInfo.ivaRate.toString();
      metadata.isr_withheld = taxInfo.isrWithheld.toString();
      metadata.iva_withheld = taxInfo.ivaWithheld.toString();
      metadata.provider_net = taxInfo.providerNet.toString();
      metadata.provider_rfc = business.rfc ?? "";
      metadata.provider_tax_residency = business.tax_residency ?? "MX";
    }

    // Create PaymentIntent with Connect destination charge
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCentavos,
      currency: "mxn",
      customer: stripeCustomerId,
      ...paymentMethodConfig,
      // Transfer to connected account, minus application fee
      transfer_data: {
        destination: business.stripe_account_id,
      },
      application_fee_amount: applicationFeeAmount,
      metadata,
    });

    const platformFeeMXN = taxInfo ? taxInfo.platformFee : applicationFeeAmount / 100;
    const providerReceives = taxInfo ? taxInfo.providerNet : (amountCentavos - applicationFeeAmount) / 100;

    console.log(`[PAYMENT] Created PaymentIntent ${paymentIntent.id}`);
    console.log(`  Amount: $${chargeAmount} MXN (${amountCentavos} centavos)`);
    console.log(`  Platform fee: $${platformFeeMXN} MXN`);
    if (taxInfo) {
      console.log(`  ISR withheld: $${taxInfo.isrWithheld} MXN (${taxInfo.isrRate * 100}%)`);
      console.log(`  IVA withheld: $${taxInfo.ivaWithheld} MXN (${taxInfo.ivaRate * 100}%)`);
    }
    console.log(`  Provider receives: $${providerReceives} MXN`);

    return json({
      client_secret: paymentIntent.client_secret,
      payment_intent_id: paymentIntent.id,
      customer_id: stripeCustomerId,
      ephemeral_key: ephemeralKey.secret,
      amount: chargeAmount,
      deposit_amount: depositAmount,
      platform_fee: platformFeeMXN,
      provider_receives: providerReceives,
      currency: "mxn",
      payment_method,
      ...(taxInfo ? {
        tax_withholding: {
          tax_base: taxInfo.taxBase,
          iva_portion: taxInfo.ivaPortion,
          isr_rate: taxInfo.isrRate,
          iva_rate: taxInfo.ivaRate,
          isr_withheld: taxInfo.isrWithheld,
          iva_withheld: taxInfo.ivaWithheld,
        },
      } : {}),
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
    console.error("[PAYMENT] Error:", err);
    return json({ error: "An internal error occurred" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
