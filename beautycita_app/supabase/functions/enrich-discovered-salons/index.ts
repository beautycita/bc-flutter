// =============================================================================
// enrich-discovered-salons — Reverse geocode + dedup pipeline
// =============================================================================
// Called by admin (BC) to clean up discovered salon data:
// 1. Reverse geocode: normalize address/city/state from lat/lng via Google
// 2. Dedup: merge salons within 50m with similar names
// 3. Category inference: tag service_categories from business name keywords
//
// Processes in batches to stay within API limits and Edge Function timeout.
// Call repeatedly until response.remaining === 0.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GOOGLE_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

let _req: Request;

// ── Category inference from business name ────────────────────────────────────
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  nails: ["nail", "uñas", "una", "manicure", "pedicure", "nails"],
  hair: ["cabello", "pelo", "corte", "color", "tinte", "peluquer", "hair", "salon de belleza", "estilista", "stylist", "blow", "keratina"],
  lashes_brows: ["pestañ", "ceja", "lash", "brow", "microblading"],
  makeup: ["maquillaje", "makeup", "mua"],
  facial: ["facial", "skincare", "piel", "derma", "acne", "limpieza facial"],
  body_spa: ["spa", "masaje", "massage", "body", "relax", "sauna", "jacuzzi", "depilac"],
  barberia: ["barber", "barberia", "barbería", "barba", "fade"],
  specialized: ["tattoo", "tatuaje", "piercing", "laser", "botox"],
};

function inferCategories(name: string): string[] {
  const lower = name.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  const matched: string[] = [];
  for (const [cat, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    if (keywords.some((kw) => lower.includes(kw))) {
      matched.push(cat);
    }
  }
  return matched;
}

// ── Reverse geocode via Google ────────────────────────────────────────────────
interface GeoResult {
  address: string;
  city: string;
  state: string;
  zip: string;
}

async function reverseGeocode(lat: number, lng: number): Promise<GeoResult | null> {
  if (!GOOGLE_API_KEY) return null;

  const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&language=es&key=${GOOGLE_API_KEY}`;
  const resp = await fetch(url);
  const data = await resp.json();

  if (data.status !== "OK" || !data.results?.length) return null;

  const components = data.results[0].address_components ?? [];
  let street = "", number = "", city = "", state = "", zip = "";

  for (const c of components) {
    const types = c.types ?? [];
    if (types.includes("street_number")) number = c.long_name;
    if (types.includes("route")) street = c.long_name;
    if (types.includes("locality")) city = c.long_name;
    if (types.includes("administrative_area_level_1")) state = c.long_name;
    if (types.includes("postal_code")) zip = c.long_name;
  }

  // Fallback: use sublocality for city if locality is missing
  if (!city) {
    for (const c of components) {
      if (c.types?.includes("sublocality_level_1") || c.types?.includes("sublocality")) {
        city = c.long_name;
        break;
      }
    }
  }

  const address = [street, number].filter(Boolean).join(" ").trim();

  return { address: address || data.results[0].formatted_address, city, state, zip };
}

// ── Dedup: find clusters within 50m with similar names ───────────────────────
function normalizeForDedup(name: string): string {
  return name
    .toLowerCase()
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s]/g, "")
    .replace(/\b(salon|de|belleza|estetica|spa|la|el|los|las|y|e)\b/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function levenshtein(a: string, b: string): number {
  const m = a.length, n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;
  const d: number[][] = Array.from({ length: m + 1 }, () => Array(n + 1).fill(0));
  for (let i = 0; i <= m; i++) d[i][0] = i;
  for (let j = 0; j <= n; j++) d[0][j] = j;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      d[i][j] = Math.min(
        d[i - 1][j] + 1, d[i][j - 1] + 1,
        d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
  }
  return d[m][n];
}

// ── Main handler ─────────────────────────────────────────────────────────────
serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": corsOrigin(req), "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" } });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Admin-only
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  const { data: { user } } = await supabase.auth.getUser(token);
  if (!user) return json({ error: "Unauthorized" }, 401);

  const { data: profile } = await supabase
    .from("profiles").select("role").eq("id", user.id).single();
  if (profile?.role !== "admin") return json({ error: "Admin only" }, 403);

  const params = await req.json().catch(() => ({}));
  const action = params.action ?? "geocode";
  const batchSize = Math.min(params.batch_size ?? 50, 100);

  // ── ACTION: geocode — reverse geocode salons with dirty/missing addresses ──
  if (action === "geocode") {
    // Find MX salons that haven't been geocode-enriched yet
    const { data: salons, error } = await supabase
      .from("discovered_salons")
      .select("id, latitude, longitude, location_address, location_city, location_state, location_zip")
      .eq("country", "MX")
      .is("enriched_at", null)
      .not("latitude", "is", null)
      .order("id")
      .limit(batchSize);

    if (error) return json({ error: error.message }, 500);
    if (!salons?.length) return json({ action: "geocode", processed: 0, remaining: 0 });

    let updated = 0;
    for (const salon of salons) {
      const geo = await reverseGeocode(salon.latitude, salon.longitude);
      if (geo) {
        await supabase.from("discovered_salons").update({
          location_address: geo.address || salon.location_address,
          location_city: geo.city || salon.location_city,
          location_state: geo.state || salon.location_state,
          location_zip: geo.zip || salon.location_zip,
          enriched_at: new Date().toISOString(),
        }).eq("id", salon.id);
        updated++;
      } else {
        // Mark as enriched even if geocode failed (don't retry forever)
        await supabase.from("discovered_salons").update({
          enriched_at: new Date().toISOString(),
        }).eq("id", salon.id);
      }
      // Rate limit: Google Geocoding allows 50 QPS
      await new Promise((r) => setTimeout(r, 25));
    }

    // Count remaining
    const { count } = await supabase
      .from("discovered_salons")
      .select("id", { count: "exact", head: true })
      .eq("country", "MX")
      .is("enriched_at", null);

    return json({ action: "geocode", processed: updated, remaining: count ?? 0 });
  }

  // ── ACTION: dedup — merge duplicate salons within 50m + similar names ───────
  if (action === "dedup") {
    // Find clusters using PostGIS
    const { data: clusters, error } = await supabase.rpc("find_duplicate_salons", {
      p_distance_meters: 50,
      p_limit: batchSize,
    });

    if (error) {
      // RPC might not exist yet — create it inline
      if (error.message.includes("find_duplicate_salons")) {
        await supabase.rpc("exec_sql", {
          sql: `
            CREATE OR REPLACE FUNCTION find_duplicate_salons(
              p_distance_meters double precision DEFAULT 50,
              p_limit integer DEFAULT 50
            ) RETURNS TABLE(id1 uuid, id2 uuid, name1 text, name2 text, distance_m double precision)
            LANGUAGE sql STABLE AS $$
              SELECT a.id as id1, b.id as id2,
                     a.business_name as name1, b.business_name as name2,
                     ST_Distance(a.location, b.location) as distance_m
              FROM discovered_salons a
              JOIN discovered_salons b ON a.id < b.id
                AND ST_DWithin(a.location, b.location, p_distance_meters)
              WHERE a.country = 'MX' AND b.country = 'MX'
                AND a.status NOT IN ('duplicate', 'registered')
                AND b.status NOT IN ('duplicate', 'registered')
              ORDER BY a.id
              LIMIT p_limit;
            $$;
          `,
        });
        return json({ action: "dedup", error: "RPC created — retry" });
      }
      return json({ error: error.message }, 500);
    }

    if (!clusters?.length) return json({ action: "dedup", merged: 0, remaining: 0 });

    let merged = 0;
    for (const pair of clusters) {
      const normA = normalizeForDedup(pair.name1);
      const normB = normalizeForDedup(pair.name2);
      const dist = levenshtein(normA, normB);
      const maxLen = Math.max(normA.length, normB.length);

      // Only merge if names are very similar (< 30% edit distance)
      if (maxLen > 0 && dist / maxLen < 0.3) {
        // Keep the one with more data (rating, phone, image)
        const { data: s1 } = await supabase.from("discovered_salons").select("*").eq("id", pair.id1).single();
        const { data: s2 } = await supabase.from("discovered_salons").select("*").eq("id", pair.id2).single();
        if (!s1 || !s2) continue;

        const score1 = (s1.phone ? 1 : 0) + (s1.feature_image_url ? 1 : 0) + (s1.rating_count ?? 0);
        const score2 = (s2.phone ? 1 : 0) + (s2.feature_image_url ? 1 : 0) + (s2.rating_count ?? 0);

        const [keep, discard] = score1 >= score2 ? [s1, s2] : [s2, s1];

        // Merge missing fields from discard into keep
        const updates: Record<string, unknown> = {};
        if (!keep.phone && discard.phone) updates.phone = discard.phone;
        if (!keep.whatsapp && discard.whatsapp) updates.whatsapp = discard.whatsapp;
        if (!keep.feature_image_url && discard.feature_image_url) updates.feature_image_url = discard.feature_image_url;
        if ((keep.rating_count ?? 0) < (discard.rating_count ?? 0)) {
          updates.rating_average = discard.rating_average;
          updates.rating_count = discard.rating_count;
        }

        if (Object.keys(updates).length > 0) {
          await supabase.from("discovered_salons").update(updates).eq("id", keep.id);
        }

        // Mark discard as duplicate
        await supabase.from("discovered_salons").update({
          status: "duplicate",
          duplicate_of: keep.id,
        }).eq("id", discard.id);

        merged++;
      }
    }

    return json({ action: "dedup", merged, checked: clusters.length });
  }

  // ── ACTION: categorize — infer service categories from business name ────────
  if (action === "categorize") {
    const { data: salons, error } = await supabase
      .from("discovered_salons")
      .select("id, business_name, categories")
      .eq("country", "MX")
      .or("categories.is.null,categories.eq.{}")
      .order("id")
      .limit(batchSize);

    if (error) return json({ error: error.message }, 500);
    if (!salons?.length) return json({ action: "categorize", processed: 0, remaining: 0 });

    let updated = 0;
    for (const salon of salons) {
      const cats = inferCategories(salon.business_name);
      if (cats.length > 0) {
        await supabase.from("discovered_salons").update({
          categories: cats,
        }).eq("id", salon.id);
        updated++;
      } else {
        // Mark with empty array so we don't re-process
        await supabase.from("discovered_salons").update({
          categories: ["uncategorized"],
        }).eq("id", salon.id);
      }
    }

    const { count } = await supabase
      .from("discovered_salons")
      .select("id", { count: "exact", head: true })
      .eq("country", "MX")
      .or("categories.is.null,categories.eq.{}");

    return json({ action: "categorize", processed: updated, remaining: count ?? 0 });
  }

  return json({ error: "Unknown action. Use: geocode, dedup, categorize" }, 400);
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Access-Control-Allow-Origin": corsOrigin(_req),
      "Content-Type": "application/json",
    },
  });
}
