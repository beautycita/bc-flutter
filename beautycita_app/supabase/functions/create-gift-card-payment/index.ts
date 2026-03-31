// =============================================================================
// create-gift-card-payment — Stripe payment for gift card purchase
// =============================================================================
// Buyer pays via Stripe. BC takes 3%. Gift card created after payment confirms.
// The salon's Stripe Connect account receives the amount minus BC 3%.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.14.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": corsOrigin(req),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: "2023-10-16" });

    // Auth
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return json({ error: "Not authenticated" }, 401, corsHeaders);
    }

    const body = await req.json();
    const { business_id, amount, buyer_name, recipient_name, message, expires_at } = body;

    if (!business_id || !amount || amount <= 0) {
      return json({ error: "business_id and amount required" }, 400, corsHeaders);
    }

    // Get business Stripe account
    const { data: business } = await supabase
      .from("businesses")
      .select("id, name, stripe_account_id, stripe_charges_enabled, is_active")
      .eq("id", business_id)
      .single();

    if (!business || !business.is_active) {
      return json({ error: "Business not found or inactive" }, 404, corsHeaders);
    }

    if (!business.stripe_account_id ||
        business.stripe_account_id.startsWith("acct_test") ||
        !business.stripe_account_id.startsWith("acct_")) {
      return json({ error: "Este negocio no tiene pagos en linea configurados" }, 400, corsHeaders);
    }

    // Generate gift card code
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let code = "";
    for (let i = 0; i < 8; i++) {
      code += chars[Math.floor(Math.random() * chars.length)];
    }

    // Buyer pays face value + 3% BC fee
    // $100 gift card costs buyer $103. Salon gets $100. BC gets $3.
    const bcFee = Math.round(amount * 0.03 * 100); // in cents
    const totalCharge = Math.round(amount * 100) + bcFee; // face value + BC fee

    // Get or create Stripe customer
    let stripeCustomerId: string;
    const { data: existingCustomers } = await stripe.customers.search({
      query: `metadata['supabase_user_id']:'${user.id}'`,
    });

    if (existingCustomers && existingCustomers.length > 0) {
      stripeCustomerId = existingCustomers[0].id;
    } else {
      const customer = await stripe.customers.create({
        email: user.email ?? undefined,
        metadata: { supabase_user_id: user.id },
      });
      stripeCustomerId = customer.id;
    }

    // Create ephemeral key
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: stripeCustomerId },
      { apiVersion: "2023-10-16" },
    );

    // Create PaymentIntent — buyer pays face value + 3% fee
    const paymentIntent = await stripe.paymentIntents.create({
      amount: totalCharge,
      currency: "mxn",
      customer: stripeCustomerId,
      application_fee_amount: bcFee,
      transfer_data: {
        destination: business.stripe_account_id,
      },
      metadata: {
        type: "gift_card",
        business_id: business_id,
        user_id: user.id,
        gift_card_code: code,
        gift_card_amount: amount.toString(),
        buyer_name: buyer_name ?? "",
        recipient_name: recipient_name ?? "",
        message: message ?? "",
        expires_at: expires_at ?? "",
      },
    });

    console.log(`[GIFT-CARD] PaymentIntent ${paymentIntent.id} created for $${amount} gift card (code: ${code})`);

    return json({
      client_secret: paymentIntent.client_secret,
      payment_intent_id: paymentIntent.id,
      customer_id: stripeCustomerId,
      ephemeral_key: ephemeralKey.secret,
      gift_card_code: code,
      commission: amount * 0.03,
    }, 200, corsHeaders);

  } catch (err) {
    console.error("[GIFT-CARD] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500, corsHeaders);
  }
});

function json(body: unknown, status = 200, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}
