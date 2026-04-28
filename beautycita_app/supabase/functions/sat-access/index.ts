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
const BC_PHONE = Deno.env.get("BC_ALERT_PHONE") ?? "";

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

// Suppression window per-reason so a real SAT hammering us doesn't spam
// hundreds of WA messages. 15-minute cooldown per distinct reason string.
const ALERT_SUPPRESSION_MS = 15 * 60 * 1000;
const lastAlertByReason = new Map<string, number>();

// Owner whitelist: BC's own ISP range (177.248.0.0/16 per infra.md).
// When exploring from his own IP, don't wake him up with his own probes.
function isOwnerIp(ip: string | null): boolean {
  if (!ip) return false;
  return ip.startsWith("177.248.");
}

async function maybeAlertBC(
  reason: string,
  details: string,
  ip: string | null,
  tone: "success" | "internal_failure" = "internal_failure",
) {
  if (isOwnerIp(ip)) {
    console.log(`[SAT-ALERT] suppressed (owner IP ${ip}): ${reason}`);
    return;
  }
  const cooldownKey = `${tone}:${reason}`;
  const last = lastAlertByReason.get(cooldownKey) ?? 0;
  if (Date.now() - last < ALERT_SUPPRESSION_MS) {
    console.log(`[SAT-ALERT] suppressed (cooldown): ${reason}`);
    return;
  }
  lastAlertByReason.set(cooldownKey, Date.now());
  await alertBC(reason, details, tone);
}

// ── Alert BC ─ success or internal-failure only. Caller-side failures
//    (invalid key, bad signature, expired timestamp, rate limited) are
//    user-input noise and intentionally NOT alerted; they're still logged
//    via logAccess() so a real attack pattern is auditable on demand.
async function alertBC(
  reason: string,
  details: string,
  tone: "success" | "internal_failure" = "internal_failure",
) {
  const header = tone === "success"
    ? `✅ *SAT API access* ✅`
    : `🚨 *SAT API ALERT* 🚨`;
  const footer = tone === "success"
    ? `_SAT successfully pulled data from the API._`
    : `_This is a critical alert. The SAT API experienced an internal failure. Investigate immediately._`;
  const msg = `${header}\n\n*Reason:* ${reason}\n*Details:* ${details}\n*Time:* ${new Date().toISOString()}\n\n${footer}`;

  // Try WA alert. Skip cleanly if BC_ALERT_PHONE is unset — never send to a
  // fabricated / hardcoded recipient again.
  if (!BC_PHONE) {
    console.error("[SAT-ALERT] BC_ALERT_PHONE env var missing — WA alert skipped");
  } else {
    try {
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      const { createClient: _createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
      const { enqueueWa, WA_PRIORITY } = await import("../_shared/wa_queue.ts");
      const supabase = _createClient(supabaseUrl, serviceKey);
      await enqueueWa(supabase, BC_PHONE, msg, {
        priority: WA_PRIORITY.CRITICAL,
        source: "sat-access:alert",
      });
    } catch (e) {
      console.error("[SAT-ALERT] WA alert failed:", e);
    }
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
    await maybeAlertBC("Supabase client init failed", String(e), null, "internal_failure");
    return json(SAT_RETRY_MESSAGE, 503);
  }

  const url = new URL(req.url);
  const endpoint = url.pathname + url.search;
  const rawIp = req.headers.get("x-forwarded-for")
    ?? req.headers.get("cf-connecting-ip")
    ?? null;
  const ipAddress = rawIp ? rawIp.split(",")[0].trim() : null;

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
      // Caller-side noise. Log only — do NOT alert. A real intrusion
      // pattern is detectable from sat_access_log without spamming WA.
      logAccess(supabase, endpoint, null, 401, ipAddress, apiKey, "invalid_key").catch((e) => console.error("[SAT-ACCESS] logAccess failed:", e));
      return json({ error: "Invalid or missing API key" }, 401);
    }

    const ts = parseInt(timestamp);
    if (!ts || Math.abs(Date.now() - ts) > TIMESTAMP_TOLERANCE_MS) {
      // Caller-side noise — clock drift / replay. Log only.
      logAccess(supabase, endpoint, null, 401, ipAddress, apiKey, "expired_timestamp").catch((e) => console.error("[SAT-ACCESS] logAccess failed:", e));
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
      // Caller-side noise. Valid key + bad signature is either a probe or
      // a misconfigured caller — auditable via sat_access_log. No WA alert.
      logAccess(supabase, endpoint, null, 403, ipAddress, apiKey, "invalid_signature").catch((e) => console.error("[SAT-ACCESS] logAccess failed:", e));
      return json({ error: "Invalid signature" }, 403);
    }

    // ── Rate Limiting ─────────────────────────────────────────────────
    const now = Date.now();
    while (rateLimitWindow.length > 0 && rateLimitWindow[0] < now - RATE_LIMIT_WINDOW_MS) {
      rateLimitWindow.shift();
    }
    if (rateLimitWindow.length >= RATE_LIMIT_MAX) {
      // Caller-side noise — log only. If SAT actually exceeds the rate
      // limit during a real audit, the access log will show the burst
      // and we can raise RATE_LIMIT_MAX without WA spam.
      logAccess(supabase, endpoint, null, 429, ipAddress, apiKey, "rate_limited").catch((e) => console.error("[SAT-ACCESS] logAccess failed:", e));
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

    logAccess(supabase, endpoint, params, 200, ipAddress, apiKey, "success").catch((e) => console.error("[SAT-ACCESS] logAccess failed:", e));
    // Notify BC on a real successful pull — once per 15 min per route so a
    // multi-endpoint SAT audit doesn't generate five WAs in 30 seconds.
    maybeAlertBC(
      `SAT pulled ${routePath || "index"}`,
      `IP ${ipAddress ?? "?"} endpoint ${endpoint}`,
      ipAddress,
      "success",
    ).catch((e) => console.error("[SAT-ALERT] maybeAlertBC failed:", e));
    return json(result);

  } catch (err) {
    // ── CRITICAL: SAT never sees an error — only the retry message ───
    const errMsg = (err as Error).message ?? String(err);
    console.error("[SAT-ACCESS] CRITICAL FAILURE:", errMsg);

    // Alert BC on real internal failure (post-auth crash). Route through
    // maybeAlertBC so a hammered failure mode (e.g. DB outage during a
    // SAT pull) doesn't spam — one alert per 15 min per error string.
    await maybeAlertBC(
      "Query/processing failure",
      errMsg,
      ipAddress,
      "internal_failure",
    );

    // Log the failure
    logAccess(supabase, endpoint, null, 503, ipAddress, "", `critical_error: ${errMsg}`).catch((e) => console.error("[SAT-ACCESS] logAccess failed:", e));

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

  // external_free visibility toggle (design doc §3 — default OFF per BC 2026-04-23).
  // When OFF: completely exclude external_free rows from the SAT feed.
  // When ON: include them with collected_by_platform=false marker (no financial impact).
  const { data: toggle } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", "external_free_sat_visible")
    .maybeSingle();
  const externalFreeVisible = toggle?.value === "true";

  const data = await queryWithRetry(() => {
    // Escrito libre §III commits BC-facilitated transactions only. Off-network
    // (salon_direct, walk_in) are the salon's own clients paid outside BC
    // rails; BC never withheld taxes on them and they must never appear in
    // the SAT feed. Defense in depth: create_booking_with_financials also
    // skips tax_withholdings for off-network.
    let query = supabase
      .from("appointments")
      .select(`
        id, business_id, starts_at, price, payment_method, payment_status,
        isr_withheld, iva_withheld, tax_base, provider_net,
        service_name, status, created_at, booking_source,
        businesses!inner(name, rfc, tax_regime, is_test)
      `)
      .eq("status", "completed")
      .in("booking_source", ["bc_marketplace", "invite_link"])
      .eq("businesses.is_test", false)
      .order("starts_at", { ascending: false });

    if (externalFreeVisible) {
      // Include both regular paid rows AND external_free
      query = query.in("payment_status", ["paid", "external_collected"]);
    } else {
      query = query.eq("payment_status", "paid")
                   .neq("payment_method", "external_free");
    }

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
      collected_by_platform: t.payment_method !== "external_free",
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
      .select("*, businesses!inner(is_test)")
      .eq("period_year", year)
      .eq("period_month", month)
      .eq("businesses.is_test", false)
      .order("created_at", { ascending: false });

    if (params.business_id) query = query.eq("business_id", params.business_id);
    return query.range(offset, offset + limit - 1);
  }, "withholdings");

  // Strip the join-only is_test marker before returning to SAT.
  return {
    period: { year, month },
    data: (data ?? []).map((w: any) => {
      const { businesses: _drop, ...rest } = w;
      return rest;
    }),
  };
}

// ---------------------------------------------------------------------------
// GET /providers — Business/provider tax lookup
// ---------------------------------------------------------------------------
async function handleProviders(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  const data = await queryWithRetry(() => {
    // Escrito commitment: "prestadores de servicios REGISTRADOS".
    // Soft-deleted rows (is_active=false) are NOT currently registered — exclude them.
    let query = supabase
      .from("businesses")
      .select("id, name, rfc, tax_regime, tax_residency, city, state, is_active, created_at")
      .eq("is_active", true)
      .eq("is_test", false);

    if (params.rfc) query = query.eq("rfc", params.rfc);
    if (params.business_id) query = query.eq("id", params.business_id);
    return query;
  }, "providers");

  // RFC is mandatory for a legally-registered provider; drop any row missing it.
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
      .select("*, businesses!inner(is_test)")
      .eq("period_year", year)
      .eq("period_month", month)
      .eq("businesses.is_test", false);

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

  const { error } = await supabase.from("sat_access_log").insert({
    endpoint,
    query_params: queryParams,
    response_status: responseStatus,
    ip_address: ipAddress,
    api_key_hash: keyHash,
    result,
  });
  if (error) {
    console.error("[SAT-ACCESS] Failed to log:", error.message);
  }
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
