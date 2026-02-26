// stripe-payment-methods edge function
// Manages Stripe payment methods via Setup Intents.
// Actions: setup-intent, list, detach

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_API = "https://api.stripe.com/v1";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, content-type, x-client-info, apikey",
    },
  });
}

async function stripePost(path: string, params: Record<string, string> = {}) {
  const resp = await fetch(`${STRIPE_API}${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams(params),
  });
  const data = await resp.json();
  if (!resp.ok) {
    throw new Error(data.error?.message ?? `Stripe error ${resp.status}`);
  }
  return data;
}

async function stripeGet(path: string, params: Record<string, string> = {}) {
  const qs = new URLSearchParams(params).toString();
  const url = qs ? `${STRIPE_API}${path}?${qs}` : `${STRIPE_API}${path}`;
  const resp = await fetch(url, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
    },
  });
  const data = await resp.json();
  if (!resp.ok) {
    throw new Error(data.error?.message ?? `Stripe error ${resp.status}`);
  }
  return data;
}

async function stripeDelete(path: string) {
  const resp = await fetch(`${STRIPE_API}${path}`, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
    },
  });
  const data = await resp.json();
  if (!resp.ok) {
    throw new Error(data.error?.message ?? `Stripe error ${resp.status}`);
  }
  return data;
}

// Get or create Stripe customer for a user
async function ensureCustomer(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  userEmail?: string,
): Promise<string> {
  // Check if user already has a Stripe customer
  const { data: profile } = await supabase
    .from("profiles")
    .select("stripe_customer_id, username")
    .eq("id", userId)
    .single();

  if (profile?.stripe_customer_id) {
    return profile.stripe_customer_id;
  }

  // Create new Stripe customer
  const params: Record<string, string> = {
    "metadata[supabase_user_id]": userId,
  };
  if (userEmail) params.email = userEmail;
  if (profile?.username) params.name = profile.username;

  const customer = await stripePost("/customers", params);

  // Store customer ID
  await supabase
    .from("profiles")
    .update({ stripe_customer_id: customer.id })
    .eq("id", userId);

  return customer.id;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers":
          "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  if (!STRIPE_SECRET_KEY) {
    return json({ error: "Stripe not configured" }, 500);
  }

  // Authenticate
  const authHeader = req.headers.get("authorization") ?? "";
  const supabase = createClient(supabaseUrl, serviceKey);
  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const body = await req.json();
    const action = body.action ?? "setup-intent";

    if (action === "setup-intent") {
      // Create/get customer → ephemeral key → setup intent
      const customerId = await ensureCustomer(supabase, user.id, user.email ?? undefined);

      // Create ephemeral key (requires Stripe-Version header)
      const ekResp = await fetch(`${STRIPE_API}/ephemeral_keys`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
          "Content-Type": "application/x-www-form-urlencoded",
          "Stripe-Version": "2024-12-18.acacia",
        },
        body: new URLSearchParams({ customer: customerId }),
      });
      const ekData = await ekResp.json();
      if (!ekResp.ok) {
        throw new Error(ekData.error?.message ?? "Failed to create ephemeral key");
      }

      // Create setup intent
      const setupIntent = await stripePost("/setup_intents", {
        customer: customerId,
        "payment_method_types[]": "card",
      });

      return json({
        setupIntent: setupIntent.client_secret,
        ephemeralKey: ekData.secret,
        customer: customerId,
      });
    }

    if (action === "list") {
      const customerId = await ensureCustomer(supabase, user.id, user.email ?? undefined);

      const methods = await stripeGet("/payment_methods", {
        customer: customerId,
        type: "card",
      });

      const cards = (methods.data ?? []).map((pm: any) => ({
        id: pm.id,
        brand: pm.card?.brand ?? "unknown",
        last4: pm.card?.last4 ?? "****",
        expMonth: pm.card?.exp_month,
        expYear: pm.card?.exp_year,
      }));

      return json({ cards });
    }

    if (action === "detach") {
      const paymentMethodId = body.payment_method_id;
      if (!paymentMethodId) {
        return json({ error: "payment_method_id required" }, 400);
      }

      await stripePost(`/payment_methods/${paymentMethodId}/detach`);
      return json({ detached: true });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("stripe-payment-methods error:", err);
    return json({ error: String(err) }, 500);
  }
});
