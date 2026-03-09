// =============================================================================
// sat-access — Real-time data access API for SAT (effective April 2026)
// =============================================================================
// Provides authenticated read-only access to platform transaction data
// as required by Mexican tax law for digital intermediation platforms.
// Uses a separate API key (SAT_API_KEY env var), not Supabase auth.
// All requests are audit-logged to sat_access_log.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SAT_API_KEY = Deno.env.get("SAT_API_KEY") ?? "";

// Rate limit: in-memory sliding window (per instance)
const rateLimitWindow: number[] = [];
const RATE_LIMIT_MAX = 100;
const RATE_LIMIT_WINDOW_MS = 60_000;

serve(async (req) => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Extract request info for logging
  const url = new URL(req.url);
  const endpoint = url.pathname;
  const ipAddress = req.headers.get("x-forwarded-for")
    ?? req.headers.get("cf-connecting-ip")
    ?? "unknown";

  try {
    // API key authentication
    const apiKey = req.headers.get("x-sat-api-key") ?? "";
    if (!SAT_API_KEY || apiKey !== SAT_API_KEY) {
      await logAccess(supabase, endpoint, null, 401, ipAddress, apiKey);
      return json({ error: "Invalid or missing API key" }, 401);
    }

    // Rate limiting
    const now = Date.now();
    while (rateLimitWindow.length > 0 && rateLimitWindow[0] < now - RATE_LIMIT_WINDOW_MS) {
      rateLimitWindow.shift();
    }
    if (rateLimitWindow.length >= RATE_LIMIT_MAX) {
      await logAccess(supabase, endpoint, null, 429, ipAddress, apiKey);
      return json({ error: "Rate limit exceeded (100/min)" }, 429);
    }
    rateLimitWindow.push(now);

    // Parse query parameters
    const params = Object.fromEntries(url.searchParams);

    // Route based on path
    const path = url.pathname.replace(/^\/sat-access\/?/, "").replace(/^\//, "");

    let result: unknown;
    let status = 200;

    switch (path) {
      case "transactions":
        result = await handleTransactions(supabase, params);
        break;
      case "providers":
        result = await handleProviders(supabase, params);
        break;
      case "summary":
        result = await handleSummary(supabase, params);
        break;
      default:
        result = {
          endpoints: [
            "GET /transactions?from=YYYY-MM-DD&to=YYYY-MM-DD&business_id=UUID",
            "GET /providers?rfc=RFC_STRING",
            "GET /summary?period=YYYY-MM",
          ],
        };
    }

    await logAccess(supabase, endpoint, params, status, ipAddress, apiKey);
    return json(result, status);

  } catch (err) {
    console.error("[SAT-ACCESS] Error:", (err as Error).message);
    await logAccess(supabase, endpoint, null, 500, ipAddress, "").catch(() => {});
    return json({ error: (err as Error).message }, 500);
  }
});

// ---------------------------------------------------------------------------
// GET /transactions — Query tax withholding records
// ---------------------------------------------------------------------------
async function handleTransactions(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  let query = supabase
    .from("tax_withholdings")
    .select("*")
    .order("created_at", { ascending: false });

  if (params.from) {
    query = query.gte("created_at", params.from);
  }
  if (params.to) {
    query = query.lte("created_at", `${params.to}T23:59:59Z`);
  }
  if (params.business_id) {
    query = query.eq("business_id", params.business_id);
  }
  if (params.rfc) {
    query = query.eq("provider_rfc", params.rfc);
  }

  // Pagination
  const limit = Math.min(parseInt(params.limit ?? "100"), 1000);
  const offset = parseInt(params.offset ?? "0");
  query = query.range(offset, offset + limit - 1);

  const { data, error, count } = await query;

  if (error) {
    throw new Error(`Query failed: ${error.message}`);
  }

  return {
    data: data ?? [],
    pagination: { limit, offset, count },
  };
}

// ---------------------------------------------------------------------------
// GET /providers — Provider tax status lookup
// ---------------------------------------------------------------------------
async function handleProviders(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  let query = supabase
    .from("businesses")
    .select("id, name, rfc, tax_regime, tax_residency, created_at");

  if (params.rfc) {
    query = query.eq("rfc", params.rfc);
  }
  if (params.business_id) {
    query = query.eq("id", params.business_id);
  }

  const { data, error } = await query;

  if (error) {
    throw new Error(`Query failed: ${error.message}`);
  }

  return { data: data ?? [] };
}

// ---------------------------------------------------------------------------
// GET /summary — Monthly withholding summary
// ---------------------------------------------------------------------------
async function handleSummary(
  supabase: ReturnType<typeof createClient>,
  params: Record<string, string>,
) {
  if (!params.period) {
    throw new Error("period parameter required (format: YYYY-MM)");
  }

  const [yearStr, monthStr] = params.period.split("-");
  const year = parseInt(yearStr);
  const month = parseInt(monthStr);

  if (!year || !month || month < 1 || month > 12) {
    throw new Error("Invalid period format. Use YYYY-MM");
  }

  // Check for pre-generated report
  const { data: report } = await supabase
    .from("sat_monthly_reports")
    .select("*")
    .eq("period_year", year)
    .eq("period_month", month)
    .single();

  if (report) {
    return {
      period: { year, month },
      status: report.status,
      generated_at: report.generated_at,
      totals: {
        transactions: report.total_transactions,
        gross: report.total_gross,
        isr_withheld: report.total_isr_withheld,
        iva_withheld: report.total_iva_withheld,
        platform_fees: report.total_platform_fees,
      },
      report_data: report.report_data,
    };
  }

  // Generate on-the-fly from raw data
  const { data: withholdings, error } = await supabase
    .from("tax_withholdings")
    .select("gross_amount, isr_withheld, iva_withheld, platform_fee")
    .eq("period_year", year)
    .eq("period_month", month);

  if (error) {
    throw new Error(`Query failed: ${error.message}`);
  }

  const records = withholdings ?? [];
  let totalGross = 0;
  let totalIsr = 0;
  let totalIva = 0;
  let totalFees = 0;

  for (const r of records) {
    totalGross += Number(r.gross_amount);
    totalIsr += Number(r.isr_withheld);
    totalIva += Number(r.iva_withheld);
    totalFees += Number(r.platform_fee);
  }

  return {
    period: { year, month },
    status: "live",
    totals: {
      transactions: records.length,
      gross: round2(totalGross),
      isr_withheld: round2(totalIsr),
      iva_withheld: round2(totalIva),
      platform_fees: round2(totalFees),
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
) {
  // SHA-256 hash of API key for audit (never store the key itself)
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
  }).catch((err) => {
    console.error("[SAT-ACCESS] Failed to log access:", err);
  });
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
