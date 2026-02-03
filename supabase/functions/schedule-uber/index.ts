// schedule-uber edge function
// Handles Uber ride scheduling for BeautyCita bookings.
// Actions:
//   - estimate: Get fare estimate for a route (no booking)
//   - schedule: Create both outbound + return rides for an appointment
// Called after book-appointment confirms the booking.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const UBER_SANDBOX = Deno.env.get("UBER_SANDBOX") === "true";
const UBER_API_BASE = UBER_SANDBOX
  ? "https://sandbox-api.uber.com"
  : "https://api.uber.com";

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

// ---------------------------------------------------------------------------
// Uber API helpers
// ---------------------------------------------------------------------------

async function uberFetch(
  path: string,
  accessToken: string,
  options: RequestInit = {},
): Promise<Response> {
  return fetch(`${UBER_API_BASE}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...(options.headers ?? {}),
    },
  });
}

async function getUberAccessToken(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<string | null> {
  const { data: profile } = await supabase
    .from("profiles")
    .select(
      "uber_access_token, uber_refresh_token, uber_token_expires_at, uber_linked",
    )
    .eq("id", userId)
    .single();

  if (!profile?.uber_linked || !profile.uber_access_token) return null;

  // Check if token is expired (with 5min buffer)
  const expiresAt = new Date(profile.uber_token_expires_at).getTime();
  if (Date.now() > expiresAt - 300_000) {
    // Token expired — trigger refresh via link-uber function
    // For now, return null and let caller handle re-auth
    console.warn("Uber token expired for user", userId);
    return null;
  }

  return profile.uber_access_token;
}

// ---------------------------------------------------------------------------
// Fare estimate
// ---------------------------------------------------------------------------

interface EstimateRequest {
  start_lat: number;
  start_lng: number;
  end_lat: number;
  end_lng: number;
}

async function getFareEstimate(
  accessToken: string,
  req: EstimateRequest,
) {
  const resp = await uberFetch("/v1.2/estimates/price", accessToken, {
    method: "GET",
  });

  // Uber Estimates API uses GET with query params
  const params = new URLSearchParams({
    start_latitude: String(req.start_lat),
    start_longitude: String(req.start_lng),
    end_latitude: String(req.end_lat),
    end_longitude: String(req.end_lng),
  });

  const estimateResp = await fetch(
    `${UBER_API_BASE}/v1.2/estimates/price?${params}`,
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  );

  if (!estimateResp.ok) {
    const err = await estimateResp.text();
    console.error("Uber estimate failed:", err);
    return null;
  }

  const data = await estimateResp.json();

  // Find UberX or cheapest option
  const prices = data.prices ?? [];
  const uberX =
    prices.find(
      // deno-lint-ignore no-explicit-any
      (p: any) =>
        p.display_name === "UberX" || p.display_name === "Uber X",
    ) ?? prices[0];

  if (!uberX) return null;

  return {
    fare_min: uberX.low_estimate ?? 0,
    fare_max: uberX.high_estimate ?? 0,
    currency: uberX.currency_code ?? "MXN",
    duration_min: Math.round((uberX.duration ?? 0) / 60),
    distance_km:
      Math.round((uberX.distance ?? 0) * (uberX.currency_code === "MXN" ? 1.609 : 1) * 10) / 10,
    surge_multiplier: uberX.surge_multiplier ?? 1.0,
    product_id: uberX.product_id,
  };
}

// ---------------------------------------------------------------------------
// Schedule rides
// ---------------------------------------------------------------------------

interface ScheduleRequest {
  appointment_id: string;
  user_id: string;
  // Outbound leg
  pickup_lat: number;
  pickup_lng: number;
  pickup_address?: string;
  // Salon (destination for outbound, pickup for return)
  salon_lat: number;
  salon_lng: number;
  salon_address?: string;
  // Timing
  appointment_at: string; // ISO datetime
  duration_minutes: number;
  // Return destination (defaults to pickup location)
  return_lat?: number;
  return_lng?: number;
  return_address?: string;
  // Uber product
  product_id?: string;
}

async function scheduleRides(
  supabase: ReturnType<typeof createClient>,
  accessToken: string,
  req: ScheduleRequest,
) {
  const appointmentTime = new Date(req.appointment_at);

  // --- Outbound ride ---
  // Get estimate for drive time
  const outEstimate = await getFareEstimate(accessToken, {
    start_lat: req.pickup_lat,
    start_lng: req.pickup_lng,
    end_lat: req.salon_lat,
    end_lng: req.salon_lng,
  });

  const driveMinutes = outEstimate?.duration_min ?? 15;
  const bufferMinutes = 3;

  // Pickup time = appointment time - drive time - buffer
  const outboundPickup = new Date(
    appointmentTime.getTime() - (driveMinutes + bufferMinutes) * 60_000,
  );

  // --- Return ride ---
  const returnPickup = new Date(
    appointmentTime.getTime() + (req.duration_minutes + 5) * 60_000,
  );

  const returnLat = req.return_lat ?? req.pickup_lat;
  const returnLng = req.return_lng ?? req.pickup_lng;
  const returnAddress = req.return_address ?? req.pickup_address;

  // Get return estimate
  const returnEstimate = await getFareEstimate(accessToken, {
    start_lat: req.salon_lat,
    start_lng: req.salon_lng,
    end_lat: returnLat,
    end_lng: returnLng,
  });

  // Schedule outbound ride via Uber API
  let outboundRequestId: string | null = null;
  let returnRequestId: string | null = null;

  try {
    const outResp = await uberFetch("/v1.2/requests", accessToken, {
      method: "POST",
      body: JSON.stringify({
        product_id: req.product_id ?? outEstimate?.product_id,
        start_latitude: req.pickup_lat,
        start_longitude: req.pickup_lng,
        end_latitude: req.salon_lat,
        end_longitude: req.salon_lng,
        scheduled_at: outboundPickup.toISOString(),
      }),
    });

    if (outResp.ok) {
      const outData = await outResp.json();
      outboundRequestId = outData.request_id;
    } else {
      console.error(
        "Outbound Uber scheduling failed:",
        await outResp.text(),
      );
    }
  } catch (err) {
    console.error("Outbound Uber request error:", err);
  }

  try {
    const retResp = await uberFetch("/v1.2/requests", accessToken, {
      method: "POST",
      body: JSON.stringify({
        product_id: req.product_id ?? returnEstimate?.product_id,
        start_latitude: req.salon_lat,
        start_longitude: req.salon_lng,
        end_latitude: returnLat,
        end_longitude: returnLng,
        scheduled_at: returnPickup.toISOString(),
      }),
    });

    if (retResp.ok) {
      const retData = await retResp.json();
      returnRequestId = retData.request_id;
    } else {
      console.error("Return Uber scheduling failed:", await retResp.text());
    }
  } catch (err) {
    console.error("Return Uber request error:", err);
  }

  // Store rides in database
  const rides = [
    {
      appointment_id: req.appointment_id,
      user_id: req.user_id,
      leg: "outbound",
      uber_request_id: outboundRequestId,
      pickup_lat: req.pickup_lat,
      pickup_lng: req.pickup_lng,
      pickup_address: req.pickup_address ?? null,
      dropoff_lat: req.salon_lat,
      dropoff_lng: req.salon_lng,
      dropoff_address: req.salon_address ?? null,
      scheduled_pickup_at: outboundPickup.toISOString(),
      estimated_fare_min: outEstimate?.fare_min ?? null,
      estimated_fare_max: outEstimate?.fare_max ?? null,
      status: outboundRequestId ? "scheduled" : "cancelled",
    },
    {
      appointment_id: req.appointment_id,
      user_id: req.user_id,
      leg: "return",
      uber_request_id: returnRequestId,
      pickup_lat: req.salon_lat,
      pickup_lng: req.salon_lng,
      pickup_address: req.salon_address ?? null,
      dropoff_lat: returnLat,
      dropoff_lng: returnLng,
      dropoff_address: returnAddress ?? null,
      scheduled_pickup_at: returnPickup.toISOString(),
      estimated_fare_min: returnEstimate?.fare_min ?? null,
      estimated_fare_max: returnEstimate?.fare_max ?? null,
      status: returnRequestId ? "scheduled" : "cancelled",
    },
  ];

  const { data: insertedRides, error: insertErr } = await supabase
    .from("uber_scheduled_rides")
    .insert(rides)
    .select();

  if (insertErr) {
    console.error("Failed to insert uber rides:", insertErr);
  }

  return {
    outbound: {
      uber_request_id: outboundRequestId,
      pickup_at: outboundPickup.toISOString(),
      fare_min: outEstimate?.fare_min ?? null,
      fare_max: outEstimate?.fare_max ?? null,
    },
    return_ride: {
      uber_request_id: returnRequestId,
      pickup_at: returnPickup.toISOString(),
      fare_min: returnEstimate?.fare_min ?? null,
      fare_max: returnEstimate?.fare_max ?? null,
    },
    rides: insertedRides,
  };
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

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

  const supabase = createClient(supabaseUrl, serviceKey);

  // Authenticate user
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    const body = await req.json();
    const action = body.action ?? "schedule";

    // Get user's Uber access token
    const accessToken = await getUberAccessToken(supabase, user.id);

    if (action === "estimate") {
      if (!accessToken) {
        // Return distance-based estimate without Uber API
        const distKm =
          haversineKm(
            body.start_lat,
            body.start_lng,
            body.end_lat,
            body.end_lng,
          );
        const baseFare = 25; // MXN base
        const perKm = 8; // MXN per km
        const fareEst = baseFare + distKm * perKm;

        return json({
          fare_min: Math.round(fareEst * 0.85),
          fare_max: Math.round(fareEst * 1.25),
          currency: "MXN",
          duration_min: Math.max(5, Math.round(distKm / 0.5)),
          distance_km: Math.round(distKm * 10) / 10,
          is_estimate: true,
        });
      }

      const estimate = await getFareEstimate(accessToken, {
        start_lat: body.start_lat,
        start_lng: body.start_lng,
        end_lat: body.end_lat,
        end_lng: body.end_lng,
      });

      if (!estimate) {
        return json({ error: "Could not get Uber estimate" }, 502);
      }

      return json(estimate);
    }

    if (action === "schedule") {
      if (!accessToken) {
        return json(
          {
            error:
              "Uber account not linked or token expired. Please re-link.",
          },
          401,
        );
      }

      const result = await scheduleRides(supabase, accessToken, {
        appointment_id: body.appointment_id,
        user_id: user.id,
        pickup_lat: body.pickup_lat,
        pickup_lng: body.pickup_lng,
        pickup_address: body.pickup_address,
        salon_lat: body.salon_lat,
        salon_lng: body.salon_lng,
        salon_address: body.salon_address,
        appointment_at: body.appointment_at,
        duration_minutes: body.duration_minutes,
        return_lat: body.return_lat,
        return_lng: body.return_lng,
        return_address: body.return_address,
        product_id: body.product_id,
      });

      return json({
        scheduled: true,
        ...result,
      });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("schedule-uber error:", err);
    return json({ error: String(err) }, 500);
  }
});

// ---------------------------------------------------------------------------
// Haversine distance for fallback estimates
// ---------------------------------------------------------------------------

function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
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
