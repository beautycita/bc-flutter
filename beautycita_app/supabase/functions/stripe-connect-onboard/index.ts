// stripe-connect-onboard edge function
// Manages Stripe Connect Express accounts for salon providers.
// Actions: create-account, get-onboard-link, get-account-status, dashboard-link

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_API = "https://api.stripe.com/v1";
const APP_URL = Deno.env.get("APP_URL") ?? "https://beautycita.com";

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

async function stripeGet(path: string) {
  const resp = await fetch(`${STRIPE_API}${path}`, {
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

  const supabase = createClient(supabaseUrl, serviceKey);

  try {
    const body = await req.json();
    const action = body.action ?? "create-account";
    const businessId = body.business_id;

    if (!businessId) {
      return json({ error: "business_id required" }, 400);
    }

    // Fetch business data
    const { data: business, error: bizError } = await supabase
      .from("businesses")
      .select("id, name, phone, whatsapp, address, stripe_account_id")
      .eq("id", businessId)
      .single();

    if (bizError || !business) {
      return json({ error: "Business not found" }, 404);
    }

    if (action === "create-account") {
      // Check if already has Stripe account
      if (business.stripe_account_id) {
        return json({
          account_id: business.stripe_account_id,
          already_exists: true,
        });
      }

      // Create Stripe Express account
      const params: Record<string, string> = {
        type: "express",
        country: "MX", // Mexico
        "capabilities[card_payments][requested]": "true",
        "capabilities[transfers][requested]": "true",
        "business_type": "individual",
        "metadata[business_id]": businessId,
        "metadata[platform]": "beautycita",
      };

      // Pre-fill business info if available
      if (business.name) {
        params["business_profile[name]"] = business.name;
      }
      if (business.phone || business.whatsapp) {
        // Note: Stripe requires phone in E.164 format without +
        const phone = (business.phone || business.whatsapp).replace(/[^\d]/g, "");
        if (phone.length >= 10) {
          params["individual[phone]"] = `+${phone.startsWith("52") ? "" : "52"}${phone}`;
        }
      }

      const account = await stripePost("/accounts", params);

      // Store Stripe account ID in business record
      await supabase
        .from("businesses")
        .update({
          stripe_account_id: account.id,
          stripe_onboarding_status: "pending",
        })
        .eq("id", businessId);

      return json({
        account_id: account.id,
        created: true,
      });
    }

    if (action === "get-onboard-link") {
      // Create or use existing account
      let accountId = business.stripe_account_id;

      if (!accountId) {
        // Create account first
        const params: Record<string, string> = {
          type: "express",
          country: "MX",
          "capabilities[card_payments][requested]": "true",
          "capabilities[transfers][requested]": "true",
          "business_type": "individual",
          "metadata[business_id]": businessId,
          "metadata[platform]": "beautycita",
        };

        if (business.name) {
          params["business_profile[name]"] = business.name;
        }

        const account = await stripePost("/accounts", params);
        accountId = account.id;

        await supabase
          .from("businesses")
          .update({
            stripe_account_id: accountId,
            stripe_onboarding_status: "pending",
          })
          .eq("id", businessId);
      }

      // Create Account Link for onboarding
      const accountLink = await stripePost("/account_links", {
        account: accountId,
        refresh_url: `${APP_URL}/stripe/refresh?business_id=${businessId}`,
        return_url: `${APP_URL}/stripe/complete?business_id=${businessId}`,
        type: "account_onboarding",
      });

      return json({
        account_id: accountId,
        onboarding_url: accountLink.url,
        expires_at: accountLink.expires_at,
      });
    }

    if (action === "get-account-status") {
      if (!business.stripe_account_id) {
        return json({
          status: "not_created",
          charges_enabled: false,
          payouts_enabled: false,
          details_submitted: false,
        });
      }

      // Fetch account from Stripe
      const account = await stripeGet(`/accounts/${business.stripe_account_id}`);

      // Determine onboarding status
      let status = "pending";
      if (account.charges_enabled && account.payouts_enabled) {
        status = "complete";
      } else if (account.details_submitted) {
        status = "pending_verification";
      }

      // Update status in database
      await supabase
        .from("businesses")
        .update({
          stripe_onboarding_status: status,
          stripe_charges_enabled: account.charges_enabled,
          stripe_payouts_enabled: account.payouts_enabled,
        })
        .eq("id", businessId);

      return json({
        status,
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        details_submitted: account.details_submitted,
        requirements: account.requirements?.currently_due ?? [],
      });
    }

    if (action === "dashboard-link") {
      if (!business.stripe_account_id) {
        return json({ error: "No Stripe account linked" }, 400);
      }

      // Create login link for Express dashboard
      const loginLink = await stripePost(
        `/accounts/${business.stripe_account_id}/login_links`
      );

      return json({
        dashboard_url: loginLink.url,
      });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("stripe-connect-onboard error:", err);
    return json({ error: String(err) }, 500);
  }
});
