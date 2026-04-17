// =============================================================================
// payout-identity-check — Gate payouts on beneficiary identity consistency.
// =============================================================================
// Spec: docs/policies/2026-04-17-payout-beneficiary-lock.md §4.2
// Decision ref: Doc decision #13
//
// Returns { ok, reason?, hold_id? }.
//
// STUB NOTE: CLABE-side destination-holder lookup (STP API / bank-side
// verification) is blocked on BBVA onboarding. Until then this function
// verifies:
//   1. No active payout_hold on the business.
//   2. beneficiary_name and rfc are present (non-null, non-empty).
//   3. RFC is valid format (via normalize_and_validate_rfc trigger shape).
// It logs every run into payout_identity_checks with result='skipped_no_data'
// when the CLABE lookup is unavailable, so downstream can differentiate
// "passed by default" from "passed with destination match".
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders as dynamicCors } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface Body {
  business_id: string;
  /** Optional: caller-supplied destination holder name (e.g., from Stripe Connect). */
  destination_holder_name?: string;
}

interface Result {
  ok: boolean;
  reason?:
    | "active_hold"
    | "missing_beneficiary_data"
    | "invalid_rfc"
    | "name_mismatch_hard"
    | "name_mismatch_review"
    | "rfc_mismatch"
    | "business_not_found";
  hold_id?: string;
  name_score?: number;
}

const RFC_REGEX = /^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$/;

function normalizeName(s: string): string {
  return s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toUpperCase()
    .replace(/\b(S\.?A\.?|DE|C\.?V\.?|S\.?A\.?P\.?I\.?|S\.?C\.?|S\.?R\.?L\.?)\b/g, "")
    .replace(/[^A-Z0-9 ]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// Jaro-Winkler similarity (0-1). Good enough for name comparison without a dep.
function jaroWinkler(a: string, b: string): number {
  if (a === b) return 1.0;
  if (!a || !b) return 0.0;

  const matchDistance = Math.max(0, Math.floor(Math.max(a.length, b.length) / 2) - 1);
  const aMatches = new Array(a.length).fill(false);
  const bMatches = new Array(b.length).fill(false);
  let matches = 0;

  for (let i = 0; i < a.length; i++) {
    const start = Math.max(0, i - matchDistance);
    const end = Math.min(i + matchDistance + 1, b.length);
    for (let j = start; j < end; j++) {
      if (bMatches[j]) continue;
      if (a[i] !== b[j]) continue;
      aMatches[i] = true;
      bMatches[j] = true;
      matches++;
      break;
    }
  }
  if (matches === 0) return 0.0;

  let t = 0;
  let k = 0;
  for (let i = 0; i < a.length; i++) {
    if (!aMatches[i]) continue;
    while (!bMatches[k]) k++;
    if (a[i] !== b[k]) t++;
    k++;
  }
  t = t / 2;

  const jaro = (matches / a.length + matches / b.length + (matches - t) / matches) / 3;

  // Winkler prefix boost (up to 4 chars, scale 0.1)
  let prefix = 0;
  for (let i = 0; i < Math.min(4, a.length, b.length); i++) {
    if (a[i] === b[i]) prefix++;
    else break;
  }
  return jaro + prefix * 0.1 * (1 - jaro);
}

serve(async (req) => {
  const corsHeaders = dynamicCors(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const body: Body = await req.json();
    if (!body?.business_id) {
      return json({ ok: false, reason: "business_not_found" as const }, 400, corsHeaders);
    }

    // 1. Load business + active hold status
    const { data: biz } = await supabase
      .from("businesses")
      .select("id, beneficiary_name, rfc, clabe")
      .eq("id", body.business_id)
      .maybeSingle();

    if (!biz) {
      return json({ ok: false, reason: "business_not_found" as const }, 404, corsHeaders);
    }

    const { data: holdRows } = await supabase
      .from("payout_holds")
      .select("id")
      .eq("business_id", body.business_id)
      .is("released_at", null)
      .limit(1);

    if (holdRows && holdRows.length > 0) {
      await logCheck(supabase, body.business_id, null, null, body.destination_holder_name ?? null, "fail", "active_hold");
      const result: Result = { ok: false, reason: "active_hold", hold_id: holdRows[0].id as string };
      return json(result, 200, corsHeaders);
    }

    // 2. Beneficiary data presence
    const name: string | null = biz.beneficiary_name ?? null;
    const rfc: string | null = biz.rfc ?? null;

    if (!name || !name.trim() || !rfc || !rfc.trim()) {
      await logCheck(supabase, body.business_id, null, null, body.destination_holder_name ?? null, "fail", "missing_beneficiary_data");
      const result: Result = { ok: false, reason: "missing_beneficiary_data" };
      return json(result, 200, corsHeaders);
    }

    // 3. RFC format
    if (!RFC_REGEX.test(rfc.toUpperCase())) {
      await logCheck(supabase, body.business_id, false, null, body.destination_holder_name ?? null, "fail", "invalid_rfc");
      const result: Result = { ok: false, reason: "invalid_rfc" };
      return json(result, 200, corsHeaders);
    }

    // 4. Name score — only computable when caller supplies a destination holder name.
    //    Until CLABE-side lookup is wired (BBVA meeting), callers rarely supply this.
    if (body.destination_holder_name && body.destination_holder_name.trim()) {
      const lhs = normalizeName(name);
      const rhs = normalizeName(body.destination_holder_name);
      const score = jaroWinkler(lhs, rhs);

      if (score >= 0.90) {
        await logCheck(supabase, body.business_id, true, score, body.destination_holder_name, "pass", null);
        return json({ ok: true, name_score: score } satisfies Result, 200, corsHeaders);
      }
      if (score >= 0.80) {
        const { data: hold } = await supabase
          .from("payout_holds")
          .insert({
            business_id: body.business_id,
            reason: "identity_mismatch",
            old_value: name,
            new_value: body.destination_holder_name,
          })
          .select("id")
          .single();
        await logCheck(supabase, body.business_id, true, score, body.destination_holder_name, "review", null);
        return json({ ok: false, reason: "name_mismatch_review", hold_id: hold?.id as string, name_score: score } satisfies Result, 200, corsHeaders);
      }
      const { data: hold } = await supabase
        .from("payout_holds")
        .insert({
          business_id: body.business_id,
          reason: "identity_mismatch",
          old_value: name,
          new_value: body.destination_holder_name,
        })
        .select("id")
        .single();
      await logCheck(supabase, body.business_id, true, score, body.destination_holder_name, "fail", null);
      return json({ ok: false, reason: "name_mismatch_hard", hold_id: hold?.id as string, name_score: score } satisfies Result, 200, corsHeaders);
    }

    // 5. No destination data available — skipped.
    //    Pass by default once basic presence+format passes. When BBVA lookup is
    //    wired, flip this branch to 'fail' for safety.
    await logCheck(supabase, body.business_id, true, null, null, "skipped_no_data", null);
    return json({ ok: true } satisfies Result, 200, corsHeaders);

  } catch (err) {
    console.error("[PAYOUT-IDENTITY-CHECK] Error:", err);
    return json({ ok: false, reason: "business_not_found" as const }, 500, dynamicCors(req));
  }
});

async function logCheck(
  supabase: ReturnType<typeof createClient>,
  businessId: string,
  rfcMatch: boolean | null,
  nameScore: number | null,
  destName: string | null,
  result: "pass" | "review" | "fail" | "skipped_no_data",
  notes: string | null,
) {
  await supabase.from("payout_identity_checks").insert({
    business_id: businessId,
    rfc_match: rfcMatch,
    name_score: nameScore,
    destination_holder_name: destName,
    result,
    notes,
  }).then(null, (e: Error) =>
    console.error(`[PAYOUT-IDENTITY-CHECK] Log insert failed: ${e.message}`)
  );
}

function json(body: unknown, status: number, headers: Record<string, string>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}
