// outreach-discovered-salon/index.ts
// Actions:
//   list     — return nearby discovered salons (not yet on BeautyCita)
//   invite   — record interest signal + evaluate outreach rules
//   import   — bulk upsert discovered salons from CSV/JSON payload (admin only)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Outreach thresholds: send platform message at these interest counts
const OUTREACH_THRESHOLDS = [1, 3, 5, 10, 20];
const OUTREACH_INTERVAL_AFTER_20 = 10;
const MIN_OUTREACH_INTERVAL_HOURS = 48;
const MAX_OUTREACH_ATTEMPTS = 10;

// Escalating outreach messages (Spanish)
const OUTREACH_MESSAGES: Record<number, string> = {
  1: "Hola {{name}}! Una clienta quiere reservar contigo en BeautyCita. Regístrate gratis en 60 seg: {{link}}",
  3: "{{name}}, 3 clientas te buscan en BeautyCita. No pierdas reservas. Regístrate gratis: {{link}}",
  5: "{{name}}, 5 personas intentaron reservar contigo esta semana. BeautyCita te conecta con ellas, gratis: {{link}}",
  10: "{{name}}, 10 clientas te buscan. Estás perdiendo reservas cada semana. 60 seg y listo: {{link}}",
  20: "{{name}}, 20 clientas y contando. Los salones registrados reciben su primera reserva en promedio en 48 hrs: {{link}}",
};

function getOutreachMessage(count: number, name: string, link: string): string {
  // Find the highest threshold <= count
  let templateCount = 1;
  for (const t of OUTREACH_THRESHOLDS) {
    if (count >= t) templateCount = t;
  }
  const template = OUTREACH_MESSAGES[templateCount] ?? OUTREACH_MESSAGES[1];
  return template.replace("{{name}}", name).replace("{{link}}", link);
}

function shouldSendOutreach(interestCount: number): boolean {
  if (OUTREACH_THRESHOLDS.includes(interestCount)) return true;
  if (interestCount > 20 && (interestCount - 20) % OUTREACH_INTERVAL_AFTER_20 === 0) return true;
  return false;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type, apikey",
      },
    });
  }

  try {
    const { action, ...params } = await req.json();

    // Auth: get user from JWT
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");

    // Service client for admin operations
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // ───────── LIST: nearby discovered salons ─────────
    if (action === "list") {
      const { lat, lng, radius_km = 50, limit = 20, service_query } = params;
      if (!lat || !lng) {
        return jsonResponse({ error: "lat and lng required" }, 400);
      }

      // Build service keywords for filtering
      const serviceKeywords = service_query
        ? buildServiceKeywords(service_query)
        : null;

      // Fetch a large candidate pool to rank from
      const candidatePool = 500;

      // Use PostGIS to find nearby discovered salons not yet registered
      const { data, error } = await serviceClient.rpc("nearby_discovered_salons", {
        user_lat: lat,
        user_lng: lng,
        radius_km: radius_km,
        max_results: candidatePool,
      });

      let results: any[];

      if (error) {
        // Fallback: plain query without PostGIS function
        const { data: fallback, error: fallbackErr } = await serviceClient
          .from("discovered_salons")
          .select("id, business_name, phone, whatsapp, location_address, location_city, latitude, longitude, feature_image_url, rating_average, rating_count, interest_count, categories, specialties, status, created_at")
          .in("status", ["discovered", "selected", "outreach_sent"])
          .not("latitude", "is", null)
          .limit(candidatePool);

        if (fallbackErr) {
          return jsonResponse({ error: fallbackErr.message }, 500);
        }

        // Client-side distance filtering
        results = (fallback ?? [])
          .map((s: any) => ({
            ...s,
            distance_km: haversineKm(lat, lng, s.latitude, s.longitude),
          }))
          .filter((s: any) => s.distance_km <= radius_km);
      } else {
        results = (data ?? []).map((s: any) => ({
          ...s,
          distance_km: s.distance_km ?? haversineKm(lat, lng, s.latitude, s.longitude),
        }));
      }

      // Apply service-type filtering if query provided
      if (serviceKeywords && serviceKeywords.length > 0) {
        results = results.filter((s: any) => matchesService(s, serviceKeywords));
      }

      // Quality-weighted ranking: best salons first, not just closest
      results.sort((a: any, b: any) => {
        const scoreA = qualityScore(a, serviceKeywords);
        const scoreB = qualityScore(b, serviceKeywords);
        return scoreB - scoreA;
      });

      // Apply limit
      results = results.slice(0, limit);

      return jsonResponse({ salons: results, count: results.length });
    }

    // ───────── INVITE: record interest + evaluate outreach ─────────
    if (action === "invite") {
      // Verify user auth
      const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: `Bearer ${token}` } },
      });
      const { data: { user }, error: authError } = await userClient.auth.getUser();
      if (authError || !user) {
        return jsonResponse({ error: "Unauthorized" }, 401);
      }

      const { discovered_salon_id } = params;
      if (!discovered_salon_id) {
        return jsonResponse({ error: "discovered_salon_id required" }, 400);
      }

      // 1. Upsert interest signal (unique per user+salon)
      const { error: signalError } = await serviceClient
        .from("salon_interest_signals")
        .upsert(
          { discovered_salon_id, user_id: user.id },
          { onConflict: "discovered_salon_id,user_id" }
        );

      if (signalError) {
        return jsonResponse({ error: signalError.message }, 500);
      }

      // 2. Count unique signals for this salon
      const { count } = await serviceClient
        .from("salon_interest_signals")
        .select("id", { count: "exact", head: true })
        .eq("discovered_salon_id", discovered_salon_id);

      const interestCount = count ?? 1;

      // 3. Update discovered_salons record
      const now = new Date().toISOString();
      await serviceClient
        .from("discovered_salons")
        .update({
          interest_count: interestCount,
          status: "selected",
          first_selected_at: serviceClient.rpc ? undefined : now, // handled below
          last_selected_at: now,
        })
        .eq("id", discovered_salon_id);

      // Set first_selected_at only if null
      await serviceClient
        .from("discovered_salons")
        .update({ first_selected_at: now })
        .eq("id", discovered_salon_id)
        .is("first_selected_at", null);

      // 4. Evaluate outreach rules
      let outreachSent = false;
      if (shouldSendOutreach(interestCount)) {
        // Fetch salon details
        const { data: salon } = await serviceClient
          .from("discovered_salons")
          .select("*")
          .eq("id", discovered_salon_id)
          .single();

        if (salon && canSendOutreach(salon)) {
          // Queue outreach (in production, this would call Twilio)
          const registrationLink = `https://beautycita.com/salon/${discovered_salon_id}`;
          const message = getOutreachMessage(interestCount, salon.business_name, registrationLink);

          // Update outreach tracking
          await serviceClient
            .from("discovered_salons")
            .update({
              status: "outreach_sent",
              last_outreach_at: now,
              outreach_count: (salon.outreach_count ?? 0) + 1,
              outreach_channel: salon.whatsapp ? "whatsapp" : (salon.phone ? "sms" : "email"),
            })
            .eq("id", discovered_salon_id);

          outreachSent = true;

          // Log the outreach message (would be sent via Twilio in production)
          console.log(`[OUTREACH] Salon: ${salon.business_name}, Count: ${interestCount}, Channel: ${salon.whatsapp ? 'whatsapp' : 'sms'}, Message: ${message}`);
        }
      }

      return jsonResponse({
        recorded: true,
        interest_count: interestCount,
        outreach_sent: outreachSent,
      });
    }

    // ───────── IMPORT: bulk upsert discovered salons (admin) ─────────
    if (action === "import") {
      // Verify admin role
      const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: `Bearer ${token}` } },
      });
      const { data: { user }, error: authError } = await userClient.auth.getUser();
      if (authError || !user) {
        return jsonResponse({ error: "Unauthorized" }, 401);
      }

      const { data: profile } = await serviceClient
        .from("profiles")
        .select("role")
        .eq("id", user.id)
        .single();

      if (profile?.role !== "admin") {
        return jsonResponse({ error: "Admin access required" }, 403);
      }

      const { salons } = params;
      if (!Array.isArray(salons) || salons.length === 0) {
        return jsonResponse({ error: "salons array required" }, 400);
      }

      let imported = 0;
      let skipped = 0;
      const errors: string[] = [];

      for (const salon of salons) {
        // Validate required fields
        if (!salon.business_name || !salon.location_city || !salon.location_state || !salon.source) {
          skipped++;
          errors.push(`Missing required fields: ${salon.business_name ?? "unnamed"}`);
          continue;
        }

        const record = {
          source: salon.source,
          source_id: salon.source_id ?? null,
          business_name: salon.business_name,
          slug: salon.slug ?? null,
          bio: salon.bio ?? null,
          phone: salon.phone ?? null,
          phone_raw: salon.phone_raw ?? null,
          whatsapp: salon.whatsapp ?? salon.phone ?? null,
          email: salon.email ?? null,
          location_address: salon.location_address ?? null,
          location_city: salon.location_city,
          location_state: salon.location_state,
          location_zip: salon.location_zip ?? null,
          country: salon.country ?? "MX",
          latitude: salon.latitude ?? null,
          longitude: salon.longitude ?? null,
          feature_image_url: salon.feature_image_url ?? null,
          rating_average: salon.rating_average ?? null,
          rating_count: salon.rating_count ?? null,
          categories: salon.categories ?? null,
          specialties: salon.specialties ?? null,
          working_hours: salon.working_hours ?? null,
          website: salon.website ?? null,
          facebook_url: salon.facebook_url ?? null,
          instagram_url: salon.instagram_url ?? null,
          portfolio_images: salon.portfolio_images ?? null,
          scraped_at: salon.scraped_at ?? new Date().toISOString(),
        };

        const { error: upsertError } = await serviceClient
          .from("discovered_salons")
          .upsert(record, { onConflict: "source,source_id" });

        if (upsertError) {
          skipped++;
          errors.push(`${salon.business_name}: ${upsertError.message}`);
        } else {
          imported++;
        }
      }

      return jsonResponse({ imported, skipped, errors: errors.slice(0, 10) });
    }

    return jsonResponse({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});

// Quality-weighted ranking score.
// Factors: rating, review count (proxy for client volume), interest signals,
// longevity (time since first scraped), and proximity.
// Proximity matters but doesn't dominate — a 4.9-star salon 8km away
// ranks above a 3.5-star salon 2km away.
function qualityScore(salon: any, serviceKeywords: string[] | null): number {
  let score = 0;

  // Rating (0-5) — normalized to 0-30 points, heavily weighted
  const rating = salon.rating_average ?? 0;
  score += (rating / 5) * 30;

  // Review count — logarithmic scale, proxy for client volume
  // 1 review = 0, 10 = 6.9, 50 = 11.7, 200 = 15.9, 1000 = 20.7
  const reviews = salon.rating_count ?? 0;
  score += reviews > 0 ? Math.log(reviews + 1) * 3 : 0;

  // Interest signals from BeautyCita users (0-10 points)
  const interest = salon.interest_count ?? 0;
  score += Math.min(interest * 2, 10);

  // Proximity — inverse distance, max 20 points
  // 0 km = 20, 5 km = 15, 10 km = 10, 25 km = 5, 50+ km = 0
  const dist = salon.distance_km ?? 50;
  score += Math.max(0, 20 - (dist * 0.4));

  // Service keyword match bonus (0-10 points)
  if (serviceKeywords && serviceKeywords.length > 0) {
    score += serviceMatchScore(salon, serviceKeywords) * 2;
  }

  // Data completeness bonus (0-5 points) — salons with more info rank higher
  if (salon.feature_image_url) score += 1;
  if (salon.location_address) score += 1;
  if (salon.working_hours) score += 1;
  if (salon.website || salon.facebook_url || salon.instagram_url) score += 1;
  if (salon.specialties && Array.isArray(salon.specialties) && salon.specialties.length > 0) score += 1;

  return score;
}

function canSendOutreach(salon: any): boolean {
  // Don't send if declined or unreachable
  if (salon.status === "declined" || salon.status === "unreachable") return false;
  // Don't send if already registered
  if (salon.status === "registered") return false;
  // Don't send if exceeded max attempts
  if ((salon.outreach_count ?? 0) >= MAX_OUTREACH_ATTEMPTS) return false;
  // Don't send if sent within interval
  if (salon.last_outreach_at) {
    const hoursSince =
      (Date.now() - new Date(salon.last_outreach_at).getTime()) / (1000 * 60 * 60);
    if (hoursSince < MIN_OUTREACH_INTERVAL_HOURS) return false;
  }
  // Need at least a phone or whatsapp
  if (!salon.phone && !salon.whatsapp) return false;
  return true;
}

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Service-type keyword mapping for better matching
const SERVICE_KEYWORD_MAP: Record<string, string[]> = {
  // Lashes
  "ext_pestanas": ["pestana", "lash", "extension", "eyelash"],
  "pestanas": ["pestana", "lash", "extension", "eyelash"],
  // Nails
  "manicure": ["manicure", "nail", "uña", "una", "gel", "acrilico"],
  "pedicure": ["pedicure", "nail", "uña", "una", "pie"],
  "unas": ["uña", "una", "nail", "acrilico", "gel"],
  // Hair
  "corte": ["corte", "cabello", "hair", "pelo", "salon", "estilista", "peluqueria", "barberia"],
  "tinte": ["tinte", "color", "cabello", "hair", "salon", "estilista"],
  "recogido": ["recogido", "peinado", "cabello", "hair", "salon", "estilista", "novia"],
  "alisado": ["alisado", "keratina", "cabello", "hair", "salon"],
  // Brows
  "microblading": ["microblading", "micropigmentacion", "ceja", "brow"],
  "cejas": ["ceja", "brow", "microblading", "micropigmentacion"],
  // Makeup
  "maquillaje": ["maquillaje", "makeup", "mua", "novia", "evento"],
  // Waxing/removal
  "depilacion": ["depilacion", "wax", "cera", "laser", "sugaring"],
  // Facial
  "facial": ["facial", "spa", "limpieza", "skin", "piel"],
  // Body
  "masaje": ["masaje", "massage", "spa", "body"],
};

function buildServiceKeywords(query: string): string[] {
  const lower = query.toLowerCase()
    .normalize("NFD").replace(/[\u0300-\u036f]/g, ""); // strip accents

  // Check keyword map first
  for (const [key, keywords] of Object.entries(SERVICE_KEYWORD_MAP)) {
    if (lower.includes(key.normalize("NFD").replace(/[\u0300-\u036f]/g, ""))) {
      return keywords;
    }
  }

  // Fallback: split query into words, filter short words
  return lower.split(/[\s_]+/)
    .filter(w => w.length >= 3)
    .slice(0, 5);
}

function normalizeText(text: string): string {
  return text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
}

function matchesService(salon: any, keywords: string[]): boolean {
  const searchable = normalizeText([
    salon.business_name ?? "",
    salon.categories ?? "",
    ...(Array.isArray(salon.specialties) ? salon.specialties : []),
  ].join(" "));

  return keywords.some(kw => searchable.includes(kw));
}

function serviceMatchScore(salon: any, keywords: string[]): number {
  const name = normalizeText(salon.business_name ?? "");
  const category = normalizeText(salon.categories ?? "");
  const cats = normalizeText(
    (Array.isArray(salon.specialties) ? salon.specialties : []).join(" ")
  );

  let score = 0;
  for (const kw of keywords) {
    if (name.includes(kw)) score += 3;       // Name match is strongest
    if (category.includes(kw)) score += 2;    // Category match
    if (cats.includes(kw)) score += 1;        // Service categories match
  }
  return score;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
