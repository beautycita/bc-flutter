// google-calendar-sync edge function
// Syncs Google Calendar events to external_appointments table.
// Uses stored OAuth tokens with automatic refresh.
//
// Environment secrets required:
//   GOOGLE_CLIENT_ID
//   GOOGLE_CLIENT_SECRET

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireFeature } from "../_shared/check-toggle.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID") ?? "";
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET") ?? "";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const GOOGLE_CALENDAR_API = "https://www.googleapis.com/calendar/v3";

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

// Refresh Google OAuth tokens
async function refreshGoogleTokens(
  refreshToken: string
): Promise<{ access_token: string; expires_in: number } | null> {
  const resp = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    console.error("Google token refresh failed:", resp.status, errText);
    return null;
  }

  return resp.json();
}

// Get valid access token with auto-refresh
async function getValidAccessToken(
  supabase: ReturnType<typeof createClient>,
  staffId: string,
  connection: {
    access_token: string;
    refresh_token: string | null;
    token_expires_at: string | null;
  }
): Promise<string | null> {
  // Check if token is still valid (5 minute buffer)
  if (connection.token_expires_at) {
    const expiresAt = new Date(connection.token_expires_at).getTime();
    if (Date.now() <= expiresAt - 300_000) {
      return connection.access_token;
    }
  }

  // Token expired or about to expire - refresh it
  if (!connection.refresh_token) {
    console.error("No refresh token available for staff:", staffId);
    return null;
  }

  console.log("Refreshing Google token for staff:", staffId);
  const tokens = await refreshGoogleTokens(connection.refresh_token);

  if (!tokens) {
    // Mark connection as having an error
    await supabase
      .from("calendar_connections")
      .update({
        sync_error: "Token refresh failed. Please reconnect Google Calendar.",
        updated_at: new Date().toISOString(),
      })
      .eq("staff_id", staffId)
      .eq("provider", "google");
    return null;
  }

  // Update stored tokens
  const newExpiresAt = new Date(
    Date.now() + (tokens.expires_in ?? 3600) * 1000
  ).toISOString();

  await supabase
    .from("calendar_connections")
    .update({
      access_token: tokens.access_token,
      token_expires_at: newExpiresAt,
      sync_error: null,
      updated_at: new Date().toISOString(),
    })
    .eq("staff_id", staffId)
    .eq("provider", "google");

  return tokens.access_token;
}

// Fetch events from Google Calendar API
async function fetchCalendarEvents(
  accessToken: string,
  timeMin: string,
  timeMax: string
): Promise<Array<{
  id: string;
  summary?: string;
  start: { dateTime?: string; date?: string };
  end: { dateTime?: string; date?: string };
  status: string;
  transparency?: string;
}>> {
  const url = new URL(`${GOOGLE_CALENDAR_API}/calendars/primary/events`);
  url.searchParams.set("timeMin", timeMin);
  url.searchParams.set("timeMax", timeMax);
  url.searchParams.set("singleEvents", "true");
  url.searchParams.set("orderBy", "startTime");
  url.searchParams.set("maxResults", "250");

  const resp = await fetch(url.toString(), {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Google Calendar API error: ${resp.status} ${errText}`);
  }

  const data = await resp.json();
  return data.items ?? [];
}

// Parse Google Calendar event to external appointment format
function parseEventToAppointment(
  staffId: string,
  event: {
    id: string;
    summary?: string;
    start: { dateTime?: string; date?: string };
    end: { dateTime?: string; date?: string };
    status: string;
    transparency?: string;
  }
): {
  staff_id: string;
  source: string;
  external_id: string;
  title: string | null;
  starts_at: string;
  ends_at: string;
  is_blocking: boolean;
  raw_data: unknown;
  synced_at: string;
} | null {
  // Skip cancelled events
  if (event.status === "cancelled") {
    return null;
  }

  // Skip events created by BeautyCita export (avoid round-trip duplication)
  if (event.summary?.startsWith("[BeautyCita]")) {
    return null;
  }

  // Parse start/end times
  let startsAt: string;
  let endsAt: string;

  if (event.start.dateTime) {
    startsAt = event.start.dateTime;
  } else if (event.start.date) {
    // All-day event - starts at midnight
    startsAt = `${event.start.date}T00:00:00Z`;
  } else {
    return null;
  }

  if (event.end.dateTime) {
    endsAt = event.end.dateTime;
  } else if (event.end.date) {
    // All-day event - ends at midnight of the next day
    endsAt = `${event.end.date}T00:00:00Z`;
  } else {
    return null;
  }

  // Determine if event blocks availability
  // "transparent" means "show as free", "opaque" (default) means "show as busy"
  const isBlocking = event.transparency !== "transparent";

  return {
    staff_id: staffId,
    source: "google_calendar",
    external_id: event.id,
    title: event.summary ?? null,
    starts_at: startsAt,
    ends_at: endsAt,
    is_blocking: isBlocking,
    raw_data: event,
    synced_at: new Date().toISOString(),
  };
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

  const blocked = await requireFeature("enable_google_calendar");
  if (blocked) return blocked;

  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    return json({ error: "Google Calendar not configured" }, 500);
  }

  // Authenticate the calling user
  const authHeader = req.headers.get("authorization") ?? "";
  const supabase = createClient(supabaseUrl, serviceKey);

  // Verify the user's JWT
  const token = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  // Rate limit: 10 requests per minute
  const rateLimitKey = user?.id || authHeader.slice(-16) || "anon";
  if (!checkRateLimit(rateLimitKey, 10, 60_000)) {
    return json({ error: "Rate limit exceeded" }, 429);
  }

  try {
    const body = await req.json();
    const action = body.action ?? "import";
    const daysAhead = body.days ?? 30;

    // Get the staff record for this user
    const { data: staffRecord, error: staffError } = await supabase
      .from("staff")
      .select("id, business_id, first_name")
      .eq("user_id", user.id)
      .single();

    if (staffError || !staffRecord) {
      return json({ error: "No staff record found" }, 403);
    }

    // Get the calendar connection
    const { data: connection, error: connError } = await supabase
      .from("calendar_connections")
      .select("access_token, refresh_token, token_expires_at, sync_enabled")
      .eq("staff_id", staffRecord.id)
      .eq("provider", "google")
      .single();

    if (connError || !connection) {
      return json({ error: "Google Calendar not connected" }, 404);
    }

    if (!connection.sync_enabled) {
      return json({ error: "Calendar sync is disabled" }, 400);
    }

    // Get valid access token (with auto-refresh)
    const accessToken = await getValidAccessToken(
      supabase,
      staffRecord.id,
      connection
    );

    if (!accessToken) {
      return json({
        error: "Failed to get valid access token. Please reconnect Google Calendar.",
      }, 401);
    }

    // =========================================================================
    // ACTION: export — Push BeautyCita appointments → Google Calendar
    // =========================================================================
    if (action === "export") {
      const now = new Date();
      const timeMin = now.toISOString();
      const timeMax = new Date(now.getTime() + daysAhead * 24 * 60 * 60 * 1000).toISOString();

      // Fetch upcoming BeautyCita appointments for this staff
      const { data: bcAppts, error: apptErr } = await supabase
        .from("appointments")
        .select("id, service_name, starts_at, ends_at, status, price, notes, google_event_id")
        .eq("staff_id", staffRecord.id)
        .eq("business_id", staffRecord.business_id)
        .in("status", ["confirmed", "pending"])
        .gte("starts_at", timeMin)
        .lte("starts_at", timeMax)
        .order("starts_at");

      if (apptErr) {
        return json({ error: `Failed to fetch appointments: ${apptErr.message}` }, 500);
      }

      let created = 0;
      let updated = 0;
      let skipped = 0;

      for (const appt of (bcAppts ?? [])) {
        const eventBody = {
          summary: `[BeautyCita] ${appt.service_name}`,
          description: `Reserva BeautyCita #${(appt.id as string).slice(0, 8)}\nPrecio: $${appt.price ?? 0} MXN\nEstado: ${appt.status}${appt.notes ? '\nNotas: ' + appt.notes : ''}`,
          start: { dateTime: appt.starts_at, timeZone: "America/Mexico_City" },
          end: { dateTime: appt.ends_at, timeZone: "America/Mexico_City" },
          transparency: "opaque",
          colorId: "6", // Tangerine — stands out as BeautyCita
        };

        try {
          if (appt.google_event_id) {
            // Update existing event
            const updateResp = await fetch(
              `${GOOGLE_CALENDAR_API}/calendars/primary/events/${appt.google_event_id}`,
              {
                method: "PUT",
                headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
                body: JSON.stringify(eventBody),
              }
            );
            if (updateResp.ok) { updated++; }
            else if (updateResp.status === 404) {
              // Event was deleted from Google — re-create
              const createResp = await fetch(
                `${GOOGLE_CALENDAR_API}/calendars/primary/events`,
                {
                  method: "POST",
                  headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
                  body: JSON.stringify(eventBody),
                }
              );
              if (createResp.ok) {
                const newEvent = await createResp.json();
                await supabase.from("appointments").update({ google_event_id: newEvent.id }).eq("id", appt.id);
                created++;
              } else { skipped++; }
            } else { skipped++; }
          } else {
            // Create new event
            const createResp = await fetch(
              `${GOOGLE_CALENDAR_API}/calendars/primary/events`,
              {
                method: "POST",
                headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
                body: JSON.stringify(eventBody),
              }
            );
            if (createResp.ok) {
              const newEvent = await createResp.json();
              await supabase.from("appointments").update({ google_event_id: newEvent.id }).eq("id", appt.id);
              created++;
            } else {
              const errText = await createResp.text();
              console.error(`Failed to create Google event for ${appt.id}:`, errText);
              skipped++;
            }
          }
        } catch (e) {
          console.error(`Error exporting appointment ${appt.id}:`, e);
          skipped++;
        }
      }

      // Update sync timestamp
      await supabase.from("calendar_connections").update({
        last_synced_at: new Date().toISOString(),
        sync_error: null,
        updated_at: new Date().toISOString(),
      }).eq("staff_id", staffRecord.id).eq("provider", "google");

      return json({
        exported: true,
        total: (bcAppts ?? []).length,
        created,
        updated,
        skipped,
      });
    }

    // =========================================================================
    // ACTION: import (default) — Pull Google Calendar → BeautyCita
    // =========================================================================

    // Calculate time range
    const now = new Date();
    const timeMin = now.toISOString();
    const timeMax = new Date(
      now.getTime() + daysAhead * 24 * 60 * 60 * 1000
    ).toISOString();

    // Fetch events from Google Calendar
    let events;
    try {
      events = await fetchCalendarEvents(accessToken, timeMin, timeMax);
    } catch (err) {
      console.error("Failed to fetch calendar events:", err);

      // Update sync error
      await supabase
        .from("calendar_connections")
        .update({
          sync_error: String(err),
          updated_at: new Date().toISOString(),
        })
        .eq("staff_id", staffRecord.id)
        .eq("provider", "google");

      return json({ error: `Failed to fetch events: ${err}` }, 502);
    }

    // Convert events to external appointments
    const appointments = events
      .map((event) => parseEventToAppointment(staffRecord.id, event))
      .filter((apt): apt is NonNullable<typeof apt> => apt !== null);

    // Get existing external appointment IDs for this source
    const { data: existingApts } = await supabase
      .from("external_appointments")
      .select("external_id")
      .eq("staff_id", staffRecord.id)
      .eq("source", "google_calendar");

    const existingIds = new Set(existingApts?.map((a) => a.external_id) ?? []);
    const newIds = new Set(appointments.map((a) => a.external_id));

    // Delete appointments that no longer exist in Google Calendar
    const toDelete = [...existingIds].filter((id) => !newIds.has(id));
    if (toDelete.length > 0) {
      await supabase
        .from("external_appointments")
        .delete()
        .eq("staff_id", staffRecord.id)
        .eq("source", "google_calendar")
        .in("external_id", toDelete);
    }

    // Upsert appointments
    if (appointments.length > 0) {
      const { error: upsertError } = await supabase
        .from("external_appointments")
        .upsert(appointments, {
          onConflict: "staff_id,source,external_id",
        });

      if (upsertError) {
        console.error("Failed to upsert appointments:", upsertError);
        return json({ error: "Failed to save appointments" }, 500);
      }
    }

    // Update last synced timestamp and clear any errors
    await supabase
      .from("calendar_connections")
      .update({
        last_synced_at: new Date().toISOString(),
        sync_error: null,
        updated_at: new Date().toISOString(),
      })
      .eq("staff_id", staffRecord.id)
      .eq("provider", "google");

    return json({
      synced: true,
      events_fetched: events.length,
      appointments_saved: appointments.length,
      appointments_deleted: toDelete.length,
      time_range: {
        from: timeMin,
        to: timeMax,
      },
    });
  } catch (err) {
    console.error("google-calendar-sync error:", err);
    return json({ error: String(err) }, 500);
  }
});
