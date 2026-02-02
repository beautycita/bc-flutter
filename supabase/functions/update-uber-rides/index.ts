// update-uber-rides edge function
// Triggered when an appointment is rescheduled or cancelled.
// Actions:
//   - reschedule: Updates both Uber ride pickup times
//   - cancel: Cancels both Uber rides
//   - update_return: Changes return destination
//   - status: Gets current ride status from Uber API

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const UBER_API_BASE = "https://api.uber.com";

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
    .select("uber_access_token, uber_token_expires_at, uber_linked")
    .eq("id", userId)
    .single();

  if (!profile?.uber_linked || !profile.uber_access_token) return null;

  const expiresAt = new Date(profile.uber_token_expires_at).getTime();
  if (Date.now() > expiresAt - 300_000) return null;

  return profile.uber_access_token;
}

// ---------------------------------------------------------------------------
// Cancel rides
// ---------------------------------------------------------------------------

async function cancelRides(
  supabase: ReturnType<typeof createClient>,
  accessToken: string | null,
  appointmentId: string,
) {
  const { data: rides } = await supabase
    .from("uber_scheduled_rides")
    .select("*")
    .eq("appointment_id", appointmentId)
    .neq("status", "cancelled")
    .neq("status", "completed");

  if (!rides || rides.length === 0) {
    return { cancelled: 0 };
  }

  let cancelledCount = 0;

  for (const ride of rides) {
    // Cancel via Uber API if we have a request ID and token
    if (ride.uber_request_id && accessToken) {
      try {
        const resp = await uberFetch(
          `/v1.2/requests/${ride.uber_request_id}`,
          accessToken,
          { method: "DELETE" },
        );

        if (!resp.ok) {
          console.error(
            `Failed to cancel Uber ride ${ride.uber_request_id}:`,
            await resp.text(),
          );
        }
      } catch (err) {
        console.error("Uber cancel error:", err);
      }
    }

    // Update local status
    await supabase
      .from("uber_scheduled_rides")
      .update({ status: "cancelled" })
      .eq("id", ride.id);

    cancelledCount++;
  }

  return { cancelled: cancelledCount };
}

// ---------------------------------------------------------------------------
// Reschedule rides
// ---------------------------------------------------------------------------

async function rescheduleRides(
  supabase: ReturnType<typeof createClient>,
  accessToken: string | null,
  appointmentId: string,
  newAppointmentAt: string,
  durationMinutes: number,
) {
  const { data: rides } = await supabase
    .from("uber_scheduled_rides")
    .select("*")
    .eq("appointment_id", appointmentId)
    .neq("status", "cancelled")
    .neq("status", "completed");

  if (!rides || rides.length === 0) {
    return { rescheduled: 0 };
  }

  const newTime = new Date(newAppointmentAt);
  let rescheduledCount = 0;

  for (const ride of rides) {
    let newPickupAt: Date;

    if (ride.leg === "outbound") {
      // Estimate drive time from original scheduling
      const origPickup = new Date(ride.scheduled_pickup_at);
      // Keep same lead time as originally calculated
      // But base it on new appointment time
      const leadMs = new Date(newAppointmentAt).getTime() - origPickup.getTime();
      // If we can't figure out original lead, use 18min (15 drive + 3 buffer)
      const leadMinutes = leadMs > 0 ? Math.round(leadMs / 60_000) : 18;
      newPickupAt = new Date(newTime.getTime() - leadMinutes * 60_000);
    } else {
      // Return: appointment time + duration + 5min buffer
      newPickupAt = new Date(
        newTime.getTime() + (durationMinutes + 5) * 60_000,
      );
    }

    // Update via Uber API
    if (ride.uber_request_id && accessToken) {
      try {
        // Uber doesn't support rescheduling — must cancel and re-create
        await uberFetch(
          `/v1.2/requests/${ride.uber_request_id}`,
          accessToken,
          { method: "DELETE" },
        );

        // Re-create the ride
        const newResp = await uberFetch("/v1.2/requests", accessToken, {
          method: "POST",
          body: JSON.stringify({
            start_latitude: ride.pickup_lat,
            start_longitude: ride.pickup_lng,
            end_latitude: ride.dropoff_lat,
            end_longitude: ride.dropoff_lng,
            scheduled_at: newPickupAt.toISOString(),
          }),
        });

        if (newResp.ok) {
          const newData = await newResp.json();
          await supabase
            .from("uber_scheduled_rides")
            .update({
              uber_request_id: newData.request_id,
              scheduled_pickup_at: newPickupAt.toISOString(),
            })
            .eq("id", ride.id);
        } else {
          console.error(
            `Failed to re-schedule Uber ride:`,
            await newResp.text(),
          );
          // Still update local time even if API fails
          await supabase
            .from("uber_scheduled_rides")
            .update({
              scheduled_pickup_at: newPickupAt.toISOString(),
              uber_request_id: null,
              status: "cancelled",
            })
            .eq("id", ride.id);
        }
      } catch (err) {
        console.error("Uber reschedule error:", err);
      }
    } else {
      // No Uber API — just update local record
      await supabase
        .from("uber_scheduled_rides")
        .update({ scheduled_pickup_at: newPickupAt.toISOString() })
        .eq("id", ride.id);
    }

    rescheduledCount++;
  }

  return { rescheduled: rescheduledCount };
}

// ---------------------------------------------------------------------------
// Update return destination
// ---------------------------------------------------------------------------

async function updateReturnDestination(
  supabase: ReturnType<typeof createClient>,
  accessToken: string | null,
  appointmentId: string,
  newLat: number,
  newLng: number,
  newAddress: string | null,
) {
  const { data: ride } = await supabase
    .from("uber_scheduled_rides")
    .select("*")
    .eq("appointment_id", appointmentId)
    .eq("leg", "return")
    .neq("status", "cancelled")
    .neq("status", "completed")
    .single();

  if (!ride) {
    return { error: "No active return ride found" };
  }

  // Update via Uber API
  if (ride.uber_request_id && accessToken) {
    try {
      const resp = await uberFetch(
        `/v1.2/requests/${ride.uber_request_id}`,
        accessToken,
        {
          method: "PATCH",
          body: JSON.stringify({
            end_latitude: newLat,
            end_longitude: newLng,
          }),
        },
      );

      if (!resp.ok) {
        console.error("Uber destination update failed:", await resp.text());
      }
    } catch (err) {
      console.error("Uber destination update error:", err);
    }
  }

  // Update local record
  await supabase
    .from("uber_scheduled_rides")
    .update({
      dropoff_lat: newLat,
      dropoff_lng: newLng,
      dropoff_address: newAddress,
    })
    .eq("id", ride.id);

  return { updated: true };
}

// ---------------------------------------------------------------------------
// Get ride status
// ---------------------------------------------------------------------------

async function getRideStatus(
  supabase: ReturnType<typeof createClient>,
  accessToken: string | null,
  appointmentId: string,
) {
  const { data: rides } = await supabase
    .from("uber_scheduled_rides")
    .select("*")
    .eq("appointment_id", appointmentId)
    .order("leg", { ascending: true });

  if (!rides || rides.length === 0) {
    return { rides: [] };
  }

  // If we have Uber API access, refresh statuses
  if (accessToken) {
    for (const ride of rides) {
      if (
        ride.uber_request_id &&
        ride.status !== "cancelled" &&
        ride.status !== "completed"
      ) {
        try {
          const resp = await uberFetch(
            `/v1.2/requests/${ride.uber_request_id}`,
            accessToken,
          );

          if (resp.ok) {
            const data = await resp.json();
            const newStatus = mapUberStatus(data.status);
            if (newStatus !== ride.status) {
              await supabase
                .from("uber_scheduled_rides")
                .update({ status: newStatus })
                .eq("id", ride.id);
              ride.status = newStatus;
            }
          }
        } catch (err) {
          console.error("Uber status check error:", err);
        }
      }
    }
  }

  return { rides };
}

function mapUberStatus(uberStatus: string): string {
  const mapping: Record<string, string> = {
    processing: "requested",
    accepted: "accepted",
    arriving: "arriving",
    in_progress: "in_progress",
    completed: "completed",
    rider_canceled: "cancelled",
    driver_canceled: "cancelled",
    no_drivers_available: "cancelled",
  };
  return mapping[uberStatus] ?? "scheduled";
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
    const action: string = body.action;
    const appointmentId: string = body.appointment_id;

    if (!appointmentId) {
      return json({ error: "appointment_id required" }, 400);
    }

    const accessToken = await getUberAccessToken(supabase, user.id);

    switch (action) {
      case "cancel": {
        const result = await cancelRides(supabase, accessToken, appointmentId);
        return json(result);
      }

      case "reschedule": {
        if (!body.new_appointment_at || !body.duration_minutes) {
          return json(
            { error: "new_appointment_at and duration_minutes required" },
            400,
          );
        }
        const result = await rescheduleRides(
          supabase,
          accessToken,
          appointmentId,
          body.new_appointment_at,
          body.duration_minutes,
        );
        return json(result);
      }

      case "update_return": {
        if (!body.return_lat || !body.return_lng) {
          return json({ error: "return_lat and return_lng required" }, 400);
        }
        const result = await updateReturnDestination(
          supabase,
          accessToken,
          appointmentId,
          body.return_lat,
          body.return_lng,
          body.return_address ?? null,
        );
        return json(result);
      }

      case "status": {
        const result = await getRideStatus(
          supabase,
          accessToken,
          appointmentId,
        );
        return json(result);
      }

      default:
        return json({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (err) {
    console.error("update-uber-rides error:", err);
    return json({ error: String(err) }, 500);
  }
});
