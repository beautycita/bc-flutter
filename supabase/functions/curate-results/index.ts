// =============================================================================
// curate-results — BeautyCita Intelligence Engine
// =============================================================================
// 6-step pipeline: Profile Lookup → Time Inference → Candidate Query →
// Score & Rank → Pick Top 3 → Build Response
// Target: 200-400ms total
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface CurateRequest {
  service_type: string;
  user_id: string | null;
  location: { lat: number; lng: number };
  transport_mode: "car" | "uber" | "transit";
  follow_up_answers?: Record<string, string>;
  override_window?: {
    range: "today" | "tomorrow" | "this_week" | "next_week";
    time_of_day: "morning" | "afternoon" | "evening" | null;
    specific_date: string | null;
  } | null;
  business_id?: string; // Lock to specific business (Cita Express)
}

interface BookingWindow {
  primary_date: string;
  primary_time: string;
  window_start: string;
  window_end: string;
  slot_preferences: Map<string, number>;
}

interface Candidate {
  business_id: string;
  business_name: string;
  business_photo: string | null;
  business_address: string | null;
  business_lat: number;
  business_lng: number;
  business_whatsapp: string | null;
  business_rating: number;
  business_reviews: number;
  cancellation_hours: number;
  deposit_required: boolean;
  auto_confirm: boolean;
  accept_walkins: boolean;
  service_id: string;
  service_name: string;
  service_price: number;
  duration_minutes: number;
  buffer_minutes: number;
  staff_id: string;
  staff_name: string;
  staff_avatar: string | null;
  experience_years: number | null;
  staff_rating: number;
  staff_reviews: number;
  effective_price: number;
  effective_duration: number;
  distance_m: number;
  slot_start: string;
  slot_end: string;
}

interface ScoredCandidate extends Candidate {
  score: number;
  transport: {
    mode: string;
    duration_min: number;
    distance_km: number;
    traffic_level: string;
    uber_estimate_min: number | null;
    uber_estimate_max: number | null;
    transit_summary: string | null;
    transit_stops: number | null;
  };
  area_avg_price: number;
  breakdown: {
    proximity: number;
    availability: number;
    rating: number;
    price: number;
    portfolio: number;
  };
}

// deno-lint-ignore no-explicit-any
type ServiceProfile = Record<string, any>;

// ---------------------------------------------------------------------------
// In-memory profile cache (profiles rarely change)
// ---------------------------------------------------------------------------

const profileCache = new Map<string, { data: ServiceProfile; at: number }>();
const CACHE_TTL = 5 * 60 * 1000; // 5 min

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function median(vals: number[]): number {
  if (vals.length === 0) return 0;
  const s = [...vals].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

function clamp01(v: number): number {
  return Math.max(0, Math.min(1, v));
}

function isToday(isoString: string): boolean {
  const d = new Date(isoString);
  const now = new Date();
  return (
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate()
  );
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Soft auth — verify JWT if present but don't block on failure.
    // This function is read-only and uses service_role for all DB queries.
    // user_id for preference lookup comes from the request body.
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    if (token) {
      const { error: authError } = await supabase.auth.getUser(token);
      if (authError) {
        console.warn("[curate-results] Auth soft-fail:", authError.message);
      }
    }

    const body: CurateRequest = await req.json();
    const {
      service_type,
      user_id,
      location,
      transport_mode,
      override_window,
      business_id,
    } = body;

    if (!service_type || !location?.lat || !location?.lng) {
      return json({ error: "service_type and location are required" }, 400);
    }
    if (!["car", "uber", "transit"].includes(transport_mode)) {
      return json(
        { error: "transport_mode must be car, uber, or transit" },
        400,
      );
    }

    // ==================================================================
    // STEP 1 — Profile Lookup (<1ms cached)
    // ==================================================================
    const profile = await profileLookup(supabase, service_type);
    if (!profile) {
      return json({ error: `Unknown service type: ${service_type}` }, 404);
    }

    // ==================================================================
    // STEP 2 — Time Inference (<5ms)
    // ==================================================================
    const window = await inferWindow(
      supabase,
      profile,
      user_id,
      override_window ?? null,
    );

    // Log time correction when override_window is present (fire-and-forget)
    if (override_window) {
      logTimeCorrection(supabase, profile, user_id, override_window, service_type)
        .catch((err) => console.error("Failed to log time correction:", err));
    }

    // ==================================================================
    // STEP 3 — Candidate Query (50-100ms)
    // ==================================================================
    const baseRadius = Number(profile.search_radius_km) * 1000;
    let candidates = await queryCandidates(
      supabase,
      service_type,
      location,
      baseRadius,
      window,
      business_id,
    );

    // Auto-radius expansion (skip when locked to a specific business)
    if (candidates.length < 3 && profile.radius_auto_expand && !business_id) {
      let mult = 1.5;
      const maxMult = Number(profile.radius_max_multiplier) || 3;
      while (candidates.length < 3 && mult <= maxMult) {
        candidates = await queryCandidates(
          supabase,
          service_type,
          location,
          baseRadius * mult,
          window,
        );
        mult *= 1.5;
      }
    }

    if (candidates.length === 0) {
      return json({
        booking_window: windowSummary(window),
        results: [],
      });
    }

    // ==================================================================
    // STEP 4 — Score & Rank (50-150ms)
    // ==================================================================
    const scored = await scoreCandidates(
      candidates,
      profile,
      window,
      transport_mode,
      location,
    );

    // ==================================================================
    // STEP 5 — Pick Top 3
    // ==================================================================
    const top3 = pickTop3(scored);

    // ==================================================================
    // STEP 6 — Build Response (<5ms)
    // ==================================================================
    const results = await buildResponse(supabase, top3, profile, service_type);

    return json({
      booking_window: windowSummary(window),
      results,
    });
  } catch (err) {
    console.error("curate-results error:", err);
    return json({ error: (err as Error).message }, 500);
  }
});

function windowSummary(w: BookingWindow) {
  return {
    primary_date: w.primary_date,
    primary_time: w.primary_time,
    window_start: w.window_start,
    window_end: w.window_end,
  };
}

// =========================================================================
// STEP 1 — Profile Lookup
// =========================================================================

async function profileLookup(
  sb: SupabaseClient,
  serviceType: string,
): Promise<ServiceProfile | null> {
  const cached = profileCache.get(serviceType);
  if (cached && Date.now() - cached.at < CACHE_TTL) return cached.data;

  const { data, error } = await sb
    .from("service_profiles")
    .select("*")
    .eq("service_type", serviceType)
    .eq("is_active", true)
    .single();

  if (error || !data) return null;
  profileCache.set(serviceType, { data, at: Date.now() });
  return data;
}

// =========================================================================
// STEP 2 — Time Inference
// =========================================================================

async function inferWindow(
  sb: SupabaseClient,
  profile: ServiceProfile,
  userId: string | null,
  override: CurateRequest["override_window"] | null,
): Promise<BookingWindow> {
  const now = new Date();

  if (override) return buildOverrideWindow(now, override, profile);

  const hour = now.getHours();
  const dow = now.getDay(); // 0=Sun

  // Fetch matching rules — rules where current hour+dow falls inside range
  const { data: rules } = await sb
    .from("time_inference_rules")
    .select("*")
    .eq("is_active", true);

  // Filter in code because ranges can wrap (e.g. hour 21-6)
  const matching = (rules ?? []).filter((r: Record<string, number>) => {
    const hMatch =
      r.hour_start <= r.hour_end
        ? hour >= r.hour_start && hour <= r.hour_end
        : hour >= r.hour_start || hour <= r.hour_end;
    const dMatch =
      r.day_of_week_start <= r.day_of_week_end
        ? dow >= r.day_of_week_start && dow <= r.day_of_week_end
        : dow >= r.day_of_week_start || dow <= r.day_of_week_end;
    return hMatch && dMatch;
  });

  // Pick narrowest match
  const rule = matching.length > 0
    ? matching.reduce((best: Record<string, number>, r: Record<string, number>) => {
        const bSpan = Math.abs(best.hour_end - best.hour_start);
        const rSpan = Math.abs(r.hour_end - r.hour_start);
        return rSpan < bSpan ? r : best;
      })
    : {
        window_offset_days_min: 0,
        window_offset_days_max: 1,
        preferred_hour_start: 10,
        preferred_hour_end: 16,
        preference_peak_hour: 11,
      };

  // Apply lead-time override from service profile
  let offMin = Number(rule.window_offset_days_min);
  let offMax = Number(rule.window_offset_days_max);

  switch (profile.typical_lead_time) {
    case "same_day":
      // Contract to today + tomorrow regardless of rule
      offMin = 0;
      offMax = 1;
      break;
    case "next_day":
      // Tomorrow through day-after-tomorrow
      offMin = 1;
      offMax = 2;
      break;
    case "this_week":
      // Expand to 5-7 days
      offMin = Math.min(offMin, 1);
      offMax = Math.max(offMax, 7);
      break;
    case "next_week":
      offMin = 7;
      offMax = 14;
      break;
    case "months":
      offMin = 0;
      offMax = 90;
      break;
  }

  // Safety: ensure offMin <= offMax
  if (offMin > offMax) offMin = 0;

  const prefStart = Number(rule.preferred_hour_start);
  const prefEnd = Number(rule.preferred_hour_end);
  const peak = Number(rule.preference_peak_hour);

  const wStart = new Date(now);
  wStart.setDate(wStart.getDate() + offMin);
  wStart.setHours(prefStart, 0, 0, 0);
  if (wStart < now) {
    wStart.setTime(now.getTime());
    wStart.setMinutes(0, 0, 0);
    wStart.setHours(wStart.getHours() + 1);
  }

  const wEnd = new Date(now);
  wEnd.setDate(wEnd.getDate() + offMax);
  wEnd.setHours(prefEnd, 0, 0, 0);

  // Build slot preferences
  const prefs = new Map<string, number>();
  for (let d = offMin; d <= offMax; d++) {
    const dayFactor = d === 0
      ? 1.0
      : d === 1
        ? 0.85
        : Math.max(0.3, 1.0 - d * 0.15);

    for (let h = prefStart; h <= prefEnd; h++) {
      const hourDist = Math.abs(h - peak);
      const hourFactor = Math.max(0.3, 1.0 - hourDist * 0.1);

      const slot = new Date(now);
      slot.setDate(slot.getDate() + d);
      slot.setHours(h, 0, 0, 0);

      if (slot > now) {
        prefs.set(slot.toISOString(), clamp01(dayFactor * hourFactor));
      }
    }
  }

  // Returning-user pattern override
  if (userId) {
    const { data: patterns } = await sb
      .from("user_booking_patterns")
      .select("*")
      .eq("user_id", userId)
      .eq("service_category", profile.category)
      .gte("confidence", 0.6)
      .limit(1);

    if (patterns?.length) {
      blendUserPattern(prefs, patterns[0], now, offMax);
    }
  }

  // Find highest-preference slot for primary_date/time
  let primarySlot = wStart.toISOString();
  let best = 0;
  for (const [k, v] of prefs) {
    if (v > best) {
      best = v;
      primarySlot = k;
    }
  }

  return {
    primary_date: primarySlot.split("T")[0],
    primary_time: new Date(primarySlot).toTimeString().slice(0, 5),
    window_start: wStart.toISOString(),
    window_end: wEnd.toISOString(),
    slot_preferences: prefs,
  };
}

function buildOverrideWindow(
  now: Date,
  ov: NonNullable<CurateRequest["override_window"]>,
  _profile: ServiceProfile,
): BookingWindow {
  const ws = new Date(now);
  const we = new Date(now);

  if (ov.specific_date) {
    const d = new Date(ov.specific_date);
    ws.setFullYear(d.getFullYear(), d.getMonth(), d.getDate());
    ws.setHours(8, 0, 0, 0);
    we.setFullYear(d.getFullYear(), d.getMonth(), d.getDate());
    we.setHours(20, 0, 0, 0);
  } else {
    switch (ov.range) {
      case "today":
        ws.setHours(now.getHours() + 1, 0, 0, 0);
        we.setHours(20, 0, 0, 0);
        break;
      case "tomorrow":
        ws.setDate(ws.getDate() + 1);
        ws.setHours(8, 0, 0, 0);
        we.setDate(we.getDate() + 1);
        we.setHours(20, 0, 0, 0);
        break;
      case "this_week":
        ws.setHours(8, 0, 0, 0);
        we.setDate(we.getDate() + (7 - now.getDay()));
        we.setHours(20, 0, 0, 0);
        break;
      case "next_week":
        ws.setDate(ws.getDate() + (7 - now.getDay() + 1));
        ws.setHours(8, 0, 0, 0);
        we.setTime(ws.getTime());
        we.setDate(we.getDate() + 5);
        we.setHours(20, 0, 0, 0);
        break;
    }
  }

  if (ov.time_of_day) {
    const ranges: Record<string, [number, number]> = {
      morning: [8, 12],
      afternoon: [12, 17],
      evening: [17, 21],
    };
    const [s, e] = ranges[ov.time_of_day] ?? [8, 20];
    ws.setHours(Math.max(ws.getHours(), s), 0, 0, 0);
    we.setHours(e, 0, 0, 0);
  }

  // Flat preferences for override windows
  const prefs = new Map<string, number>();
  const cursor = new Date(ws);
  while (cursor <= we) {
    prefs.set(cursor.toISOString(), 0.7);
    cursor.setHours(cursor.getHours() + 1);
  }

  return {
    primary_date: ws.toISOString().split("T")[0],
    primary_time: ws.toTimeString().slice(0, 5),
    window_start: ws.toISOString(),
    window_end: we.toISOString(),
    slot_preferences: prefs,
  };
}

function blendUserPattern(
  prefs: Map<string, number>,
  // deno-lint-ignore no-explicit-any
  pattern: any,
  now: Date,
  maxDays: number,
) {
  const factor = pattern.confidence >= 0.85 ? 0.8 : 0.4;

  for (let d = 0; d <= maxDays; d++) {
    const date = new Date(now);
    date.setDate(date.getDate() + d);

    if (
      pattern.preferred_day_of_week !== null &&
      date.getDay() === pattern.preferred_day_of_week
    ) {
      const h = pattern.preferred_hour ?? 11;
      const slot = new Date(date);
      slot.setHours(h, 0, 0, 0);
      const key = slot.toISOString();
      const existing = prefs.get(key) ?? 0.5;
      prefs.set(key, clamp01(existing * (1 - factor) + 1.0 * factor));
    }
  }
}

// =========================================================================
// STEP 3 — Candidate Query
// =========================================================================

async function queryCandidates(
  sb: SupabaseClient,
  serviceType: string,
  loc: { lat: number; lng: number },
  radiusM: number,
  window: BookingWindow,
  businessId?: string,
): Promise<Candidate[]> {
  const { data, error } = await sb.rpc("curate_candidates", {
    p_service_type: serviceType,
    p_lat: loc.lat,
    p_lng: loc.lng,
    p_radius_meters: Math.round(radiusM),
    p_window_start: window.window_start,
    p_window_end: window.window_end,
    p_business_id: businessId ?? null,
  });

  if (error) {
    console.error("curate_candidates RPC error:", error.message);
    return [];
  }
  return (data ?? []) as Candidate[];
}

// =========================================================================
// STEP 4 — Score & Rank
// =========================================================================

function normalizeInverse(value: number, best: number, worst: number): number {
  return clamp01((worst - value) / (worst - best));
}

function bayesianRating(
  R: number,
  v: number,
  C = 4.3,
  m = 10,
): number {
  return ((R * v + C * m) / (v + m)) / 5.0;
}

function normalizePriceToMedian(price: number, med: number): number {
  if (med === 0) return 0.5;
  const ratio = price / med;
  if (ratio <= 1.0) return 1.0;
  return Math.max(0, 1.0 - (ratio - 1.0) * 1.4);
}

function slotPreference(window: BookingWindow, slotISO: string): number {
  const t = new Date(slotISO).getTime();
  let bestPref = 0.5;
  let bestDist = Infinity;

  for (const [k, p] of window.slot_preferences) {
    const d = Math.abs(new Date(k).getTime() - t);
    if (d < bestDist) {
      bestDist = d;
      bestPref = p;
    }
  }

  // Decay if far from any preference anchor
  const hDist = bestDist / 3_600_000;
  if (hDist > 2) bestPref *= Math.max(0.3, 1.0 - (hDist - 2) * 0.1);

  return clamp01(bestPref);
}

// ---------------------------------------------------------------------------
// Google Distance Matrix API — batch transport time lookup
// ---------------------------------------------------------------------------

interface TransportData {
  mode: string;
  duration_min: number;
  distance_km: number;
  traffic_level: string;
  uber_estimate_min: number | null;
  uber_estimate_max: number | null;
  transit_summary: string | null;
  transit_stops: number | null;
}

const GOOGLE_API_KEY = Deno.env.get("GOOGLE_ROUTES_API_KEY") ?? "";

async function getTransportTimes(
  origin: { lat: number; lng: number },
  candidates: Candidate[],
  transportMode: string,
): Promise<Map<string, TransportData>> {
  // Deduplicate by business location (many candidates share a business)
  const bizLocations = new Map<
    string,
    { lat: number; lng: number; distM: number }
  >();
  for (const c of candidates) {
    if (!bizLocations.has(c.business_id)) {
      bizLocations.set(c.business_id, {
        lat: c.business_lat,
        lng: c.business_lng,
        distM: c.distance_m,
      });
    }
  }

  const bizIds = [...bizLocations.keys()];
  const bizLocs = [...bizLocations.values()];
  const result = new Map<string, TransportData>();

  // Google API mode mapping
  const gMode = transportMode === "transit" ? "transit" : "driving";

  // Chunk into batches of 25 (Distance Matrix limit per request)
  const CHUNK = 25;
  for (let i = 0; i < bizLocs.length; i += CHUNK) {
    const chunkIds = bizIds.slice(i, i + CHUNK);
    const chunkLocs = bizLocs.slice(i, i + CHUNK);

    const destinations = chunkLocs
      .map((l) => `${l.lat},${l.lng}`)
      .join("|");

    const params = new URLSearchParams({
      origins: `${origin.lat},${origin.lng}`,
      destinations,
      mode: gMode,
      departure_time: "now",
      language: "es",
      key: GOOGLE_API_KEY,
    });

    try {
      const resp = await fetch(
        `https://maps.googleapis.com/maps/api/distancematrix/json?${params}`,
      );

      if (!resp.ok) {
        console.error(
          `Google Distance Matrix HTTP ${resp.status}:`,
          await resp.text(),
        );
        // Fall back to distance estimates for this chunk
        for (let j = 0; j < chunkIds.length; j++) {
          result.set(chunkIds[j], fallbackTransport(chunkLocs[j].distM, transportMode));
        }
        continue;
      }

      const data = await resp.json();

      if (data.status !== "OK" || !data.rows?.[0]?.elements) {
        console.error("Google Distance Matrix error:", data.status, data.error_message);
        for (let j = 0; j < chunkIds.length; j++) {
          result.set(chunkIds[j], fallbackTransport(chunkLocs[j].distM, transportMode));
        }
        continue;
      }

      const elements = data.rows[0].elements;
      for (let j = 0; j < chunkIds.length; j++) {
        const el = elements[j];
        if (el.status !== "OK") {
          result.set(chunkIds[j], fallbackTransport(chunkLocs[j].distM, transportMode));
          continue;
        }

        const durSec = el.duration_in_traffic?.value ?? el.duration?.value ?? 0;
        const baseDurSec = el.duration?.value ?? durSec;
        const distM = el.distance?.value ?? chunkLocs[j].distM;
        const durMin = Math.round(durSec / 60);
        const distKm = Math.round(distM / 100) / 10;

        // Traffic level from ratio of traffic-aware vs base duration
        const ratio = baseDurSec > 0 ? durSec / baseDurSec : 1;
        const trafficLevel =
          ratio < 1.2 ? "light" : ratio < 1.5 ? "moderate" : "heavy";

        result.set(chunkIds[j], {
          mode: transportMode,
          duration_min: Math.max(1, durMin),
          distance_km: distKm,
          traffic_level: trafficLevel,
          uber_estimate_min: null,
          uber_estimate_max: null,
          transit_summary: null,
          transit_stops: null,
        });
      }
    } catch (err) {
      console.error("Google Distance Matrix fetch error:", err);
      for (let j = 0; j < chunkIds.length; j++) {
        result.set(chunkIds[j], fallbackTransport(chunkLocs[j].distM, transportMode));
      }
    }
  }

  return result;
}

function fallbackTransport(distM: number, mode: string): TransportData {
  const distKm = distM / 1000;
  const speed = mode === "transit" ? 15 : 30;
  const durMin = Math.max(1, Math.round((distKm / speed) * 60));
  return {
    mode,
    duration_min: durMin,
    distance_km: Math.round(distKm * 10) / 10,
    traffic_level: durMin < 10 ? "light" : durMin < 25 ? "moderate" : "heavy",
    uber_estimate_min: null,
    uber_estimate_max: null,
    transit_summary: null,
    transit_stops: null,
  };
}

// ---------------------------------------------------------------------------
// Score & Rank
// ---------------------------------------------------------------------------

async function scoreCandidates(
  candidates: Candidate[],
  profile: ServiceProfile,
  window: BookingWindow,
  transportMode: string,
  userLocation: { lat: number; lng: number },
): Promise<ScoredCandidate[]> {
  // Weights from profile
  let wP = Number(profile.weight_proximity);
  let wA = Number(profile.weight_availability);
  let wR = Number(profile.weight_rating);
  const wPr = Number(profile.weight_price);
  const wPo = Number(profile.weight_portfolio);

  // Uber mode: reduce proximity, boost rating + availability
  if (transportMode === "uber") {
    const reduction = wP * 0.30;
    wP -= reduction;
    wR += reduction * 0.6;
    wA += reduction * 0.4;
  }

  const prices = candidates
    .map((c) => Number(c.effective_price))
    .filter((p) => p > 0);
  const areaMedian = median(prices);

  // Batch transport time lookup via Google Distance Matrix API
  let transportMap: Map<string, TransportData>;
  if (GOOGLE_API_KEY) {
    transportMap = await getTransportTimes(
      userLocation,
      candidates,
      transportMode,
    );
  } else {
    // No API key — use distance-based fallback for all
    transportMap = new Map();
    for (const c of candidates) {
      if (!transportMap.has(c.business_id)) {
        transportMap.set(
          c.business_id,
          fallbackTransport(c.distance_m, transportMode),
        );
      }
    }
  }

  return candidates.map((c) => {
    const transport = transportMap.get(c.business_id) ??
      fallbackTransport(c.distance_m, transportMode);

    const proximityScore = normalizeInverse(transport.duration_min, 5, 45);
    const availabilityScore = slotPreference(window, c.slot_start);
    const ratingScore = bayesianRating(
      Number(c.staff_rating),
      Number(c.staff_reviews),
    );
    const priceScore = normalizePriceToMedian(
      Number(c.effective_price),
      areaMedian,
    );
    const portfolioScore = 0.5; // neutral until portfolio data exists

    const score =
      proximityScore * wP +
      availabilityScore * wA +
      ratingScore * wR +
      priceScore * wPr +
      portfolioScore * wPo;

    return {
      ...c,
      score,
      transport,
      area_avg_price: areaMedian,
      breakdown: {
        proximity: proximityScore * wP,
        availability: availabilityScore * wA,
        rating: ratingScore * wR,
        price: priceScore * wPr,
        portfolio: portfolioScore * wPo,
      },
    };
  });
}

// =========================================================================
// STEP 5 — Pick Top 3
// =========================================================================

function pickTop3(scored: ScoredCandidate[]): ScoredCandidate[] {
  scored.sort((a, b) => b.score - a.score);

  // Deduplicate: one result per business (keep highest-scoring staff)
  const seen = new Set<string>();
  const deduped: ScoredCandidate[] = [];
  for (const c of scored) {
    if (!seen.has(c.business_id)) {
      seen.add(c.business_id);
      deduped.push(c);
    }
  }

  return deduped.slice(0, 3);
}

// =========================================================================
// STEP 6 — Build Response
// =========================================================================

async function buildResponse(
  sb: SupabaseClient,
  top3: ScoredCandidate[],
  profile: ServiceProfile,
  serviceType: string,
) {
  if (top3.length === 0) return [];

  const bizIds = top3.map((c) => c.business_id);
  const category: string = profile.category ?? "";

  // --- Snippet selection using review_tags for quality scoring ---
  // Query 1: Best snippet per business for this exact service_type
  const { data: taggedReviews } = await sb
    .from("review_tags")
    .select(
      "review_id, snippet_quality_score, reviews!inner(id, business_id, rating, comment, created_at, user_id, service_type, is_visible)",
    )
    .in("reviews.business_id", bizIds)
    .eq("reviews.is_visible", true)
    .eq("reviews.service_type", serviceType)
    .order("snippet_quality_score", { ascending: false })
    .limit(top3.length * 3);

  // Index: best tagged review per business (service-type match)
  // deno-lint-ignore no-explicit-any
  const snippetByBiz = new Map<string, any>();
  for (const t of taggedReviews ?? []) {
    // deno-lint-ignore no-explicit-any
    const r = (t as any).reviews;
    if (r && !snippetByBiz.has(r.business_id)) {
      snippetByBiz.set(r.business_id, {
        ...r,
        snippet_quality_score: t.snippet_quality_score,
      });
    }
  }

  // Query 2: Fallback — any review for businesses missing a service-type match
  const missingBizIds = bizIds.filter((id) => !snippetByBiz.has(id));
  if (missingBizIds.length > 0) {
    // Try review_tags first (any service type for this business)
    const { data: fallbackTagged } = await sb
      .from("review_tags")
      .select(
        "review_id, snippet_quality_score, reviews!inner(id, business_id, rating, comment, created_at, user_id, service_type, is_visible)",
      )
      .in("reviews.business_id", missingBizIds)
      .eq("reviews.is_visible", true)
      .order("snippet_quality_score", { ascending: false })
      .limit(missingBizIds.length * 2);

    for (const t of fallbackTagged ?? []) {
      // deno-lint-ignore no-explicit-any
      const r = (t as any).reviews;
      if (r && !snippetByBiz.has(r.business_id)) {
        snippetByBiz.set(r.business_id, {
          ...r,
          snippet_quality_score: t.snippet_quality_score,
          is_category_fallback: true,
        });
      }
    }

    // If still missing, try untagged reviews (reviews not yet processed by tag-review)
    const stillMissing = missingBizIds.filter((id) => !snippetByBiz.has(id));
    if (stillMissing.length > 0) {
      const { data: untRev } = await sb
        .from("reviews")
        .select("id, business_id, rating, comment, created_at, user_id")
        .in("business_id", stillMissing)
        .eq("is_visible", true)
        .order("rating", { ascending: false })
        .order("created_at", { ascending: false })
        .limit(stillMissing.length * 2);

      for (const r of untRev ?? []) {
        if (!snippetByBiz.has(r.business_id)) {
          snippetByBiz.set(r.business_id, {
            ...r,
            snippet_quality_score: null,
            is_category_fallback: true,
          });
        }
      }
    }
  }

  // Fetch reviewer display names
  const reviewerIds = [...snippetByBiz.values()]
    .map((r) => r.user_id)
    .filter(Boolean);
  const { data: reviewers } =
    reviewerIds.length > 0
      ? await sb
          .from("profiles")
          .select("id, full_name, username")
          .in("id", reviewerIds)
      : { data: [] };
  const nameMap = new Map<string, string>();
  for (const p of reviewers ?? []) {
    nameMap.set(p.id, p.full_name || p.username);
  }

  // Category display name for fallback text
  const categoryNames: Record<string, string> = {
    unas: "Unas",
    cabello: "Cabello",
    pestanas: "Pestanas",
    cejas: "Cejas",
    maquillaje: "Maquillaje",
    facial: "Facial",
    corporal: "Corporal",
    depilacion: "Depilacion",
    barberia: "Barberia",
  };

  return top3.map((c, i) => {
    const review = snippetByBiz.get(c.business_id);
    const daysAgo = review
      ? Math.floor(
          (Date.now() - new Date(review.created_at).getTime()) / 86_400_000,
        )
      : 0;

    // Badges
    const badges: string[] = [];
    if (
      profile.typical_lead_time === "same_day" &&
      isToday(c.slot_start)
    ) {
      badges.push("available_today");
    }
    if (c.accept_walkins && Number(profile.availability_level) > 0.7) {
      badges.push("walk_in_ok");
    }
    if (Number(c.business_reviews) < 5) badges.push("new_on_platform");
    if (c.auto_confirm) badges.push("instant_confirm");

    // Build snippet with fallback logic
    let reviewSnippet;
    if (review) {
      const isFallback = review.is_category_fallback === true;
      reviewSnippet = {
        text: isFallback
          ? `Recomendado en ${categoryNames[category] ?? category}`
          : (review.comment ?? ""),
        author_name: nameMap.get(review.user_id) ?? "Cliente",
        days_ago: daysAgo,
        rating: review.rating,
        quality_score: review.snippet_quality_score ?? null,
      };
    } else {
      // No reviews at all for this business
      reviewSnippet = {
        text: "Nuevo en BeautyCita",
        author_name: null,
        days_ago: null,
        rating: null,
        quality_score: null,
      };
    }

    return {
      rank: i + 1,
      score: Math.round(c.score * 1000) / 1000,
      business: {
        id: c.business_id,
        name: c.business_name,
        photo_url: c.business_photo,
        address: c.business_address,
        lat: c.business_lat,
        lng: c.business_lng,
        whatsapp: c.business_whatsapp,
      },
      staff: {
        id: c.staff_id,
        name: c.staff_name,
        avatar_url: c.staff_avatar,
        experience_years: c.experience_years,
        rating: Number(c.staff_rating),
        total_reviews: Number(c.staff_reviews),
      },
      service: {
        id: c.service_id,
        name: c.service_name,
        price: Number(c.effective_price),
        duration_minutes: Number(c.effective_duration),
        currency: "MXN",
      },
      slot: {
        starts_at: c.slot_start,
        ends_at: c.slot_end,
      },
      transport: c.transport,
      review_snippet: reviewSnippet,
      badges,
      area_avg_price: c.area_avg_price,
      scoring_breakdown: c.breakdown,
    };
  });
}

// =========================================================================
// Time Inference Correction Logging
// =========================================================================

async function logTimeCorrection(
  sb: SupabaseClient,
  profile: ServiceProfile,
  userId: string | null,
  override: NonNullable<CurateRequest["override_window"]>,
  serviceType: string,
) {
  // Compute what the original (non-override) window would have been
  const originalWindow = await inferWindow(sb, profile, userId, null);

  // Classify original window into hour range
  const origStart = new Date(originalWindow.window_start);
  const origEnd = new Date(originalWindow.window_end);
  const origHourRange = `${origStart.getHours()}-${origEnd.getHours()}`;

  // Classify original day range
  const now = new Date();
  const origDayStart = Math.max(
    0,
    Math.round(
      (origStart.getTime() - now.getTime()) / 86_400_000,
    ),
  );
  const origDayEnd = Math.max(
    0,
    Math.round(
      (origEnd.getTime() - now.getTime()) / 86_400_000,
    ),
  );
  const origDayRange = `+${origDayStart}-${origDayEnd}d`;

  // Build correction description
  const corrParts: string[] = [];
  if (override.range) corrParts.push(override.range);
  if (override.time_of_day) corrParts.push(override.time_of_day);
  if (override.specific_date) corrParts.push(override.specific_date);
  const correctionTo = corrParts.join("|") || "custom";

  // Upsert: atomically increment correction_count via RPC
  const { error } = await sb.rpc("increment_time_correction", {
    p_service_type: serviceType,
    p_original_hour_range: origHourRange,
    p_original_day_range: origDayRange,
    p_correction_to: correctionTo,
  });

  if (error) {
    console.error("Failed to log time correction:", error);
  }
}
