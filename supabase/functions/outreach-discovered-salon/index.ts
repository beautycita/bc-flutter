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
      const { lat, lng, radius_km = 50 } = params;
      if (!lat || !lng) {
        return jsonResponse({ error: "lat and lng required" }, 400);
      }

      // Use PostGIS to find nearby discovered salons not yet registered
      const { data, error } = await serviceClient.rpc("nearby_discovered_salons", {
        user_lat: lat,
        user_lng: lng,
        radius_km: radius_km,
        max_results: 100,
      });

      if (error) {
        // Fallback: plain query without PostGIS function
        const { data: fallback, error: fallbackErr } = await serviceClient
          .from("discovered_salons")
          .select("id, name, phone, whatsapp, address, city, lat, lng, photo_url, rating, reviews_count, interest_count, status")
          .in("status", ["discovered", "selected", "outreach_sent"])
          .not("lat", "is", null)
          .limit(100);

        if (fallbackErr) {
          return jsonResponse({ error: fallbackErr.message }, 500);
        }

        // Client-side distance filtering
        const results = (fallback ?? [])
          .map((s: any) => ({
            ...s,
            distance_km: haversineKm(lat, lng, s.lat, s.lng),
          }))
          .filter((s: any) => s.distance_km <= radius_km)
          .sort((a: any, b: any) => a.distance_km - b.distance_km);

        return jsonResponse({ salons: results, count: results.length });
      }

      return jsonResponse({ salons: data ?? [], count: (data ?? []).length });
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
          const registrationLink = `https://beautycita.com/registro?ref=${discovered_salon_id}`;
          const message = getOutreachMessage(interestCount, salon.name, registrationLink);

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
          console.log(`[OUTREACH] Salon: ${salon.name}, Count: ${interestCount}, Channel: ${salon.whatsapp ? 'whatsapp' : 'sms'}, Message: ${message}`);
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
        if (!salon.name || !salon.city || !salon.state || !salon.source) {
          skipped++;
          errors.push(`Missing required fields: ${salon.name ?? "unnamed"}`);
          continue;
        }

        const record = {
          source: salon.source,
          source_id: salon.source_id ?? null,
          name: salon.name,
          phone: salon.phone ?? null,
          whatsapp: salon.whatsapp ?? salon.phone ?? null,
          address: salon.address ?? null,
          city: salon.city,
          state: salon.state,
          country: salon.country ?? "MX",
          lat: salon.lat ?? null,
          lng: salon.lng ?? null,
          photo_url: salon.photo_url ?? null,
          rating: salon.rating ?? null,
          reviews_count: salon.reviews_count ?? null,
          business_category: salon.business_category ?? null,
          service_categories: salon.service_categories ?? null,
          hours: salon.hours ?? null,
          website: salon.website ?? null,
          facebook_url: salon.facebook_url ?? null,
          instagram_handle: salon.instagram_handle ?? null,
          scraped_at: salon.scraped_at ?? new Date().toISOString(),
        };

        const { error: upsertError } = await serviceClient
          .from("discovered_salons")
          .upsert(record, { onConflict: "source,source_id" });

        if (upsertError) {
          skipped++;
          errors.push(`${salon.name}: ${upsertError.message}`);
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

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
