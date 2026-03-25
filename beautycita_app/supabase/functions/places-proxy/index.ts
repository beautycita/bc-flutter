// places-proxy edge function
// Proxies Google Places API calls server-side to avoid API key restrictions
// Actions:
//   - autocomplete: Search for places
//   - details: Get place details (coordinates + address)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_API_KEY =
  Deno.env.get("GOOGLE_PLACES_API_KEY") ??
  Deno.env.get("GOOGLE_ROUTES_API_KEY") ??
  "";

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

let _req: Request;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": corsOrigin(_req),
      "Access-Control-Allow-Headers":
        "authorization, content-type, x-client-info, apikey",
    },
  });
}

// Rate limiting
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(key: string, limit: number, windowMs: number): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(key);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (entry.count >= limit) return false;
  entry.count++;
  return true;
}

Deno.serve(async (req: Request) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": corsOrigin(req),
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers":
          "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Authenticate user
  const supabase = createClient(supabaseUrl, serviceKey);
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  // Rate limit: 30 requests per minute
  const rateLimitKey = user?.id || authHeader.slice(-16) || "anon";
  if (!checkRateLimit(rateLimitKey, 30, 60_000)) {
    return json({ error: "Rate limit exceeded" }, 429);
  }

  if (!GOOGLE_API_KEY) {
    return json({ error: "Google API key not configured" }, 500);
  }

  try {
    const body = await req.json();
    const action: string = body.action;

    switch (action) {
      case "autocomplete": {
        const input: string = body.input;
        if (!input) return json({ predictions: [] });

        const params = new URLSearchParams({
          input,
          key: GOOGLE_API_KEY,
          language: "es",
          components: "country:mx",
        });

        if (body.lat && body.lng) {
          params.set("location", `${body.lat},${body.lng}`);
          params.set("radius", "50000");
        }

        const resp = await fetch(
          `https://maps.googleapis.com/maps/api/place/autocomplete/json?${params}`,
          { headers: { Referer: "https://beautycita.com" } },
        );
        const data = await resp.json();

        if (data.status !== "OK" && data.status !== "ZERO_RESULTS") {
          console.error("Places autocomplete error:", data.status, data.error_message);
          return json({ predictions: [], error: data.error_message }, 200);
        }

        const predictions = (data.predictions ?? []).map(
          (p: Record<string, unknown>) => {
            const sf = (p.structured_formatting ?? {}) as Record<string, string>;
            return {
              place_id: p.place_id,
              main_text: sf.main_text ?? "",
              secondary_text: sf.secondary_text ?? "",
              description: p.description ?? "",
            };
          },
        );

        return json({ predictions });
      }

      case "details": {
        const placeId: string = body.place_id;
        if (!placeId) return json({ error: "place_id required" }, 400);

        const params = new URLSearchParams({
          place_id: placeId,
          fields: "geometry,formatted_address",
          key: GOOGLE_API_KEY,
          language: "es",
        });

        const resp = await fetch(
          `https://maps.googleapis.com/maps/api/place/details/json?${params}`,
          { headers: { Referer: "https://beautycita.com" } },
        );
        const data = await resp.json();

        if (data.status !== "OK") {
          console.error("Places details error:", data.status, data.error_message);
          return json({ error: data.error_message }, 200);
        }

        const result = data.result ?? {};
        const loc = result.geometry?.location;

        return json({
          lat: loc?.lat,
          lng: loc?.lng,
          address: result.formatted_address ?? "",
        });
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    console.error("places-proxy error:", err);
    return json({ error: "An internal error occurred" }, 500);
  }
});
