// calendar-ics edge function
// Handles ICS format calendar operations:
//   export  — Generate .ics download from BeautyCita appointments
//   import  — Parse uploaded .ics file and create external appointments
//   feed    — Public ICS feed URL for subscribe-based sync
//
// No external API keys needed.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

function icsResponse(ics: string, filename: string) {
  return new Response(ics, {
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Access-Control-Allow-Origin": "*",
    },
  });
}

// ── ICS Generation ──────────────────────────────────────────────────────────

function escapeICS(text: string): string {
  return text
    .replace(/\\/g, "\\\\")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
    .replace(/\n/g, "\\n");
}

function toICSDate(iso: string): string {
  // Convert ISO 8601 to ICS format: 20260304T100000Z
  return iso.replace(/[-:]/g, "").replace(/\.\d+/, "").replace(/\+.*/, "Z");
}

function generateICS(
  calName: string,
  events: Array<{
    uid: string;
    summary: string;
    dtstart: string;
    dtend: string;
    description?: string;
    status?: string;
    location?: string;
  }>
): string {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//BeautyCita//Calendar//ES",
    `X-WR-CALNAME:${escapeICS(calName)}`,
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
  ];

  for (const e of events) {
    lines.push("BEGIN:VEVENT");
    lines.push(`UID:${e.uid}@beautycita.com`);
    lines.push(`DTSTART:${toICSDate(e.dtstart)}`);
    lines.push(`DTEND:${toICSDate(e.dtend)}`);
    lines.push(`SUMMARY:${escapeICS(e.summary)}`);
    if (e.description) {
      lines.push(`DESCRIPTION:${escapeICS(e.description)}`);
    }
    if (e.location) {
      lines.push(`LOCATION:${escapeICS(e.location)}`);
    }
    if (e.status) {
      lines.push(`STATUS:${e.status}`);
    }
    lines.push(`DTSTAMP:${toICSDate(new Date().toISOString())}`);
    lines.push("END:VEVENT");
  }

  lines.push("END:VCALENDAR");
  return lines.join("\r\n");
}

// ── ICS Parsing ─────────────────────────────────────────────────────────────

interface ParsedEvent {
  uid: string;
  summary: string;
  dtstart: string; // ISO 8601
  dtend: string;
  description?: string;
  location?: string;
  status?: string;
}

function parseICSDate(icsDate: string): string {
  // Handle both DTSTART:20260304T100000Z and DTSTART;TZID=...:20260304T100000
  const cleaned = icsDate
    .replace(/^.*[:]/g, "")
    .trim();

  // Parse: 20260304T100000Z or 20260304T100000
  const match = cleaned.match(
    /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z?$/
  );
  if (match) {
    const [, y, mo, d, h, mi, s] = match;
    return `${y}-${mo}-${d}T${h}:${mi}:${s}Z`;
  }

  // All-day: 20260304
  const dateMatch = cleaned.match(/^(\d{4})(\d{2})(\d{2})$/);
  if (dateMatch) {
    const [, y, mo, d] = dateMatch;
    return `${y}-${mo}-${d}T00:00:00Z`;
  }

  // Fallback: return as-is
  return cleaned;
}

function parseICS(icsContent: string): ParsedEvent[] {
  const events: ParsedEvent[] = [];
  const lines = icsContent.replace(/\r\n /g, "").split(/\r?\n/);
  let currentEvent: Partial<ParsedEvent> | null = null;

  for (const line of lines) {
    if (line === "BEGIN:VEVENT") {
      currentEvent = {};
      continue;
    }
    if (line === "END:VEVENT") {
      if (currentEvent?.dtstart && currentEvent?.dtend) {
        events.push({
          uid: currentEvent.uid ?? crypto.randomUUID(),
          summary: currentEvent.summary ?? "Evento",
          dtstart: currentEvent.dtstart,
          dtend: currentEvent.dtend,
          description: currentEvent.description,
          location: currentEvent.location,
          status: currentEvent.status,
        });
      }
      currentEvent = null;
      continue;
    }
    if (!currentEvent) continue;

    if (line.startsWith("UID:")) {
      currentEvent.uid = line.substring(4).trim();
    } else if (line.startsWith("SUMMARY:")) {
      currentEvent.summary = line.substring(8).replace(/\\[,;n]/g, (m) =>
        m === "\\n" ? "\n" : m.charAt(1)
      );
    } else if (line.startsWith("DTSTART")) {
      currentEvent.dtstart = parseICSDate(line);
    } else if (line.startsWith("DTEND")) {
      currentEvent.dtend = parseICSDate(line);
    } else if (line.startsWith("DESCRIPTION:")) {
      currentEvent.description = line.substring(12).replace(/\\[,;n]/g, (m) =>
        m === "\\n" ? "\n" : m.charAt(1)
      );
    } else if (line.startsWith("LOCATION:")) {
      currentEvent.location = line.substring(9).replace(/\\[,;n]/g, (m) =>
        m === "\\n" ? "\n" : m.charAt(1)
      );
    } else if (line.startsWith("STATUS:")) {
      currentEvent.status = line.substring(7).trim();
    }
  }

  return events;
}

// ── Main handler ────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST",
        "Access-Control-Allow-Headers":
          "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  const supabase = createClient(supabaseUrl, serviceKey);
  const url = new URL(req.url);

  // ─── GET /calendar-ics?feed=STAFF_ID ─────────────────────────────────────
  // Public ICS feed (no auth) — generates a live .ics from appointments.
  // Clients subscribe to this URL in Google Calendar / Apple Calendar / Outlook.
  if (req.method === "GET") {
    const feedStaffId = url.searchParams.get("feed");
    const feedBizId = url.searchParams.get("business");

    if (!feedStaffId && !feedBizId) {
      return json({ error: "feed (staff_id) or business (business_id) required" }, 400);
    }

    try {
      let appointments: Array<Record<string, unknown>>;
      let calName: string;

      if (feedBizId) {
        // Business-wide feed: all appointments for next 90 days
        const { data: biz } = await supabase
          .from("businesses")
          .select("name")
          .eq("id", feedBizId)
          .single();

        calName = biz?.name ?? "BeautyCita";

        const now = new Date();
        const future = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);

        const { data } = await supabase
          .from("appointments")
          .select("id, service_name, starts_at, ends_at, status, staff_id, staff(first_name, last_name)")
          .eq("business_id", feedBizId)
          .gte("starts_at", now.toISOString())
          .lte("starts_at", future.toISOString())
          .in("status", ["confirmed", "pending", "completed"])
          .order("starts_at");

        appointments = data ?? [];
      } else {
        // Staff-specific feed
        const { data: staffData } = await supabase
          .from("staff")
          .select("first_name, last_name, business_id, businesses(name)")
          .eq("id", feedStaffId!)
          .single();

        calName = staffData
          ? `${staffData.first_name} — ${(staffData as Record<string, unknown>).businesses?.name ?? "BeautyCita"}`
          : "BeautyCita";

        const now = new Date();
        const future = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);

        const { data } = await supabase
          .from("appointments")
          .select("id, service_name, starts_at, ends_at, status")
          .eq("staff_id", feedStaffId!)
          .gte("starts_at", now.toISOString())
          .lte("starts_at", future.toISOString())
          .in("status", ["confirmed", "pending", "completed"])
          .order("starts_at");

        appointments = data ?? [];
      }

      const events = appointments.map((a) => {
        const staff = a.staff as { first_name?: string; last_name?: string } | undefined;
        const staffName = staff ? `${staff.first_name ?? ""} ${staff.last_name ?? ""}`.trim() : "";
        return {
          uid: a.id as string,
          summary: `${a.service_name ?? "Cita"}${staffName ? ` — ${staffName}` : ""}`,
          dtstart: a.starts_at as string,
          dtend: a.ends_at as string,
          status: (a.status === "confirmed" || a.status === "completed") ? "CONFIRMED" : "TENTATIVE",
        };
      });

      const ics = generateICS(calName, events);
      return icsResponse(ics, `${calName.replace(/[^a-zA-Z0-9]/g, "_")}.ics`);
    } catch (err) {
      console.error("ICS feed error:", err);
      return json({ error: String(err) }, 500);
    }
  }

  // ─── POST actions (authenticated) ─────────────────────────────────────────
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Authenticate
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
    const action = body.action ?? "";

    // ─── ACTION: export ─────────────────────────────────────────────────────
    // Returns .ics content for the business (or specific staff)
    if (action === "export") {
      const staffId = body.staff_id;
      const daysBack = body.days_back ?? 30;
      const daysAhead = body.days_ahead ?? 90;

      // Get the staff/business record
      const { data: staffRecord } = await supabase
        .from("staff")
        .select("id, first_name, business_id, businesses(name)")
        .eq("user_id", user.id)
        .single();

      if (!staffRecord) {
        return json({ error: "No staff record found" }, 403);
      }

      const bizName = (staffRecord as Record<string, unknown>).businesses?.name ?? "BeautyCita";
      const now = new Date();
      const start = new Date(now.getTime() - daysBack * 24 * 60 * 60 * 1000);
      const end = new Date(now.getTime() + daysAhead * 24 * 60 * 60 * 1000);

      let query = supabase
        .from("appointments")
        .select("id, service_name, starts_at, ends_at, status, notes, staff(first_name, last_name)")
        .eq("business_id", staffRecord.business_id)
        .gte("starts_at", start.toISOString())
        .lte("starts_at", end.toISOString())
        .in("status", ["confirmed", "pending", "completed"])
        .order("starts_at");

      if (staffId) {
        query = query.eq("staff_id", staffId);
      }

      const { data: appointments } = await query;

      const events = (appointments ?? []).map((a: Record<string, unknown>) => {
        const staff = a.staff as { first_name?: string; last_name?: string } | undefined;
        const staffName = staff ? `${staff.first_name ?? ""} ${staff.last_name ?? ""}`.trim() : "";
        return {
          uid: a.id as string,
          summary: `${a.service_name ?? "Cita"}${staffName ? ` — ${staffName}` : ""}`,
          dtstart: a.starts_at as string,
          dtend: a.ends_at as string,
          description: (a.notes as string) ?? undefined,
          status: (a.status === "confirmed" || a.status === "completed") ? "CONFIRMED" : "TENTATIVE",
        };
      });

      const ics = generateICS(bizName as string, events);
      return json({ ics, events_count: events.length });
    }

    // ─── ACTION: import ─────────────────────────────────────────────────────
    // Parse .ics content and create external_appointments
    if (action === "import") {
      const icsContent = body.ics_content;
      const targetStaffId = body.staff_id;

      if (!icsContent) {
        return json({ error: "ics_content required" }, 400);
      }

      // Get the staff record for this user
      const { data: staffRecord } = await supabase
        .from("staff")
        .select("id, business_id")
        .eq("user_id", user.id)
        .single();

      if (!staffRecord) {
        return json({ error: "No staff record found" }, 403);
      }

      const effectiveStaffId = targetStaffId ?? staffRecord.id;

      // Verify user owns the target staff's business
      if (effectiveStaffId !== staffRecord.id) {
        const { data: targetStaff } = await supabase
          .from("staff")
          .select("business_id")
          .eq("id", effectiveStaffId)
          .single();

        if (!targetStaff || targetStaff.business_id !== staffRecord.business_id) {
          return json({ error: "Cannot import to a staff member in a different business" }, 403);
        }
      }

      const events = parseICS(icsContent);

      if (events.length === 0) {
        return json({ imported: 0, message: "No events found in ICS file" });
      }

      // Filter to future events only (no point importing past events)
      const now = new Date();
      const futureEvents = events.filter(
        (e) => new Date(e.dtend) > now
      );

      // Convert to external_appointments format
      const records = futureEvents.map((e) => ({
        staff_id: effectiveStaffId,
        source: "ical" as const,
        external_id: e.uid,
        title: e.summary,
        starts_at: e.dtstart,
        ends_at: e.dtend,
        is_blocking: e.status !== "TRANSPARENT",
        raw_data: e,
        synced_at: new Date().toISOString(),
      }));

      // Upsert (skip duplicates by external_id)
      const { error: upsertError } = await supabase
        .from("external_appointments")
        .upsert(records, {
          onConflict: "staff_id,source,external_id",
        });

      if (upsertError) {
        console.error("ICS import upsert error:", upsertError);
        return json({ error: "Failed to save imported events" }, 500);
      }

      return json({
        imported: records.length,
        total_parsed: events.length,
        skipped_past: events.length - futureEvents.length,
      });
    }

    // ─── ACTION: feed_url ───────────────────────────────────────────────────
    // Returns the public ICS feed URL for this business/staff
    if (action === "feed_url") {
      const { data: staffRecord } = await supabase
        .from("staff")
        .select("id, business_id")
        .eq("user_id", user.id)
        .single();

      if (!staffRecord) {
        return json({ error: "No staff record found" }, 403);
      }

      const baseUrl = `${supabaseUrl}/functions/v1/calendar-ics`;
      const staffFeed = `${baseUrl}?feed=${staffRecord.id}`;
      const bizFeed = `${baseUrl}?business=${staffRecord.business_id}`;

      return json({
        staff_feed_url: staffFeed,
        business_feed_url: bizFeed,
      });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (err) {
    console.error("calendar-ics error:", err);
    return json({ error: String(err) }, 500);
  }
});
