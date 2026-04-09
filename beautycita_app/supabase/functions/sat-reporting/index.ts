// =============================================================================
// sat-reporting — Generate monthly tax withholding reports for SAT
// =============================================================================
// Aggregates tax_withholdings for a given month, generates per-provider
// breakdown, stores in sat_monthly_reports. Used for the "declaración
// informativa" due by the 10th of the following month.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

const corsHeaders = (req: Request) => ({
  "Access-Control-Allow-Origin": corsOrigin(req),
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
});

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface ReportRequest {
  year: number;
  month: number; // 1-12
}

let _req: Request;

serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Auth check — require service_role or admin
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");

    // Allow service_role key or authenticated admin
    const isServiceRole = token === SUPABASE_SERVICE_ROLE_KEY;
    if (!isServiceRole) {
      const { data: { user }, error: authError } = await supabase.auth.getUser(token);
      if (authError || !user) {
        return json({ error: "Unauthorized" }, 401);
      }
      // Check admin role
      const { data: profile } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", user.id)
        .single();
      if (profile?.role !== "admin") {
        return json({ error: "Admin access required" }, 403);
      }
    }

    const body: ReportRequest = await req.json();
    const { year, month } = body;

    if (!year || !month || month < 1 || month > 12) {
      return json({ error: "Valid year and month (1-12) are required" }, 400);
    }

    // Fetch all withholdings for the period
    const { data: withholdings, error: fetchError } = await supabase
      .from("tax_withholdings")
      .select("*")
      .eq("period_year", year)
      .eq("period_month", month)
      .order("created_at", { ascending: true });

    if (fetchError) {
      console.error("[SAT-REPORTING] Failed to fetch withholdings:", fetchError.message);
      return json({ error: "Failed to fetch withholdings" }, 500);
    }

    const records = withholdings ?? [];

    // Aggregate totals
    let totalGross = 0;
    let totalIsrWithheld = 0;
    let totalIvaWithheld = 0;
    let totalPlatformFees = 0;

    // Per-provider breakdown
    const providerMap = new Map<string, {
      business_id: string;
      rfc: string | null;
      tax_residency: string;
      transactions: number;
      gross: number;
      isr_withheld: number;
      iva_withheld: number;
      platform_fees: number;
      provider_net: number;
    }>();

    for (const w of records) {
      totalGross += Number(w.gross_amount);
      totalIsrWithheld += Number(w.isr_withheld);
      totalIvaWithheld += Number(w.iva_withheld);
      totalPlatformFees += Number(w.platform_fee);

      const key = w.business_id;
      const existing = providerMap.get(key);
      if (existing) {
        existing.transactions++;
        existing.gross += Number(w.gross_amount);
        existing.isr_withheld += Number(w.isr_withheld);
        existing.iva_withheld += Number(w.iva_withheld);
        existing.platform_fees += Number(w.platform_fee);
        existing.provider_net += Number(w.provider_net);
      } else {
        providerMap.set(key, {
          business_id: w.business_id,
          rfc: w.provider_rfc,
          tax_residency: w.provider_tax_residency,
          transactions: 1,
          gross: Number(w.gross_amount),
          isr_withheld: Number(w.isr_withheld),
          iva_withheld: Number(w.iva_withheld),
          platform_fees: Number(w.platform_fee),
          provider_net: Number(w.provider_net),
        });
      }
    }

    // Round totals
    totalGross = round2(totalGross);
    totalIsrWithheld = round2(totalIsrWithheld);
    totalIvaWithheld = round2(totalIvaWithheld);
    totalPlatformFees = round2(totalPlatformFees);

    const providerBreakdown = Array.from(providerMap.values()).map((p) => ({
      ...p,
      gross: round2(p.gross),
      isr_withheld: round2(p.isr_withheld),
      iva_withheld: round2(p.iva_withheld),
      platform_fees: round2(p.platform_fees),
      provider_net: round2(p.provider_net),
    }));

    // Calculate due dates:
    // Informative return: 10th of following month
    // Remittance: 17th of following month
    const nextMonth = month === 12 ? 1 : month + 1;
    const nextYear = month === 12 ? year + 1 : year;
    const informativeDue = `${nextYear}-${String(nextMonth).padStart(2, "0")}-10`;
    const remittanceDue = `${nextYear}-${String(nextMonth).padStart(2, "0")}-17`;

    const reportData = {
      period: { year, month },
      generated_at: new Date().toISOString(),
      totals: {
        transactions: records.length,
        gross: totalGross,
        isr_withheld: totalIsrWithheld,
        iva_withheld: totalIvaWithheld,
        total_withheld: round2(totalIsrWithheld + totalIvaWithheld),
        platform_fees: totalPlatformFees,
      },
      due_dates: {
        informative: informativeDue,
        remittance: remittanceDue,
      },
      providers: providerBreakdown,
    };

    // Upsert into sat_monthly_reports
    const { error: upsertError } = await supabase
      .from("sat_monthly_reports")
      .upsert({
        period_year: year,
        period_month: month,
        total_transactions: records.length,
        total_gross: totalGross,
        total_isr_withheld: totalIsrWithheld,
        total_iva_withheld: totalIvaWithheld,
        total_platform_fees: totalPlatformFees,
        status: "generated",
        report_data: reportData,
        generated_at: new Date().toISOString(),
        due_date: informativeDue,
      }, {
        onConflict: "period_year,period_month",
      });

    if (upsertError) {
      console.error("[SAT-REPORTING] Failed to save report:", upsertError.message);
      return json({ error: "Failed to save report" }, 500);
    }

    // Also generate/update per-business sat_monthly_reports
    for (const provider of providerBreakdown) {
      const { error: perBizError } = await supabase.from("sat_monthly_reports").upsert({
        business_id: provider.business_id,
        period_year: year,
        period_month: month,
        total_transactions: provider.transactions,
        total_gross: provider.gross,
        total_isr_withheld: provider.isr_withheld,
        total_iva_withheld: provider.iva_withheld,
        total_platform_fees: provider.platform_fees,
        status: "generated",
        generated_at: new Date().toISOString(),
      }, {
        onConflict: "period_year,period_month,business_id",
      });
      if (perBizError) {
        console.error(`[SAT-REPORTING] Per-biz upsert error: ${perBizError.message}`);
      }
    }

    // Generate platform-level declaration
    // Count unique businesses, sum commissions, compute totals
    const { data: commissions } = await supabase
      .from("commission_records")
      .select("amount")
      .eq("period_year", year)
      .eq("period_month", month);
    const totalCommissions = (commissions ?? []).reduce((sum: number, c: { amount: number }) => sum + Number(c.amount), 0);

    const { error: declError } = await supabase.from("platform_sat_declarations").upsert({
      period_year: year,
      period_month: month,
      total_businesses: providerBreakdown.length,
      total_transactions: records.length,
      total_revenue_all: totalGross,
      total_iva_collected: totalIvaWithheld,
      total_isr_collected: totalIsrWithheld,
      total_commissions_earned: round2(totalCommissions),
      total_paid_to_sat: round2(totalIsrWithheld + totalIvaWithheld),
      status: "generated",
      generated_at: new Date().toISOString(),
    }, {
      onConflict: "period_year,period_month",
    });
    if (declError) {
      console.error(`[SAT-REPORTING] Platform declaration error: ${declError.message}`);
    }

    console.log(`[SAT-REPORTING] Generated report for ${year}-${String(month).padStart(2, "0")}`);
    console.log(`  Transactions: ${records.length}`);
    console.log(`  ISR withheld: $${totalIsrWithheld} MXN`);
    console.log(`  IVA withheld: $${totalIvaWithheld} MXN`);
    console.log(`  Commissions: $${round2(totalCommissions)} MXN`);
    console.log(`  Businesses: ${providerBreakdown.length}`);

    return json(reportData);

  } catch (err) {
    console.error("[SAT-REPORTING] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}
