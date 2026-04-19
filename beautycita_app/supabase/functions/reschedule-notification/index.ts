// =============================================================================
// reschedule-notification — Notify customer when appointment is rescheduled
// =============================================================================
// Called from Flutter (web/mobile) after drag-and-drop reschedule.
// Sends WhatsApp + push notification to the customer.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";


function json(body: unknown, status = 200, req?: Request) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req!), "Content-Type": "application/json" },
  });
}

function formatDateEs(isoDate: string): { date: string; time: string } {
  const d = new Date(isoDate);
  const date = d.toLocaleDateString("es-MX", {
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
  });
  const time = d.toLocaleTimeString("es-MX", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
  return { date, time };
}

async function sendWhatsApp(phone: string, message: string): Promise<boolean> {
  if (!BEAUTYPI_WA_URL) return false;
  try {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 5000);
    const res = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
      signal: ac.signal,
    });
    clearTimeout(t);
    if (!res.ok) {
      console.error(`[RESCHEDULE] WA send failed for ${phone}: ${res.status}`);
      return false;
    }
    const data = await res.json();
    return data.sent === true;
  } catch (err) {
    console.error(`[RESCHEDULE] WA error for ${phone}:`, err);
    return false;
  }
}

Deno.serve(async (req) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, req);
  }

  // Auth: require valid JWT or service-role key
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  if (!token) {
    return json({ error: "Authorization required" }, 401, req);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const isServiceRole = token === SUPABASE_SERVICE_KEY;

  if (!isServiceRole) {
    const {
      data: { user },
      error: authErr,
    } = await supabase.auth.getUser(token);
    if (authErr || !user) {
      return json({ error: "Invalid token" }, 401, req);
    }
  }

  try {
    const { appointment_id, old_staff_id } = await req.json();

    if (!appointment_id) {
      return json({ error: "appointment_id is required" }, 400, req);
    }

    // 1. Fetch appointment with business join. staff_name is NOT a column
    //    on appointments (despite being a SELECT alias in some RPCs) —
    //    hunter caught this edge-fn silently 404ing on every reschedule.
    //    Staff name is now assembled from the staff join further down.
    const { data: appt, error: apptErr } = await supabase
      .from("appointments")
      .select(
        `
        id,
        user_id,
        business_id,
        staff_id,
        service_name,
        customer_name,
        starts_at,
        ends_at,
        businesses!appointments_business_id_fkey (
          name
        )
      `
      )
      .eq("id", appointment_id)
      .single();

    if (apptErr || !appt) {
      console.error("[RESCHEDULE] Appointment lookup failed:", apptErr);
      return json({ error: "Appointment not found" }, 404, req);
    }

    const salonName =
      (appt as any).businesses?.name ?? "Salon";
    const { date, time } = formatDateEs(appt.starts_at);
    const serviceName = appt.service_name || "servicio";

    // Assemble staff display name from staff table (optional — empty
    // string if no staff assigned or staff row missing).
    let staffName = "";
    if (appt.staff_id) {
      const { data: staffRow } = await supabase
        .from("staff")
        .select("first_name, last_name")
        .eq("id", appt.staff_id)
        .maybeSingle();
      if (staffRow) {
        const first = staffRow.first_name ?? "";
        const lastInitial = staffRow.last_name
          ? ` ${staffRow.last_name.slice(0, 1)}.`
          : "";
        staffName = `${first}${lastInitial}`.trim();
      }
    }

    const results: Record<string, string> = {};

    // 2. Fetch customer profile (phone, fcm_token)
    if (appt.user_id) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("phone, fcm_token, full_name")
        .eq("id", appt.user_id)
        .single();

      const phone = profile?.phone ?? null;
      const fcmToken = profile?.fcm_token ?? null;

      // 3. WhatsApp notification
      if (phone) {
        const message =
          `*BeautyCita - Cita Reagendada*\n` +
          `Tu cita de ${serviceName} ha sido reagendada.\n` +
          `Nueva fecha: ${date}, ${time}\n` +
          (staffName ? `Estilista: ${staffName}\n` : "") +
          `Salon: ${salonName}`;

        const waSent = await sendWhatsApp(phone, message);
        results.whatsapp = waSent ? "sent" : "failed";
        console.log(
          `[RESCHEDULE] WA ${waSent ? "sent" : "failed"} to ${phone}`
        );
      } else {
        results.whatsapp = "skipped";
      }

      // 4. Push notification
      if (fcmToken) {
        try {
          const pushRes = await fetch(
            `${SUPABASE_URL}/functions/v1/send-push-notification`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                user_id: appt.user_id,
                notification_type: "booking_rescheduled",
                custom_title: "Cita Reagendada",
                custom_body: `Tu cita de ${serviceName} fue movida a ${date}, ${time}${staffName ? ` con ${staffName}` : ""}`,
                data: {
                  route: "/bookings",
                  booking_id: appt.id,
                  type: "rescheduled",
                },
              }),
            }
          );

          results.push = pushRes.ok ? "sent" : "failed";
          if (!pushRes.ok) {
            console.error(
              `[RESCHEDULE] Push failed: ${await pushRes.text()}`
            );
          }
        } catch (pushErr) {
          results.push = "error";
          console.error("[RESCHEDULE] Push error:", pushErr);
        }
      } else {
        results.push = "skipped";
      }
    } else {
      // Walk-in appointment (no user_id) — skip customer notifications
      results.whatsapp = "skipped";
      results.push = "skipped";
    }

    // 5. Notify stylist via WhatsApp
    if (appt.staff_id) {
      const { data: staffMember } = await supabase
        .from("staff")
        .select("phone")
        .eq("id", appt.staff_id)
        .single();

      const staffPhone = staffMember?.phone ?? null;
      if (staffPhone) {
        const customerName = (appt as any).customer_name || "un cliente";
        const staffMsg =
          `*BeautyCita - Cita Reagendada*\n` +
          `La cita de ${serviceName} con ${customerName} ha sido movida.\n` +
          `Nueva fecha: ${date}, ${time}\n` +
          `Salon: ${salonName}`;

        const staffWaSent = await sendWhatsApp(staffPhone, staffMsg);
        results.staff_whatsapp = staffWaSent ? "sent" : "failed";
        console.log(`[RESCHEDULE] Staff WA ${staffWaSent ? "sent" : "failed"} to ${staffPhone}`);
      } else {
        results.staff_whatsapp = "no_phone";
      }
    } else {
      results.staff_whatsapp = "no_staff";
    }

    // 6. If stylist was reassigned, notify old stylist they lost the appointment
    if (old_staff_id && old_staff_id !== appt.staff_id) {
      const { data: oldStaff } = await supabase
        .from("staff")
        .select("phone, display_name")
        .eq("id", old_staff_id)
        .single();

      const oldStaffPhone = oldStaff?.phone ?? null;
      if (oldStaffPhone) {
        const customerName = (appt as any).customer_name || "un cliente";
        const oldStaffMsg =
          `*BeautyCita - Cita Reasignada*\n` +
          `La cita de ${serviceName} con ${customerName} ha sido reasignada a otro estilista.\n` +
          `Fecha: ${date}, ${time}\n` +
          `Salon: ${salonName}`;

        const oldStaffWaSent = await sendWhatsApp(oldStaffPhone, oldStaffMsg);
        results.old_staff_whatsapp = oldStaffWaSent ? "sent" : "failed";
        console.log(`[RESCHEDULE] Old staff WA ${oldStaffWaSent ? "sent" : "failed"} to ${oldStaffPhone}`);
      } else {
        results.old_staff_whatsapp = "no_phone";
      }
    }

    console.log(
      `[RESCHEDULE] Appointment ${appointment_id} — results:`,
      results
    );
    return json({ success: true, appointment_id, channels: results }, 200, req);
  } catch (err) {
    console.error("[RESCHEDULE] Handler error:", (err as Error).message);
    return json({ error: "Internal server error" }, 500, req);
  }
});
