// =============================================================================
// reconciliation-watchdog — runs the 3 accounting invariants and alerts BC
// =============================================================================
//
// Invoked by a cron (systemd timer on www-bc or external scheduler) at a
// chosen cadence. Calls run_reconciliation_all() RPC, inspects worst_status:
//
//   * 'ok'       → return 200, no alert
//   * 'warning'  → return 200, log but don't page BC
//   * 'critical' → return 200, fire WA alert to BC with drift summary
//   * 'error'    → return 500, fire WA alert (schema mismatch / bug)
//
// Auth: requires CRON_SECRET (prevents random hits from paging BC).
//
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const WA_API_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "http://172.22.0.1:3200";
const WA_API_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const BC_PHONE = Deno.env.get("BC_ALERT_PHONE") ?? "";

async function sendAlert(message: string): Promise<boolean> {
  if (!WA_API_URL || !BC_PHONE) return false;
  try {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 5000);
    const res = await fetch(`${WA_API_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${WA_API_TOKEN}`,
      },
      body: JSON.stringify({ phone: BC_PHONE, message }),
      signal: ac.signal,
    });
    clearTimeout(t);
    return res.ok;
  } catch (_) { return false; }
}

interface CheckResult {
  log_id: string;
  check_name: string;
  expected?: number;
  actual?: number;
  drift?: number;
  status: string;
  offender_count?: number;
  error?: string;
}

function formatCheck(c: CheckResult): string {
  const sym = c.status === 'ok' ? '✓' : c.status === 'warning' ? '⚠' : '✗';
  if (c.status === 'error') {
    return `${sym} ${c.check_name}: error — ${c.error ?? 'unknown'}`;
  }
  const drift = Number(c.drift ?? 0).toFixed(2);
  const offs = c.offender_count != null && c.offender_count > 0
    ? ` (${c.offender_count} offenders)` : '';
  return `${sym} ${c.check_name}: drift=${drift}${offs}`;
}

Deno.serve(async (req) => {
  const pre = handleCorsPreflightIfOptions(req);
  if (pre) return pre;

  // CRON_SECRET auth. The Supabase Kong gateway already requires
  // `Authorization: Bearer <ANON_KEY>` upstream, so we can't re-use that
  // header for our cron secret. Accept the secret via x-cron-secret
  // (preferred) or ?secret= query string.
  const url = new URL(req.url);
  const providedSecret =
    req.headers.get("x-cron-secret") ?? url.searchParams.get("secret") ?? "";
  if (!CRON_SECRET || providedSecret !== CRON_SECRET) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data, error } = await supabase.rpc("run_reconciliation_all");

    if (error) {
      await sendAlert(
        `🚨 *BeautyCita reconciliation watchdog FAILED*\n\nCould not run run_reconciliation_all():\n${error.message}`,
      );
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders(req), "Content-Type": "application/json" },
      });
    }

    const result = data as {
      user_saldo: CheckResult;
      business_debt: CheckResult;
      platform: CheckResult;
      worst_status: string;
      checked_at: string;
    };

    // Alert on critical or error
    if (result.worst_status === "critical" || result.worst_status === "error") {
      const lines = [
        result.worst_status === "critical"
          ? "🚨 *BeautyCita accounting invariant FAILED*"
          : "⚠️ *BeautyCita reconciliation check ERRORED*",
        "",
        formatCheck(result.user_saldo),
        formatCheck(result.business_debt),
        formatCheck(result.platform),
        "",
        `_Checked at ${result.checked_at}_`,
        "Run admin query on reconciliation_log for offenders.",
      ];
      await sendAlert(lines.join("\n"));
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await sendAlert(`🚨 *reconciliation-watchdog crash*: ${msg}`);
    return new Response(JSON.stringify({ error: msg }), {
      status: 500,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }
});
