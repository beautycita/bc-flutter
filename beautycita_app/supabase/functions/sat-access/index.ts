// =============================================================================
// sat-access — Real-time data access API for SAT (CFF Art. 30-B)
// =============================================================================
// Provides authenticated read-only access to platform transaction data
// as required by Mexican tax law for digital intermediation platforms.
//
// Authentication: HMAC-SHA256 signed requests
//   X-SAT-Key: {api_key}           — identifies the caller
//   X-SAT-Timestamp: {unix_epoch}  — prevents replay (5-min window)
//   X-SAT-Signature: HMAC-SHA256(secret, timestamp + method + path + body)
//
// All requests are audit-logged to sat_access_log.
// Rate limited: 100 requests/hour.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SAT_API_KEY = Deno.env.get("SAT_API_KEY") ?? "";
const SAT_API_SECRET = Deno.env.get("SAT_API_SECRET") ?? "";

// Rate limit: sliding window per hour
const rateLimitWindow: number[] = [];
const RATE_LIMIT_MAX = 100;
const RATE_LIMIT_WINDOW_MS = 3_600_000; // 1 hour
const TIMESTAMP_TOLERANCE_MS = 300_000; // 5 minutes

serve(async (req) => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const url = new URL(req.url);
  const endpoint = url.pathname + url.search;
  const ipAddress = req.headers.get("x-forwarded-for")
    ?? req.headers.get("cf-connecting-ip")
    ?? "unknown";

  try {
    // ── HMAC Authentication ────────────────────────────────────────────
    const apiKey = req.headers.get("x-sat-key") ?? "";
    const timestamp = req.headers.get("x-sat-timestamp") ?? "";
    const signature = req.headers.get("x-sat-signature") ?? "";

    // Verify API key
    if (!SAT_API_KEY || !SAT_API_SECRET || apiKey !== SAT_API_KEY) {
      await logAccess(supabase, endpoint, null, 401, ipAddress, apiKey, "invalid_key");
      return json({ error: "Invalid or missing API key" }, 401);
    }

    // Verify timestamp (prevent replay attacks — 5 minute window)
    const ts = parseInt(timestamp);
    if (!ts || Math.abs(Date.now() - ts) > TIMESTAMP_TOLERANCE_MS) {
      await logAccess(supabase, endpoint, null, 401, ipAddress, apiKey, "expired_timestamp");
      return json({ error: "Timestamp expired or invalid. Must be within 5 minutes." }, 401);
    }

    // Verify HMAC-SHA256 signature
    // Signature = HMAC-SHA256(secret, timestamp + method + path)
    const path = url.pathname + url.search;
    const signaturePayload = `${timestamp}${req.method}${path}`;

    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(SAT_API_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const expectedSigBuffer = await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(signaturePayload),
    );
    const expectedSignature = Array.from(new Uint8Array(expectedSigBuffer))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    if (signature !== expectedSignature) {
      await logAccess(supabase, endpoint, null, 403, ipAddress, apiKey, "invalid_signature");
      return json({ error: "Invalid signature" }, 403);
    }

    // ── Rate Limiting ──────────────────────────────────────────────────
    const now = Date.now();
    while (rateLimitWindow.length > 0 && rateLimitWindow[0] < now - RATE_LIMIT_WINDOW_MS) {
      rateLimitWindow.shift();
    }
    if (rateLimitWindow.length >= RATE_LIMIT_MAX) {
      await logAccess(supabase, endpoint, null, 429, ipAddress, apiKey, "rate_limited");
      return json({ error: "Rate limit exceeded (100/hour)" }, 429);
    }
    rateLimitWindow.push(now);

    // ── Route ──────────────────────────────────────────────────────────
    const params = Object.fromEntries(url.searchParams);
    const routePath = url.pathname.replace(/^\/sat-access\/?/, "").replace(/^\//, "");

    let result: unknown;

    switch (routePath) {
      case "transactions":
        result = await handleTransactions(supabase, params);
        break;
      case "withholdings":
        result = await handleWithholdings(supabase, params);
        break;
      case "providers":
        result = await handleProviders(supabase, params);
        break;
      case "summary":
        result = await handleSummary(supabase, params);
        break;
      case "platform":
        result = await handlePlatformDeclaration(supabase, params);
        break;
      default:
        result = {
          api: "BeautyCita SAT Access API",
          version: "2.0",
          law: "CFF Art. 30-B",
          auth: "HMAC-SHA256",
          endpoints: [
            "GET /transactions?from=YYYY-MM-DD&to=YYYY-MM-DD&business_id=UUID&rfc=RFC",
            "GET /withholdings?period=YYYY-MM&business_id=UUID",
            "GET /providers?rfc=RFC&business_id=UUID",
            "GET /summary?period=YYYY-MM",
            "GET /platform?period=YYYY-MM",
          ],
        };
    }

    await logAccess(supabase, endpoint, params, 200, ipAddress, apiKey, "success");
    return json(result);

  } catch (err) {
    console.error("[SAT-ACCESS] Error:", (err as Error).message);
    await logAccess(supabase, endpoint, null, 500, ipAddress, "", "error").catch(() => {});
    return json({ error: "Internal server error" }, 500);
  }
});

// ---------------------------------------------------------------------------
// GET /transactions — Completed appointment transactions with tax data
// ---------------------------------------------------------------------------
async function handleTransactions(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  let query = supabase
    .from("appointments")
    .select(`
      id, business_id, starts_at, price, payment_method, payment_status,
      isr_withheld, iva_withheld, tax_base, provider_net,
      service_name, status, created_at,
      businesses!inner(name, rfc, tax_regime)
    `)
    .eq("status", "completed")
    .eq("payment_status", "paid")
    .order("starts_at", { ascending: false });

  if (params.from) query = query.gte("starts_at", params.from);
  if (params.to) query = query.lte("starts_at", `${params.to}T23:59:59Z`);
  if (params.business_id) query = query.eq("business_id", params.business_id);
  if (params.rfc) query = query.eq("businesses.rfc", params.rfc);

  const limit = Math.min(parseInt(params.limit ?? "100"), 1000);
  const offset = parseInt(params.offset ?? "0");
  query = query.range(offset, offset + limit - 1);

  const { data, error, count } = await query;
  if (error) throw new Error(`Query failed: ${error.message}`);

  return {
    data: (data ?? []).map((t: any) => ({
      transaction_id: t.id,
      business_id: t.business_id,
      business_name: t.businesses?.name,
      business_rfc: t.businesses?.rfc,
      tax_regime: t.businesses?.tax_regime,
      date: t.starts_at,
      service: t.service_name,
      gross_amount: t.price,
      payment_method: t.payment_method,
      isr_withheld: t.isr_withheld ?? 0,
      iva_withheld: t.iva_withheld ?? 0,
      tax_base: t.tax_base ?? 0,
      provider_net: t.provider_net ?? 0,
    })),
    pagination: { limit, offset, total: count },
  };
}

// ---------------------------------------------------------------------------
// GET /withholdings — Tax withholding ledger entries
// ---------------------------------------------------------------------------
async function handleWithholdings(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  if (!params.period) throw new Error("period required (YYYY-MM)");

  const [yearStr, monthStr] = params.period.split("-");
  const year = parseInt(yearStr);
  const month = parseInt(monthStr);

  let query = supabase
    .from("tax_withholdings")
    .select("*")
    .eq("period_year", year)
    .eq("period_month", month)
    .order("created_at", { ascending: false });

  if (params.business_id) query = query.eq("business_id", params.business_id);

  const limit = Math.min(parseInt(params.limit ?? "100"), 1000);
  const offset = parseInt(params.offset ?? "0");
  query = query.range(offset, offset + limit - 1);

  const { data, error } = await query;
  if (error) throw new Error(`Query failed: ${error.message}`);

  return { period: { year, month }, data: data ?? [] };
}

// ---------------------------------------------------------------------------
// GET /providers — Business/provider tax lookup
// ---------------------------------------------------------------------------
async function handleProviders(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  let query = supabase
    .from("businesses")
    .select("id, name, rfc, tax_regime, tax_residency, city, state, is_active, created_at");

  if (params.rfc) query = query.eq("rfc", params.rfc);
  if (params.business_id) query = query.eq("id", params.business_id);

  const { data, error } = await query;
  if (error) throw new Error(`Query failed: ${error.message}`);

  // Only return businesses with RFC (SAT doesn't need unregistered ones)
  return { data: (data ?? []).filter((b: any) => b.rfc) };
}

// ---------------------------------------------------------------------------
// GET /summary — Per-business monthly summary report
// ---------------------------------------------------------------------------
async function handleSummary(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  if (!params.period) throw new Error("period required (YYYY-MM)");

  const [yearStr, monthStr] = params.period.split("-");
  const year = parseInt(yearStr);
  const month = parseInt(monthStr);

  let query = supabase
    .from("sat_monthly_reports")
    .select("*")
    .eq("period_year", year)
    .eq("period_month", month);

  if (params.business_id) query = query.eq("business_id", params.business_id);

  const { data, error } = await query;
  if (error) throw new Error(`Query failed: ${error.message}`);

  return {
    period: { year, month },
    reports: (data ?? []).map((r: any) => ({
      business_id: r.business_id,
      total_transactions: r.total_transactions,
      total_gross: r.total_gross,
      isr_withheld: r.total_isr_withheld,
      iva_withheld: r.total_iva_withheld,
      platform_fees: r.total_platform_fees,
      status: r.status,
      generated_at: r.generated_at,
    })),
  };
}

// ---------------------------------------------------------------------------
// GET /platform — Platform-level aggregate declaration (BC total)
// ---------------------------------------------------------------------------
async function handlePlatformDeclaration(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  if (!params.period) throw new Error("period required (YYYY-MM)");

  const [yearStr, monthStr] = params.period.split("-");
  const year = parseInt(yearStr);
  const month = parseInt(monthStr);

  const { data, error } = await supabase
    .from("platform_sat_declarations")
    .select("*")
    .eq("period_year", year)
    .eq("period_month", month)
    .maybeSingle();

  if (error) throw new Error(`Query failed: ${error.message}`);

  if (!data) {
    return { period: { year, month }, status: "not_generated" };
  }

  return {
    period: { year, month },
    platform: {
      name: "BeautyCita S.A. de C.V.",
      total_businesses: data.total_businesses,
      total_transactions: data.total_transactions,
      total_revenue: data.total_revenue_all,
      iva_collected: data.total_iva_collected,
      isr_collected: data.total_isr_collected,
      commissions_earned: data.total_commissions_earned,
      paid_to_sat: data.total_paid_to_sat,
      bank_interest: data.bank_interest_earned,
      status: data.status,
      submitted_at: data.submitted_at,
    },
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
async function logAccess(
  supabase: ReturnType<typeof createClient>,
  endpoint: string,
  queryParams: Record<string, string> | null,
  responseStatus: number,
  ipAddress: string,
  apiKey: string,
  result: string,
) {
  const keyHash = apiKey
    ? Array.from(
        new Uint8Array(
          await crypto.subtle.digest("SHA-256", new TextEncoder().encode(apiKey))
        )
      ).map((b) => b.toString(16).padStart(2, "0")).join("")
    : null;

  await supabase.from("sat_access_log").insert({
    endpoint,
    query_params: queryParams,
    response_status: responseStatus,
    ip_address: ipAddress,
    api_key_hash: keyHash,
    result,
  }).catch((err) => {
    console.error("[SAT-ACCESS] Failed to log:", err);
  });
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      "Content-Type": "application/json",
      "X-Content-Type-Options": "nosniff",
      "Cache-Control": "no-store",
    },
  });
}
