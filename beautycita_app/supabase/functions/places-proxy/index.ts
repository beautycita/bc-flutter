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

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, content-type, x-client-info, apikey",
    },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
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
    return json({ error: String(err) }, 500);
  }
});
