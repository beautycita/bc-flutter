import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { lat, lng, radius_km = 15, city, state, scrape_request_id } = await req.json();

    // If polling for status
    if (scrape_request_id) {
      const { data, error } = await supabase
        .from("scrape_requests")
        .select("id, status, records_found, error, created_at, completed_at")
        .eq("id", scrape_request_id)
        .single();

      if (error) throw error;
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Validate required params
    if (lat == null || lng == null) {
      return new Response(
        JSON.stringify({ error: "lat and lng are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
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
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
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
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Auth check (required)
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    const userId = user.id;

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
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
