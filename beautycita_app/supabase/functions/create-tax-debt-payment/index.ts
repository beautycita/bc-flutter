// =============================================================================
// create-tax-debt-payment — Salon pays open tax_obligation debt to BC
// =============================================================================
// Caller: authenticated salon owner.
// Creates a Stripe PaymentIntent on BC's PLATFORM account (no Connect transfer)
// for the sum of open tax_obligation debts. On payment_intent.succeeded, the
// stripe-webhook handler reduces those debts FIFO and the salon_debts trigger
// recomputes cash eligibility (immediate reactivation).
//
// payment_method: 'card' | 'oxxo'  (defaults to 'card')
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.21.0?target=deno";
import { corsHeaders as dynamicCors } from "../_shared/cors.ts";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

interface Req {
  business_id: string;
  amount?: number;
  payment_method?: "card" | "oxxo";
  /** "payment_sheet" returns client_secret for flutter_stripe mobile.
   *  "checkout"      returns a hosted Stripe Checkout URL for web. */
  flow?: "payment_sheet" | "checkout";
  /** For checkout flow: where to redirect after success/cancel. */
  success_url?: string;
  cancel_url?: string;
}

serve(async (req) => {
  const corsHeaders = dynamicCors(req);
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), {
      status: s,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    if (!token) return json({ error: "Unauthorized" }, 401);

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: { user }, error: authErr } = await userClient.auth.getUser();
    if (authErr || !user) return json({ error: "Unauthorized" }, 401);

    const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const body: Req = await req.json();
    if (!body.business_id) return json({ error: "business_id required" }, 400);
    const paymentMethod = body.payment_method === "oxxo" ? "oxxo" : "card";

    // Verify caller owns the business.
    const { data: biz } = await svc
      .from("businesses")
      .select("id, name, owner_id, is_test")
      .eq("id", body.business_id)
      .single();
    if (!biz) return json({ error: "business not found" }, 404);
    if (biz.owner_id !== user.id) return json({ error: "Forbidden" }, 403);
    if (biz.is_test) return json({ error: "Test business cannot pay debt" }, 400);

    // Sum open tax_obligation debts.
    const { data: debts } = await svc
      .from("salon_debts")
      .select("id, remaining_amount")
      .eq("business_id", body.business_id)
      .eq("debt_type", "tax_obligation")
      .gt("remaining_amount", 0);

    const openDebt = (debts ?? []).reduce(
      (acc: number, r: any) => acc + Number(r.remaining_amount ?? 0),
      0,
    );
    if (openDebt <= 0) {
      return json({ error: "No tax debt to pay", open_debt: 0 }, 400);
    }

    const amountMxn = body.amount && body.amount > 0
      ? Math.min(body.amount, openDebt)
      : openDebt;
    const amountCentavos = Math.round(amountMxn * 100);

    // Stripe customer for the salon owner — separate from booking customers
    // because the payer is the salon owner.
    const { data: profile } = await svc
      .from("profiles")
      .select("id, stripe_customer_id, full_name")
      .eq("id", user.id)
      .single();

    let stripeCustomerId = profile?.stripe_customer_id as string | null;
    if (stripeCustomerId) {
      try {
        const c = await stripe.customers.retrieve(stripeCustomerId);
        if ((c as any).deleted) stripeCustomerId = null;
      } catch (_) {
        stripeCustomerId = null;
      }
    }
    if (!stripeCustomerId) {
      const userEmail = user.email ?? undefined;
      const created = await stripe.customers.create({
        email: userEmail,
        name: profile?.full_name ?? biz.name,
        metadata: { user_id: user.id, role: "salon_owner" },
      });
      stripeCustomerId = created.id;
      await svc.from("profiles").update({ stripe_customer_id: stripeCustomerId }).eq("id", user.id);
    }

    const flow = body.flow ?? "payment_sheet";

    if (flow === "checkout") {
      // Hosted Stripe Checkout for web — returns a URL the user opens.
      const session = await stripe.checkout.sessions.create({
        customer: stripeCustomerId,
        mode: "payment",
        payment_method_types: paymentMethod === "oxxo" ? ["oxxo"] : ["card"],
        line_items: [
          {
            price_data: {
              currency: "mxn",
              product_data: { name: `BeautyCita — Pago de retencion fiscal (${biz.name})` },
              unit_amount: amountCentavos,
            },
            quantity: 1,
          },
        ],
        payment_intent_data: {
          metadata: {
            payment_type: "salon_tax_debt",
            business_id: body.business_id,
            user_id: user.id,
            amount_mxn: amountMxn.toString(),
          },
          description: `BeautyCita — Pago de retencion fiscal (${biz.name})`,
        },
        success_url: body.success_url ?? "https://beautycita.com/negocio?cash_pay=success",
        cancel_url: body.cancel_url ?? "https://beautycita.com/negocio?cash_pay=cancel",
      });
      return json({
        url: session.url,
        amount: amountMxn,
        open_debt: openDebt,
        currency: "mxn",
        payment_method: paymentMethod,
      });
    }

    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: stripeCustomerId },
      { apiVersion: "2023-10-16" },
    );

    const piConfig: Record<string, unknown> = paymentMethod === "oxxo"
      ? {
        payment_method_types: ["oxxo"],
        payment_method_options: { oxxo: { expires_after_days: 3 } },
      }
      : {
        automatic_payment_methods: { enabled: true },
      };

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCentavos,
      currency: "mxn",
      customer: stripeCustomerId,
      ...piConfig,
      metadata: {
        payment_type: "salon_tax_debt",
        business_id: body.business_id,
        user_id: user.id,
        amount_mxn: amountMxn.toString(),
      },
      description: `BeautyCita — Pago de retencion fiscal (${biz.name})`,
    });

    return json({
      client_secret: paymentIntent.client_secret,
      payment_intent_id: paymentIntent.id,
      customer_id: stripeCustomerId,
      ephemeral_key: ephemeralKey.secret,
      amount: amountMxn,
      open_debt: openDebt,
      currency: "mxn",
      payment_method: paymentMethod,
    });
  } catch (e) {
    console.error("[create-tax-debt-payment]", e);
    return json({ error: String(e).slice(0, 200) }, 500);
  }
});
