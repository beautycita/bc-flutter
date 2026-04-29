// stripe-connect-onboard edge function
// Manages Stripe Connect Express accounts for salon providers.
// Actions: create-account, get-onboard-link, get-account-status, dashboard-link
//
// Platform rule: a salon without a valid RFC cannot transact. This function
// refuses to create a Stripe account unless businesses.rfc is populated
// (and the DB-level trigger has already validated its format).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_API = "https://api.stripe.com/v1";
// Hardcoded — refuse to honor any APP_URL env override so a misconfigured
// secret can't redirect Stripe return traffic to a different host.
const APP_URL = "https://beautycita.com";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// MCC 7230 = Barber and Beauty Shops. Fixed for all BeautyCita accounts.
const BEAUTYCITA_MCC = "7230";
const PRODUCT_DESCRIPTION = "Servicios de belleza y salón agendados vía BeautyCita";

function json(body: unknown, status = 200, req?: Request) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders(req),
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

// Rate limiting
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(key: string, limit: number, windowMs: number): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(key);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (entry.count >= limit) return false;
  entry.count++;
  return true;
}

function formatMxPhone(raw: string | null | undefined): string | undefined {
  if (!raw) return undefined;
  const digits = raw.replace(/[^\d]/g, "");
  if (digits.length < 10) return undefined;
  return `+${digits.startsWith("52") ? "" : "52"}${digits}`;
}

/**
 * Builds the complete Stripe account creation params from a business record.
 * Assumes business.rfc is present and format-valid (DB trigger enforces format).
 * RFC length determines entity type: 12 chars = PM (company), 13 chars = PF (individual).
 */
function buildStripeAccountParams(
  business: Record<string, unknown>,
  ownerEmail: string | null,
): Record<string, string> {
  const rfc = (business.rfc as string).toUpperCase();
  const isPM = rfc.length === 12;
  const businessType = isPM ? "company" : "individual";
  const phone = formatMxPhone(
    (business.phone as string) || (business.whatsapp as string),
  );

  const params: Record<string, string> = {
    type: "express",
    country: "MX",
    "capabilities[card_payments][requested]": "true",
    "capabilities[transfers][requested]": "true",
    business_type: businessType,
    "metadata[business_id]": business.id as string,
    "metadata[platform]": "beautycita",
    "metadata[rfc]": rfc,
    "metadata[tax_regime]": (business.tax_regime as string) ?? "",
  };

  // Business profile (applies to both PF and PM)
  if (business.name) {
    params["business_profile[name]"] = business.name as string;
  }
  params["business_profile[mcc]"] = BEAUTYCITA_MCC;
  params["business_profile[product_description]"] = PRODUCT_DESCRIPTION;
  if (business.website) {
    params["business_profile[url]"] = business.website as string;
  } else if (business.slug) {
    params["business_profile[url]"] = `${APP_URL}/${business.slug}`;
  }
  if (phone) {
    params["business_profile[support_phone]"] = phone;
  }
  if (business.email) {
    params["business_profile[support_email]"] = business.email as string;
  } else if (ownerEmail) {
    params["business_profile[support_email]"] = ownerEmail;
  }

  if (isPM) {
    // Persona Moral — company fields
    params["company[tax_id]"] = rfc;
    if (business.name) params["company[name]"] = business.name as string;
    if (phone) params["company[phone]"] = phone;
    if (business.address) {
      params["company[address][line1]"] = business.address as string;
      params["company[address][city]"] = (business.city as string) || "";
      params["company[address][state]"] = (business.state as string) || "";
      params["company[address][country]"] =
        (business.country as string) || "MX";
    }
  } else {
    // Persona Física — individual fields
    params["individual[id_number]"] = rfc;
    if (business.beneficiary_name) {
      const parts = (business.beneficiary_name as string).trim().split(/\s+/);
      if (parts.length >= 2) {
        params["individual[first_name]"] = parts[0];
        params["individual[last_name]"] = parts.slice(1).join(" ");
      } else if (parts.length === 1) {
        params["individual[first_name]"] = parts[0];
      }
    }
    if (phone) params["individual[phone]"] = phone;
    if (ownerEmail) params["individual[email]"] = ownerEmail;
    if (business.address) {
      params["individual[address][line1]"] = business.address as string;
      params["individual[address][city]"] = (business.city as string) || "";
      params["individual[address][state]"] = (business.state as string) || "";
      params["individual[address][country]"] =
        (business.country as string) || "MX";
    }
  }

  return params;
}

/**
 * Creates the Stripe Connect account and attaches CLABE (if banking is verified).
 * Persists stripe_account_id back to the businesses row.
 */
async function createStripeAccount(
  business: Record<string, unknown>,
  ownerEmail: string | null,
  // deno-lint-ignore no-explicit-any
  supabase: any,
): Promise<string> {
  const params = buildStripeAccountParams(business, ownerEmail);
  const account = await stripePost("/accounts", params);

  if (business.banking_complete && business.clabe) {
    try {
      await stripePost(`/accounts/${account.id}/external_accounts`, {
        "external_account[object]": "bank_account",
        "external_account[country]": "MX",
        "external_account[currency]": "mxn",
        "external_account[account_number]": business.clabe as string,
        "external_account[account_holder_name]":
          (business.beneficiary_name as string) ??
          (business.name as string) ??
          "",
      });
    } catch (e) {
      // Non-fatal: Stripe onboarding can still collect this info manually.
      console.warn("Failed to prefill CLABE:", e);
    }
  }

  await supabase
    .from("businesses")
    .update({
      stripe_account_id: account.id,
      stripe_onboarding_status: "pending",
    })
    .eq("id", business.id as string);

  return account.id;
}

Deno.serve(async (req: Request) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, req);
  }

  if (!STRIPE_SECRET_KEY) {
    return json({ error: "Stripe not configured" }, 500, req);
  }

  // ── Auth: require valid JWT ──
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  if (!token) {
    return json({ error: "Authorization required" }, 401, req);
  }

  const supabase = createClient(supabaseUrl, serviceKey);
  const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
  if (authErr || !user) {
    return json({ error: "Invalid token" }, 401, req);
  }

  // Rate limit: 5 requests per minute
  const rateLimitKey = user?.id || authHeader.slice(-16) || "anon";
  if (!checkRateLimit(rateLimitKey, 5, 60_000)) {
    return json({ error: "Rate limit exceeded" }, 429, req);
  }

  try {
    const body = await req.json();
    const action = body.action ?? "create-account";
    const businessId = body.business_id;

    if (!businessId) {
      return json({ error: "business_id required" }, 400, req);
    }
    if (typeof businessId !== "string" || !UUID_RE.test(businessId)) {
      return json({ error: "business_id must be a UUID" }, 400, req);
    }

    // Fetch business data + verify ownership
    const { data: business, error: bizError } = await supabase
      .from("businesses")
      .select(
        "id, name, phone, whatsapp, email, website, slug, address, city, state, country, rfc, tax_regime, stripe_account_id, owner_id, clabe, bank_name, beneficiary_name, banking_complete",
      )
      .eq("id", businessId)
      .single();

    if (bizError || !business) {
      return json({ error: "Business not found" }, 404, req);
    }

    // Verify caller owns this business
    if (business.owner_id !== user.id) {
      return json({ error: "Not authorized for this business" }, 403, req);
    }

    // Platform rule: salon cannot transact without RFC. Refuse Stripe
    // account creation / onboarding link when RFC is missing. Status checks
    // and dashboard links remain available so an already-onboarded salon
    // isn't locked out by a future RFC nullification.
    const needsRfc = action === "create-account" || action === "get-onboard-link";
    if (needsRfc && !business.rfc) {
      return json(
        {
          error: "RFC_REQUIRED",
          message:
            "Captura tu RFC antes de configurar Stripe. Es requisito legal para operar en BeautyCita.",
        },
        400,
        req,
      );
    }

    // Look up owner email from auth.users for Stripe autofill (individual[email]).
    // Only needed when we actually build account params.
    let ownerEmail: string | null = null;
    if (needsRfc) {
      const { data: ownerUser } = await supabase.auth.admin.getUserById(
        business.owner_id,
      );
      ownerEmail = ownerUser?.user?.email ?? null;
    }

    if (action === "create-account") {
      if (business.stripe_account_id) {
        return json({
          account_id: business.stripe_account_id,
          already_exists: true,
        }, 200, req);
      }

      const accountId = await createStripeAccount(business, ownerEmail, supabase);
      return json({ account_id: accountId, created: true }, 200, req);
    }

    if (action === "get-onboard-link") {
      let accountId = business.stripe_account_id;
      if (!accountId) {
        accountId = await createStripeAccount(business, ownerEmail, supabase);
      }

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
      }, 200, req);
    }

    if (action === "get-account-status") {
      if (!business.stripe_account_id) {
        return json({
          status: "not_created",
          charges_enabled: false,
          payouts_enabled: false,
          details_submitted: false,
        }, 200, req);
      }

      const account = await stripeGet(`/accounts/${business.stripe_account_id}`);

      let status = "pending";
      if (account.charges_enabled && account.payouts_enabled) {
        status = "complete";
      } else if (account.details_submitted) {
        status = "pending_verification";
      }

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
      }, 200, req);
    }

    if (action === "dashboard-link") {
      if (!business.stripe_account_id) {
        return json({ error: "No Stripe account linked" }, 400, req);
      }

      const loginLink = await stripePost(
        `/accounts/${business.stripe_account_id}/login_links`,
      );

      return json({
        dashboard_url: loginLink.url,
      }, 200, req);
    }

    return json({ error: `Unknown action: ${action}` }, 400, req);
  } catch (err) {
    console.error("stripe-connect-onboard error:", err);
    return json({ error: "Internal server error" }, 500, req);
  }
});
