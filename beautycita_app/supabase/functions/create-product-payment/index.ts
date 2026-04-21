// =============================================================================
// create-product-payment — Create Stripe PaymentIntent for product purchase
// =============================================================================
// Creates a PaymentIntent for purchasing a marketplace product, with:
// - Flat 10% commission to BeautyCita
// - Split payment to seller's Stripe Connect account
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { requireFeature } from "../_shared/check-toggle.ts";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";


const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// BeautyCita marketplace commission: 10%
const MARKETPLACE_COMMISSION_PERCENT = 0.10;

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

interface ShippingAddress {
  name: string;
  street: string;
  city: string;
  state: string;
  zip: string;
  phone: string;
}

interface ProductPaymentRequest {
  product_id: string;
  quantity: number;
  shipping_address: ShippingAddress;
}

serve(async (req) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;

  try {
    // Feature toggle check
    const blocked = await requireFeature("enable_pos");
    if (blocked) return blocked;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Auth check
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401, req);
    }

    const body: ProductPaymentRequest = await req.json();
    const { product_id, quantity = 1, shipping_address } = body;

    if (!product_id) {
      return json({ error: "product_id is required" }, 400, req);
    }

    if (!shipping_address || !shipping_address.name || !shipping_address.street) {
      return json({ error: "shipping_address with name and street is required" }, 400, req);
    }

    if (quantity < 1 || !Number.isInteger(quantity)) {
      return json({ error: "quantity must be a positive integer" }, 400, req);
    }

    // Fetch product with business info
    const { data: product, error: productError } = await supabase
      .from("products")
      .select(`
        *,
        businesses!inner (
          id,
          name,
          stripe_account_id,
          onboarding_complete,
          is_active,
          banking_complete,
          rfc
        )
      `)
      .eq("id", product_id)
      .single();

    if (productError || !product) {
      return json({ error: "Product not found" }, 404, req);
    }

    // Verify product is in stock (in_stock is a boolean column)
    if (!product.in_stock) {
      return json({ error: "Product is not available" }, 400, req);
    }

    const business = product.businesses as {
      id: string;
      name: string;
      stripe_account_id: string | null;
      onboarding_complete: boolean;
      is_active: boolean;
      banking_complete: boolean;
      rfc: string | null;
    };

    // Verify business is active
    if (!business.is_active) {
      return json({ error: "This business is no longer active" }, 400, req);
    }

    // Verify business is fully onboarded
    if (!business.onboarding_complete) {
      return json({ error: "This business is not yet accepting online payments" }, 400, req);
    }

    // Banking gate parity with create-payment-intent
    if (!business.banking_complete) {
      return json({ error: "Este negocio aun no ha completado su verificacion bancaria" }, 400, req);
    }

    // Platform rule: salon cannot transact without RFC. Same gate as
    // create-payment-intent (build 60074). Closes the gap where products
    // could be purchased from no-RFC salons while bookings could not.
    if (!business.rfc) {
      console.warn(`[PRODUCT-PAYMENT] RFC missing on business ${business.id} — refusing charge`);
      return json({
        error: "Este negocio no tiene RFC vigente y no puede recibir pagos en linea.",
        code: "RFC_REQUIRED",
      }, 400, req);
    }

    if (!business.stripe_account_id) {
      return json({ error: "Este negocio no tiene pagos en linea configurados" }, 400, req);
    }

    // Reject fake/test Stripe account IDs before hitting the Stripe API
    if (
      business.stripe_account_id.startsWith("acct_test") ||
      !business.stripe_account_id.startsWith("acct_")
    ) {
      return json({ error: "Este negocio no tiene pagos en linea configurados" }, 400, req);
    }

    // Block new purchases if the business has an active payout hold.
    const { data: holdCheck, error: holdErr } = await supabase.rpc("has_active_payout_hold", {
      p_business_id: business.id,
    });
    if (holdErr) {
      console.error(`[PRODUCT-PAYMENT] has_active_payout_hold error:`, holdErr);
      return json({ error: "No se pudo verificar el estado del negocio. Intenta de nuevo." }, 500, req);
    }
    if (holdCheck === true) {
      console.warn(`[PRODUCT-PAYMENT] Purchase rejected — business ${business.id} has active payout hold`);
      return json({
        error: "Este negocio temporalmente no puede vender productos. Intenta de nuevo mas tarde.",
        code: "PAYOUT_HOLD_ACTIVE",
      }, 409, req);
    }

    // Calculate amounts
    const productPrice = product.price ?? 0;

    if (productPrice <= 0) {
      return json({ error: "Product price is not configured" }, 400, req);
    }

    const totalAmount = productPrice * quantity;
    const commission = totalAmount * MARKETPLACE_COMMISSION_PERCENT;
    const sellerReceives = totalAmount - commission;
    const platformFee = Math.round(commission * 100); // in centavos
    const amountCentavos = Math.round(totalAmount * 100);

    // Get or create Stripe customer
    let stripeCustomerId: string | undefined;

    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", user.id)
      .single();

    if (profile?.stripe_customer_id) {
      // Verify customer exists in current Stripe mode (handles test->live key switch)
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

    // Create PaymentIntent with Connect destination charge
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCentavos,
      currency: "mxn",
      customer: stripeCustomerId,
      automatic_payment_methods: { enabled: true },
      // Transfer to connected account, minus platform fee
      transfer_data: {
        destination: business.stripe_account_id,
      },
      application_fee_amount: platformFee,
      metadata: {
        product_id,
        product_name: product.name,
        business_id: business.id,
        business_name: business.name,
        user_id: user.id,
        quantity: quantity.toString(),
        shipping_address: JSON.stringify(shipping_address),
        payment_type: "product",
      },
    });

    console.log(`[PRODUCT-PAYMENT] Created PaymentIntent ${paymentIntent.id}`);
    console.log(`  Amount: $${totalAmount} MXN (${amountCentavos} centavos)`);
    console.log(`  Commission (10%): $${commission} MXN`);
    console.log(`  Seller receives: $${sellerReceives} MXN`);

    return json({
      client_secret: paymentIntent.client_secret,
      payment_intent_id: paymentIntent.id,
      customer_id: stripeCustomerId,
      ephemeral_key: ephemeralKey.secret,
      amount: totalAmount,
      commission: Math.round(commission * 100) / 100,
      seller_receives: Math.round(sellerReceives * 100) / 100,
      currency: "mxn",
      product: {
        id: product.id,
        name: product.name,
        price: productPrice,
      },
      business: {
        id: business.id,
        name: business.name,
      },
    });

  } catch (err) {
    console.error("[PRODUCT-PAYMENT] Error:", err);
    return json({ error: "An internal error occurred" }, 500, req);
  }
});

function json(body: unknown, status = 200, req?: Request) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req!), "Content-Type": "application/json" },
  });
}
