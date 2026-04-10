// =============================================================================
// sat-access — Real-time data access API for SAT (CFF Art. 30-B)
// =============================================================================
// CRITICAL INFRASTRUCTURE — This endpoint must NEVER return an error to SAT.
// If anything fails internally, return a polite "high volume" retry message.
// All failures trigger immediate WA + logging alerts to BC.
//
// Authentication: HMAC-SHA256 signed requests
//   X-SAT-Key: {api_key}           — identifies the caller
//   X-SAT-Timestamp: {unix_epoch}  — prevents replay (5-min window)
//   X-SAT-Signature: HMAC-SHA256(secret, timestamp + method + path)
//
// All requests are audit-logged to sat_access_log.
// Rate limited: 100 requests/hour.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SAT_API_KEY = Deno.env.get("SAT_API_KEY") ?? "";
const SAT_API_SECRET = Deno.env.get("SAT_API_SECRET") ?? "";
const WA_API_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const WA_API_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const BC_PHONE = "+5213322091741";

// Rate limit: sliding window per hour
const rateLimitWindow: number[] = [];
const RATE_LIMIT_MAX = 100;
const RATE_LIMIT_WINDOW_MS = 3_600_000;
const TIMESTAMP_TOLERANCE_MS = 300_000;

// ── SAT-safe error message — NEVER expose internals to SAT ──────────────────
const SAT_RETRY_MESSAGE = {
  status: "temporarily_unavailable",
  message: "El servidor esta experimentando un volumen inusualmente alto. Por favor espere un momento e intente de nuevo.",
  retry_after_seconds: 30,
};

// ── Alert BC immediately on any SAT failure ─────────────────────────────────
async function alertBC(reason: string, details: string) {
  const msg = `🚨 *SAT API ALERT* 🚨\n\n*Reason:* ${reason}\n*Details:* ${details}\n*Time:* ${new Date().toISOString()}\n\n_This is a critical alert. The SAT API experienced a failure. Investigate immediately._`;

  // Try WA alert
  try {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 5000);
    await fetch(`${WA_API_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${WA_API_TOKEN}`,
      },
      body: JSON.stringify({ phone: BC_PHONE, message: msg }),
      signal: ac.signal,
    });
    clearTimeout(t);
  } catch (e) {
    console.error("[SAT-ALERT] WA alert failed:", e);
  }

  // Always log to console (picked up by docker logs)
  console.error(`[SAT-ALERT] ${reason}: ${details}`);
}

// ── DB query with retry (2 attempts, 1s delay) ─────────────────────────────
async function queryWithRetry<T>(
  fn: () => Promise<{ data: T | null; error: any }>,
  label: string,
): Promise<T> {
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const { data, error } = await fn();
      if (error) {
        if (attempt < 2) {
          console.warn(`[SAT] ${label} attempt ${attempt} failed: ${error.message}, retrying...`);
          await new Promise((r) => setTimeout(r, 1000));
          continue;
        }
        throw new Error(`${label}: ${error.message}`);
      }
      return data as T;
    } catch (e) {
      if (attempt < 2) {
        console.warn(`[SAT] ${label} attempt ${attempt} exception, retrying...`);
        await new Promise((r) => setTimeout(r, 1000));
        continue;
      }
      throw e;
    }
  }
  throw new Error(`${label}: all retries exhausted`);
}

Deno.serve(async (req) => {
  // ── ABSOLUTE SAFETY NET — nothing escapes as an ugly error to SAT ───────
  let supabase: ReturnType<typeof createClient>;
  try {
    supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  } catch (e) {
    await alertBC("Supabase client init failed", String(e));
    return json(SAT_RETRY_MESSAGE, 503);
  }

  const url = new URL(req.url);
  const endpoint = url.pathname + url.search;
  const ipAddress = req.headers.get("x-forwarded-for")
    ?? req.headers.get("cf-connecting-ip")
    ?? "unknown";

  try {
    // ── CORS preflight ────────────────────────────────────────────────
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204 });
    }

    // ── HMAC Authentication ───────────────────────────────────────────
    const apiKey = req.headers.get("x-sat-key") ?? "";
    const timestamp = req.headers.get("x-sat-timestamp") ?? "";
    const signature = req.headers.get("x-sat-signature") ?? "";

    if (!SAT_API_KEY || !SAT_API_SECRET || apiKey !== SAT_API_KEY) {
      logAccess(supabase, endpoint, null, 401, ipAddress, apiKey, "invalid_key").catch(() => {});
      return json({ error: "Invalid or missing API key" }, 401);
    }

    const ts = parseInt(timestamp);
    if (!ts || Math.abs(Date.now() - ts) > TIMESTAMP_TOLERANCE_MS) {
      logAccess(supabase, endpoint, null, 401, ipAddress, apiKey, "expired_timestamp").catch(() => {});
      return json({ error: "Timestamp expired or invalid. Must be within 5 minutes." }, 401);
    }

    // Use X-SAT-Original-Path (set by nginx) so callers sign the public URL
    const originalPath = req.headers.get("x-sat-original-path");
    const internalPath = url.pathname + url.search;
    const path = originalPath || internalPath;
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
      logAccess(supabase, endpoint, null, 403, ipAddress, apiKey, "invalid_signature").catch(() => {});
      return json({ error: "Invalid signature" }, 403);
    }

    // ── Rate Limiting ─────────────────────────────────────────────────
    const now = Date.now();
    while (rateLimitWindow.length > 0 && rateLimitWindow[0] < now - RATE_LIMIT_WINDOW_MS) {
      rateLimitWindow.shift();
    }
    if (rateLimitWindow.length >= RATE_LIMIT_MAX) {
      logAccess(supabase, endpoint, null, 429, ipAddress, apiKey, "rate_limited").catch(() => {});
      return json(SAT_RETRY_MESSAGE, 429);
    }
    rateLimitWindow.push(now);

    // ── Route ─────────────────────────────────────────────────────────
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

    logAccess(supabase, endpoint, params, 200, ipAddress, apiKey, "success").catch(() => {});
    return json(result);

  } catch (err) {
    // ── CRITICAL: SAT never sees an error — only the retry message ───
    const errMsg = (err as Error).message ?? String(err);
    console.error("[SAT-ACCESS] CRITICAL FAILURE:", errMsg);

    // Alert BC immediately via every channel
    await alertBC("Query/processing failure", errMsg);

    // Log the failure
    logAccess(supabase, endpoint, null, 503, ipAddress, "", `critical_error: ${errMsg}`).catch(() => {});

    // Return friendly retry message — NOT an error
    return json(SAT_RETRY_MESSAGE, 503);
  }
});

// ---------------------------------------------------------------------------
// GET /transactions — Completed appointment transactions with tax data
// ---------------------------------------------------------------------------
async function handleTransactions(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  const limit = Math.min(parseInt(params.limit ?? "100"), 1000);
  const offset = parseInt(params.offset ?? "0");

  const data = await queryWithRetry(() => {
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

    return query.range(offset, offset + limit - 1);
  }, "transactions");

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
    pagination: { limit, offset },
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
  const limit = Math.min(parseInt(params.limit ?? "100"), 1000);
  const offset = parseInt(params.offset ?? "0");

  const data = await queryWithRetry(() => {
    let query = supabase
      .from("tax_withholdings")
      .select("*")
      .eq("period_year", year)
      .eq("period_month", month)
      .order("created_at", { ascending: false });

    if (params.business_id) query = query.eq("business_id", params.business_id);
    return query.range(offset, offset + limit - 1);
  }, "withholdings");

  return { period: { year, month }, data: data ?? [] };
}

// ---------------------------------------------------------------------------
// GET /providers — Business/provider tax lookup
// ---------------------------------------------------------------------------
async function handleProviders(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  const data = await queryWithRetry(() => {
    let query = supabase
      .from("businesses")
      .select("id, name, rfc, tax_regime, tax_residency, city, state, is_active, created_at");

    if (params.rfc) query = query.eq("rfc", params.rfc);
    if (params.business_id) query = query.eq("id", params.business_id);
    return query;
  }, "providers");

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

  const data = await queryWithRetry(() => {
    let query = supabase
      .from("sat_monthly_reports")
      .select("*")
      .eq("period_year", year)
      .eq("period_month", month);

    if (params.business_id) query = query.eq("business_id", params.business_id);
    return query;
  }, "summary");

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

  const data = await queryWithRetry(() => {
    return supabase
      .from("platform_sat_declarations")
      .select("*")
      .eq("period_year", year)
      .eq("period_month", month)
      .maybeSingle();
  }, "platform");

  if (!data) {
    return { period: { year, month }, status: "not_generated" };
  }

  return {
    period: { year, month },
    platform: {
      name: "BEAUTYCITA, SOCIEDAD ANONIMA DE CAPITAL VARIABLE",
      rfc: "BEA260313MI8",
      total_businesses: data.total_businesses,
      total_transactions: data.total_transactions,
      total_revenue: data.total_revenue,
      iva_collected: data.total_iva_collected,
      isr_collected: data.total_isr_collected,
      commissions_earned: data.total_commissions,
      status: data.status,
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
