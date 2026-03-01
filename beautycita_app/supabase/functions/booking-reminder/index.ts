// =============================================================================
// booking-reminder — Hourly cron job for appointment reminders
// =============================================================================
// Finds appointments starting within the next 2 hours that haven't been
// reminded yet, sends push notifications, and marks them as reminded.
//
// NOTE: Requires a `reminded_at` column on the `appointments` table.
// Run this migration before deploying:
//
//   ALTER TABLE public.appointments
//     ADD COLUMN IF NOT EXISTS reminded_at timestamptz;
//
//   COMMENT ON COLUMN public.appointments.reminded_at IS
//     'Timestamp when the 2-hour reminder push was sent. NULL = not yet reminded.';
//
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://beautycita.com",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Verify this is called by cron or has service-role auth
  const authHeader = req.headers.get("authorization") ?? "";
  const cronSecret = Deno.env.get("CRON_SECRET") ?? "";

  // Verify cron secret or service-role key (NOT spoofable includes check)
  const isValidCron = cronSecret && authHeader === `Bearer ${cronSecret}`;
  const isServiceRole = authHeader === `Bearer ${SUPABASE_SERVICE_KEY}`;
  if (!isValidCron && !isServiceRole) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const now = new Date();
  const twoHoursFromNow = new Date(now.getTime() + 2 * 60 * 60 * 1000);

  try {
    // -------------------------------------------------------------------
    // 1. Find appointments starting within the next 2 hours that
    //    are pending/confirmed and haven't been reminded yet
    // -------------------------------------------------------------------
    const { data: appointments, error: queryErr } = await supabase
      .from("appointments")
      .select(`
        id,
        user_id,
        business_id,
        service_name,
        starts_at,
        businesses!appointments_business_id_fkey (
          name
        )
      `)
      .gte("starts_at", now.toISOString())
      .lte("starts_at", twoHoursFromNow.toISOString())
      .in("status", ["pending", "confirmed"])
      .is("reminded_at", null)
      .limit(200);

    if (queryErr) {
      console.error("[REMINDER] Query error:", queryErr);
      return json({ error: queryErr.message }, 500);
    }

    if (!appointments || appointments.length === 0) {
      console.log("[REMINDER] No appointments to remind");
      return json({ processed: 0, sent: 0, failed: 0 });
    }

    console.log(`[REMINDER] Found ${appointments.length} appointments to remind`);

    let sent = 0;
    let failed = 0;

    for (const appt of appointments) {
      const startsAt = new Date(appt.starts_at);
      const diffMs = startsAt.getTime() - now.getTime();
      const diffMin = Math.round(diffMs / (1000 * 60));

      const business = appt.businesses as unknown as { name: string } | null;
      const salonName = business?.name ?? "tu salon";

      // Build human-readable time-until string
      let timeStr: string;
      if (diffMin <= 60) {
        timeStr = `${diffMin}min`;
      } else {
        const hours = Math.floor(diffMin / 60);
        const mins = diffMin % 60;
        timeStr = mins > 0 ? `${hours}h ${mins}min` : `${hours}h`;
      }

      const reminderBody = `Tu cita de ${appt.service_name} es en ${timeStr}. ${salonName}`;

      // -------------------------------------------------------------------
      // 2. Send push notification via send-push-notification function
      // -------------------------------------------------------------------
      try {
        const pushRes = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            booking_id: appt.id,
            user_id: appt.user_id,
            notification_type: "booking_reminder",
            custom_title: "Recordatorio de Cita",
            custom_body: reminderBody,
            data: {
              type: "booking_reminder",
              booking_id: appt.id,
            },
          }),
        });

        if (pushRes.ok) {
          // -------------------------------------------------------------------
          // 3. Update reminded_at on the appointment
          // -------------------------------------------------------------------
          const { error: updateErr } = await supabase
            .from("appointments")
            .update({ reminded_at: now.toISOString() })
            .eq("id", appt.id);

          if (updateErr) {
            console.error(`[REMINDER] Failed to update reminded_at for ${appt.id}:`, updateErr);
          }

          sent++;
          console.log(`[REMINDER] Sent reminder for ${appt.id} — ${appt.service_name} in ${timeStr}`);
        } else {
          failed++;
          console.error(`[REMINDER] Push failed for ${appt.id}: ${await pushRes.text()}`);
        }
      } catch (pushErr) {
        failed++;
        console.error(`[REMINDER] Push error for ${appt.id}:`, pushErr);
      }
    }

    console.log(`[REMINDER] Done: ${sent} sent, ${failed} failed out of ${appointments.length}`);

    return json({
      processed: appointments.length,
      sent,
      failed,
    });
  } catch (err) {
    console.error("[REMINDER] Handler error:", (err as Error).message);
    return json({ error: "Internal server error" }, 500);
  }
});
