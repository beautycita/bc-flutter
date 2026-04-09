import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";


// --- Helpers for search_place ---

function extractCity(address: string): string {
  const parts = address.split(",").map((p) => p.trim());
  if (parts.length >= 3) {
    const candidate = parts[parts.length - 2].replace(/^\d{5}\s*/, "");
    return candidate || parts[parts.length - 2];
  }
  return parts[0];
}

function extractState(address: string): string {
  const parts = address.split(",").map((p) => p.trim());
  if (parts.length >= 2) {
    // Last part is usually country or state
    return parts[parts.length - 1].replace(/^\d{5}\s*/, "");
  }
  return "";
}

function mapGoogleTypesToCategories(types: string[] | undefined): string[] {
  if (!types) return ["beauty"];
  const mapped = new Set<string>();
  for (const t of types) {
    switch (t) {
      case "barber_shop":
      case "barbershop":
        mapped.add("barberia");
        mapped.add("cabello");
        break;
      case "beauty_salon":
      case "hair_salon":
        mapped.add("cabello");
        break;
      case "nail_salon":
        mapped.add("unas");
        break;
      case "spa":
        mapped.add("cuerpo_spa");
        mapped.add("facial");
        break;
    }
  }
  return mapped.size > 0 ? Array.from(mapped) : ["beauty"];
}

// --- Main handler ---

serve(async (req) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Auth check FIRST — before any DB queries
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }
    const userId = user.id;

    const body = await req.json();
    const { action } = body;

    // ========================
    // ACTION: search_place
    // ========================
    if (action === "search_place") {
      const { query, lat, lng } = body;

      if (!query || lat == null || lng == null) {
        return new Response(
          JSON.stringify({ error: "query, lat, and lng are required" }),
          { status: 400, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
        );
      }

      const apiKey =
        Deno.env.get("GOOGLE_PLACES_API_KEY") ??
        Deno.env.get("GOOGLE_ROUTES_API_KEY") ??
        "";

      if (!apiKey) {
        return new Response(
          JSON.stringify({ error: "Google API key not configured" }),
          { status: 500, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
        );
      }

      // 1. Call Google Places textSearch
      const searchResp = await fetch(
        "https://places.googleapis.com/v1/places:searchText",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey,
            "X-Goog-FieldMask":
              "places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.nationalPhoneNumber,places.internationalPhoneNumber,places.types,places.photos,places.regularOpeningHours",
          },
          body: JSON.stringify({
            textQuery: query,
            locationBias: {
              circle: {
                center: { latitude: lat, longitude: lng },
                radius: 50000,
              },
            },
          }),
        }
      );

      const searchData = await searchResp.json();
      const places = searchData.places;

      if (!places || places.length === 0) {
        return new Response(
          JSON.stringify({ error: "No results found", salon: null }),
          { status: 200, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
        );
      }

      // 2. Take first result
      const place = places[0];
      const placeId = place.id;

      // 3. Check for duplicates by source_id
      const { data: existingRows } = await supabase
        .from("discovered_salons")
        .select("*")
        .eq("source_id", placeId)
        .limit(1);

      if (existingRows && existingRows.length > 0) {
        return new Response(
          JSON.stringify({ salon: existingRows[0], source: "existing" }),
          { headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
        );
      }

      // 4. Map categories
      const mappedCategories = mapGoogleTypesToCategories(place.types);

      // 5. Build photo URL
      let photoUrl: string | null = null;
      if (place.photos && place.photos.length > 0) {
        const photoName = place.photos[0].name;
        photoUrl = `https://places.googleapis.com/v1/${photoName}/media?maxHeightPx=500&maxWidthPx=800&key=${apiKey}`;
      }

      // 6. Extract location info
      const placeLat = place.location?.latitude;
      const placeLng = place.location?.longitude;
      const address = place.formattedAddress ?? "";

      // 7. Insert into discovered_salons
      const { data: inserted, error: insertErr } = await supabase
        .from("discovered_salons")
        .insert({
          source: "user_search",
          source_id: placeId,
          business_name: place.displayName?.text ?? query,
          phone: place.internationalPhoneNumber || place.nationalPhoneNumber || null,
          location_address: address,
          location_city: extractCity(address),
          location_state: extractState(address),
          country: "MX",
          latitude: placeLat,
          longitude: placeLng,
          feature_image_url: photoUrl,
          rating_average: place.rating ?? null,
          rating_count: place.userRatingCount ?? null,
          categories: place.types?.join(", ") ?? null,
          matched_categories: mappedCategories,
          status: "discovered",
        })
        .select()
        .single();

      if (insertErr) throw insertErr;

      // 8. Set PostGIS geography column (parameterized to prevent SQL injection)
      if (placeLat != null && placeLng != null && inserted) {
        await supabase.rpc("set_salon_location", {
          p_id: inserted.id,
          p_lng: Number(placeLng),
          p_lat: Number(placeLat),
        }).catch(() => {
          console.warn("[on-demand-scrape] Could not set geography column via RPC");
        });
      }

      return new Response(
        JSON.stringify({ salon: inserted, source: "scraped" }),
        { headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }

    // ========================
    // LEGACY: coverage check / scrape request flow
    // ========================
    const { lat, lng, radius_km = 15, city, state, scrape_request_id } = body;

    // If polling for status
    if (scrape_request_id) {
      const { data, error } = await supabase
        .from("scrape_requests")
        .select("id, status, records_found, error, created_at, completed_at")
        .eq("id", scrape_request_id)
        .single();

      if (error) throw error;
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders(req), "Content-Type": "application/json" },
      });
    }

    // Validate required params
    if (lat == null || lng == null) {
      return new Response(
        JSON.stringify({ error: "lat and lng are required" }),
        { status: 400, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }

    // Check coverage via PostGIS RPC
    const { data: coverage, error: covError } = await supabase.rpc("check_coverage", {
      p_lat: lat,
      p_lng: lng,
      p_radius_km: radius_km,
    });

    if (covError) throw covError;

    const salonCount = coverage?.[0]?.salon_count ?? 0;
    const hasCoverage = coverage?.[0]?.has_coverage ?? false;

    if (hasCoverage) {
      return new Response(
        JSON.stringify({ has_coverage: true, salon_count: salonCount }),
        { headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }

    // No coverage -- check for existing nearby pending/processing request
    // ~0.2 degrees latitude/longitude is roughly 20km at Mexican latitudes
    const { data: existing } = await supabase
      .from("scrape_requests")
      .select("id, status, city")
      .in("status", ["pending", "processing"])
      .gte("lat", lat - 0.2)
      .lte("lat", lat + 0.2)
      .gte("lng", lng - 0.2)
      .lte("lng", lng + 0.2)
      .limit(1);

    if (existing && existing.length > 0) {
      return new Response(
        JSON.stringify({
          has_coverage: false,
          salon_count: salonCount,
          scrape_request_id: existing[0].id,
          status: existing[0].status,
        }),
        { headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }

    // Create new scrape request
    const { data: newRequest, error: insertError } = await supabase
      .from("scrape_requests")
      .insert({
        city: city || `Location ${lat.toFixed(2)},${lng.toFixed(2)}`,
        state: state || null,
        country: "MX",
        lat,
        lng,
        radius_km,
        requested_by: userId,
      })
      .select()
      .single();

    if (insertError) throw insertError;

    return new Response(
      JSON.stringify({
        has_coverage: false,
        salon_count: salonCount,
        scrape_request_id: newRequest.id,
        status: "pending",
      }),
      { headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("[on-demand-scrape] Error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
    );
  }
});
