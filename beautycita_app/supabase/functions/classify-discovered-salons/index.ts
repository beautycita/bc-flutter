// =============================================================================
// classify-discovered-salons — HVT auto-classifier
// =============================================================================
// Computes hvt_score from 5 weighted signals and maps salons into 6 tiers.
// Respects tier_locked (manual overrides survive auto runs). Auto-locks
// t1/t2 assignments when hvt_autolock_top_tiers is true.
//
// Triggers:
//   • Cron nightly via pg_cron + service-role key
//   • On-demand admin POST { salon_ids?: uuid[] | null, force?: bool }
//
// Signals (all 0..1 normalized before weighting):
//   chain_size      — owner_chain_size from detect_same_owner_siblings
//   years           — years_in_business
//   reputation      — sigmoid(rating × log(review_count))
//   social          — log10(followers)/5
//   press           — log10(mentions+1)/2
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";

let _req: Request;
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

interface SalonRow {
  id: string;
  business_name: string | null;
  phone: string | null;
  whatsapp: string | null;
  owner_chain_size: number | null;
  years_in_business: number | null;
  reputation_signal_count: number | null;
  reputation_score: number | null;
  social_followers: number | null;
  press_mentions: number | null;
  tier_locked: boolean;
  tier_id: string | null;
}

interface Weights {
  chain: number; years: number; reputation: number; social: number; press: number;
}
interface Thresholds { t1: number; t2: number; t3: number; t4: number; t5: number; }

function sigmoid(x: number): number {
  return 1 / (1 + Math.exp(-x));
}

// Normalizers — clamp to 0..1 with a domain that flags real-world value.
function normChain(n: number | null): number {
  // 1 location → 0, 2 → 0.4, 3 → 0.7, 4+ → 0.9..1.0
  const v = n ?? 1;
  if (v <= 1) return 0;
  return Math.min(1, 0.4 + 0.2 * (v - 2) + (v >= 4 ? 0.1 : 0));
}
function normYears(y: number | null): number {
  // 0 → 0, 5 → 0.5, 10+ → 1
  return Math.min(1, Math.max(0, (y ?? 0) / 10));
}
function normReputation(rating: number | null, count: number | null): number {
  // Bayesian-ish: sigmoid(rating × log(count)). 4.7 stars × 200 reviews → ~0.95.
  const r = rating ?? 0;
  const c = count ?? 0;
  if (c <= 0 || r <= 0) return 0;
  return Math.min(1, sigmoid((r - 3.5) * Math.log10(c + 1)));
}
function normSocial(f: number | null): number {
  // 100 → 0.4, 1k → 0.6, 10k → 0.8, 100k+ → 1.0
  return Math.min(1, Math.log10(Math.max(1, f ?? 0)) / 5);
}
function normPress(p: number | null): number {
  // 0 → 0, 1 → 0.15, 10 → 0.5, 100+ → 1.0
  return Math.min(1, Math.log10((p ?? 0) + 1) / 2);
}

function tierFromScore(score: number, t: Thresholds): string {
  if (score >= t.t1) return "t1";
  if (score >= t.t2) return "t2";
  if (score >= t.t3) return "t3";
  if (score >= t.t4) return "t4";
  if (score >= t.t5) return "t5";
  return "t6";
}

async function readConfigNumber(
  supabase: ReturnType<typeof createClient>,
  key: string,
  fallback: number,
): Promise<number> {
  const { data } = await supabase.from("app_config").select("value").eq("key", key).maybeSingle();
  const n = Number(data?.value);
  return Number.isFinite(n) ? n : fallback;
}

async function readConfigBool(
  supabase: ReturnType<typeof createClient>,
  key: string,
  fallback: boolean,
): Promise<boolean> {
  const { data } = await supabase.from("app_config").select("value").eq("key", key).maybeSingle();
  return data?.value === "true" ? true : data?.value === "false" ? false : fallback;
}

async function loadConfig(supabase: ReturnType<typeof createClient>) {
  const [
    wChain, wYears, wRep, wSoc, wPress,
    tt1, tt2, tt3, tt4, tt5, autoLock,
  ] = await Promise.all([
    readConfigNumber(supabase, "hvt_weight_chain", 0.30),
    readConfigNumber(supabase, "hvt_weight_years", 0.20),
    readConfigNumber(supabase, "hvt_weight_reputation", 0.25),
    readConfigNumber(supabase, "hvt_weight_social", 0.15),
    readConfigNumber(supabase, "hvt_weight_press", 0.10),
    readConfigNumber(supabase, "hvt_threshold_t1", 85),
    readConfigNumber(supabase, "hvt_threshold_t2", 70),
    readConfigNumber(supabase, "hvt_threshold_t3", 55),
    readConfigNumber(supabase, "hvt_threshold_t4", 35),
    readConfigNumber(supabase, "hvt_threshold_t5", 15),
    readConfigBool(supabase, "hvt_autolock_top_tiers", true),
  ]);
  return {
    weights: { chain: wChain, years: wYears, reputation: wRep, social: wSoc, press: wPress } as Weights,
    thresholds: { t1: tt1, t2: tt2, t3: tt3, t4: tt4, t5: tt5 } as Thresholds,
    autoLock,
  };
}

async function refreshChainSize(
  supabase: ReturnType<typeof createClient>,
  salonId: string,
): Promise<number> {
  const { data, error } = await supabase.rpc("detect_same_owner_siblings", { p_salon_id: salonId });
  if (error) {
    console.error(`[classify] sibling detect failed for ${salonId}: ${error.message}`);
    return 1;
  }
  const siblings = (data as Array<{ sibling_id: string; match_score: number }> | null) ?? [];
  // Count siblings with confidence ≥ 0.5 (phone match alone is 0.5).
  const confidentSiblings = siblings.filter((s) => Number(s.match_score) >= 0.5).length;
  return 1 + confidentSiblings;
}

function scoreSalon(salon: SalonRow, w: Weights): { score: number; signals: Record<string, unknown> } {
  const sChain = normChain(salon.owner_chain_size);
  const sYears = normYears(salon.years_in_business);
  const sRep = normReputation(salon.reputation_score, salon.reputation_signal_count);
  const sSoc = normSocial(salon.social_followers);
  const sPress = normPress(salon.press_mentions);

  const raw =
    w.chain * sChain +
    w.years * sYears +
    w.reputation * sRep +
    w.social * sSoc +
    w.press * sPress;
  const wSum = w.chain + w.years + w.reputation + w.social + w.press;
  const score = wSum > 0 ? Math.round((raw / wSum) * 100 * 100) / 100 : 0;

  return {
    score,
    signals: {
      chain_size: salon.owner_chain_size,
      years: salon.years_in_business,
      reputation_score: salon.reputation_score,
      reputation_count: salon.reputation_signal_count,
      social_followers: salon.social_followers,
      press_mentions: salon.press_mentions,
      n: { chain: sChain, years: sYears, rep: sRep, soc: sSoc, press: sPress },
      w,
    },
  };
}

Deno.serve(async (req: Request) => {
  _req = req;
  const preflight = handleCorsPreflightIfOptions(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("authorization") ?? "";
  const cronHeader = req.headers.get("x-cron-secret") ?? "";
  const isCron = !!CRON_SECRET && (
    authHeader === `Bearer ${CRON_SECRET}` || cronHeader === CRON_SECRET
  );
  const isService = authHeader === `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`;

  // For non-cron/non-service callers: must be admin/superadmin authed user.
  let isAdmin = false;
  if (!isCron && !isService) {
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "Unauthorized" }, 401);
    const { data: profile } = await userClient
      .from("profiles").select("role").eq("id", user.id).maybeSingle();
    isAdmin = profile?.role === "admin" || profile?.role === "superadmin";
    if (!isAdmin) return json({ error: "Admin access required" }, 403);
  }

  let body: { salon_ids?: string[]; force?: boolean } = {};
  try { body = await req.json(); } catch { /* empty body OK for cron */ }
  const force = body.force === true;
  const targetIds = Array.isArray(body.salon_ids) ? body.salon_ids : null;

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const config = await loadConfig(supabase);

  // Load salons. Cron path = full table; on-demand path = explicit list or
  // unclassified-only when no list provided.
  let q = supabase
    .from("discovered_salons")
    .select("id,business_name,phone,whatsapp,owner_chain_size,years_in_business," +
            "reputation_signal_count,reputation_score,social_followers,press_mentions," +
            "tier_locked,tier_id");
  if (targetIds) q = q.in("id", targetIds);
  else if (!force) q = q.is("tier_id", null);
  const { data: salonsRaw, error: fetchErr } = await q.limit(5000);
  if (fetchErr) return json({ error: `fetch failed: ${fetchErr.message}` }, 500);

  const salons = (salonsRaw ?? []) as SalonRow[];
  let processed = 0;
  let skippedLocked = 0;
  let updated = 0;
  let autoLocked = 0;

  for (const salon of salons) {
    if (salon.tier_locked && !force) {
      skippedLocked++;
      continue;
    }
    processed++;

    // Refresh chain_size on every classify pass — siblings appear/disappear as
    // the discovered_salons table grows.
    const chainSize = await refreshChainSize(supabase, salon.id);
    const enriched = { ...salon, owner_chain_size: chainSize };

    const { score, signals } = scoreSalon(enriched, config.weights);
    const newTier = tierFromScore(score, config.thresholds);
    const shouldAutoLock = config.autoLock && (newTier === "t1" || newTier === "t2");

    // Skip the write when nothing meaningful changed AND we're not forcing.
    if (!force && salon.tier_id === newTier && salon.owner_chain_size === chainSize) {
      continue;
    }

    // Update cached signals on the salon row.
    const { error: updErr } = await supabase
      .from("discovered_salons")
      .update({
        owner_chain_size: chainSize,
        hvt_score: score,
        tier_locked: shouldAutoLock || salon.tier_locked,
      })
      .eq("id", salon.id);
    if (updErr) {
      console.error(`[classify] update failed for ${salon.id}: ${updErr.message}`);
      continue;
    }

    // Append a current tier_assignment row. The trigger demotes the prior one.
    const { error: assignErr } = await supabase
      .from("discovered_salon_tier_assignments")
      .insert({
        discovered_salon_id: salon.id,
        tier_id: newTier,
        source: "auto",
        reason: salon.tier_id === null
          ? "Initial auto-classification"
          : `Auto-reclassified (${salon.tier_id} → ${newTier}, score=${score})`,
        signal_snapshot: signals,
        is_current: true,
      });
    if (assignErr) {
      console.error(`[classify] assignment insert failed for ${salon.id}: ${assignErr.message}`);
      continue;
    }

    updated++;
    if (shouldAutoLock && !salon.tier_locked) autoLocked++;
  }

  const summary = {
    total: salons.length,
    processed,
    updated,
    skipped_locked: skippedLocked,
    auto_locked: autoLocked,
    weights: config.weights,
    thresholds: config.thresholds,
  };
  console.log("[classify] summary:", JSON.stringify(summary));
  return json(summary);
});
