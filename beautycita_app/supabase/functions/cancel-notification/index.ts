// =============================================================================
// cancel-notification — Notify customer + stylist when appointment is cancelled
// =============================================================================
// Called from admin panel after cancellation.
// Sends WhatsApp + push notification to the customer, WhatsApp to stylist.
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
      console.error(`[CANCEL] WA send failed for ${phone}: ${res.status}`);
      return false;
    }
    const data = await res.json();
    return data.sent === true;
  } catch (err) {
    console.error(`[CANCEL] WA error for ${phone}:`, err);
    return false;
  }
}

Deno.serve(async (req) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, req);
  }

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
    const { appointment_id } = await req.json();

    if (!appointment_id) {
      return json({ error: "appointment_id is required" }, 400, req);
    }

    const { data: appt, error: apptErr } = await supabase
      .from("appointments")
      .select(
        `
        id,
        user_id,
        staff_id,
        service_name,
        staff_name,
        customer_name,
        starts_at,
        businesses!appointments_business_id_fkey (
          name
        )
      `
      )
      .eq("id", appointment_id)
      .single();

    if (apptErr || !appt) {
      console.error("[CANCEL] Appointment lookup failed:", apptErr);
      return json({ error: "Appointment not found" }, 404, req);
    }

    // Atomic notify-once claim (cancel is terminal — never cleared).
    const { data: claimed } = await supabase
      .from("appointments")
      .update({ cancel_notified_at: new Date().toISOString() })
      .eq("id", appointment_id)
      .is("cancel_notified_at", null)
      .select("id");
    if (!claimed || claimed.length === 0) {
      console.log(`[CANCEL] ${appointment_id} already notified, skipping`);
      return json({ success: true, skipped: "already_notified" }, 200, req);
    }

    const salonName = (appt as any).businesses?.name ?? "Salon";
    const { date, time } = formatDateEs(appt.starts_at);
    const staffName = appt.staff_name || "";
    const serviceName = appt.service_name || "servicio";

    const results: Record<string, string> = {};

    // 1. Notify customer (WhatsApp + push)
    if (appt.user_id) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("phone, fcm_token")
        .eq("id", appt.user_id)
        .single();

      const phone = profile?.phone ?? null;
      const fcmToken = profile?.fcm_token ?? null;

      if (phone) {
        const message =
          `*BeautyCita - Cita Cancelada*\n` +
          `Tu cita de ${serviceName} ha sido cancelada.\n` +
          `Fecha original: ${date}, ${time}\n` +
          (staffName ? `Estilista: ${staffName}\n` : "") +
          `Salon: ${salonName}\n\n` +
          `Si tienes preguntas, contacta al salon directamente.`;

        const waSent = await sendWhatsApp(phone, message);
        results.whatsapp = waSent ? "sent" : "failed";
      } else {
        results.whatsapp = "skipped";
      }

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
                notification_type: "booking_cancelled",
                custom_title: "Cita Cancelada",
                custom_body: `Tu cita de ${serviceName} (${date}, ${time}) ha sido cancelada.`,
                data: {
                  route: "/bookings",
                  booking_id: appt.id,
                  type: "cancelled",
                },
              }),
            }
          );
          results.push = pushRes.ok ? "sent" : "failed";
        } catch (pushErr) {
          results.push = "error";
          console.error("[CANCEL] Push error:", pushErr);
        }
      } else {
        results.push = "skipped";
      }
    } else {
      results.whatsapp = "skipped";
      results.push = "skipped";
    }

    // 2. Notify stylist via WhatsApp
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
          `*BeautyCita - Cita Cancelada*\n` +
          `La cita de ${serviceName} con ${customerName} ha sido cancelada.\n` +
          `Fecha: ${date}, ${time}\n` +
          `Salon: ${salonName}`;

        const staffWaSent = await sendWhatsApp(staffPhone, staffMsg);
        results.staff_whatsapp = staffWaSent ? "sent" : "failed";
      } else {
        results.staff_whatsapp = "no_phone";
      }
    } else {
      results.staff_whatsapp = "no_staff";
    }

    console.log(
      `[CANCEL] Appointment ${appointment_id} — results:`,
      results
    );
    return json({ success: true, appointment_id, channels: results }, 200, req);
  } catch (err) {
    console.error("[CANCEL] Handler error:", (err as Error).message);
    return json({ error: "Internal server error" }, 500, req);
  }
});
