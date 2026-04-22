// =============================================================================
// stylist-appointment-reminder — T-5min nudge to the stylist (or salon)
// =============================================================================
// Cron: every 2 minutes. Finds appointments where starts_at is 3-7 min from
// now and stylist_reminded_at IS NULL. For each, sends:
//   1. Sticky push notification (if staff.user_id → profile.fcm_token) —
//      Android ongoing:true, iOS time-sensitive interruption-level
//   2. WhatsApp to staff.phone if set
//   3. WhatsApp to businesses.whatsapp if stylist has no phone
// Records stylist_reminded_at to dedupe.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { sendWhatsAppWithRetry } from "../_shared/wa_queue.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GOOGLE_SA_JSON = Deno.env.get("GOOGLE_SERVICE_ACCOUNT") ?? "";

let _req: Request | undefined;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req!), "Content-Type": "application/json" },
  });
}

// ── FCM direct send with sticky params ─────────────────────────────────────
// Not using send-push-notification because we need:
//   Android: ongoing:true + importance HIGH so it persists until dismissed
//   iOS: interruption-level time-sensitive + sound
// send-push-notification's helper doesn't expose these toggles; inline is
// cleaner than expanding that helper and risking regressions elsewhere.
async function getFcmAccessToken(): Promise<string | null> {
  if (!GOOGLE_SA_JSON) return null;
  try {
    const sa = JSON.parse(GOOGLE_SA_JSON);
    const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
      .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
    const now = Math.floor(Date.now() / 1000);
    const claim = btoa(JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    })).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
    const unsigned = `${header}.${claim}`;

    const pemHeader = "-----BEGIN PRIVATE KEY-----";
    const pemFooter = "-----END PRIVATE KEY-----";
    const pemContents = sa.private_key
      .replace(pemHeader, "").replace(pemFooter, "").replace(/\s/g, "");
    const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
    const key = await crypto.subtle.importKey(
      "pkcs8", binaryDer, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false, ["sign"],
    );
    const sig = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned),
    );
    const signature = btoa(String.fromCharCode(...new Uint8Array(sig)))
      .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
    const jwt = `${unsigned}.${signature}`;

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
    });
    const tokenData = await tokenRes.json();
    return tokenData.access_token ?? null;
  } catch (e) {
    console.error("[STYLIST-REMIND] FCM token error:", e);
    return null;
  }
}

async function sendStickyPush(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<boolean> {
  const accessToken = await getFcmAccessToken();
  if (!accessToken) return false;
  try {
    const projectId = JSON.parse(GOOGLE_SA_JSON).project_id;
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: { title, body },
            android: {
              priority: "HIGH",
              notification: {
                sound: "beautycita_notify",
                channel_id: "stylist_alerts",
                // Sticky: stays in the shade until dismissed
                notification_priority: "PRIORITY_MAX",
                visibility: "PUBLIC",
                sticky: true,
              },
            },
            apns: {
              headers: {
                // Time-sensitive: delivered even in Focus/DND, stays visible
                "apns-priority": "10",
                "apns-push-type": "alert",
              },
              payload: {
                aps: {
                  alert: { title, body },
                  sound: "default",
                  badge: 1,
                  "interruption-level": "time-sensitive",
                  "relevance-score": 1.0,
                },
              },
            },
            data,
          },
        }),
      },
    );
    if (!res.ok) {
      const err = await res.text();
      console.error("[STYLIST-REMIND] FCM failed:", res.status, err);
      return false;
    }
    return true;
  } catch (e) {
    console.error("[STYLIST-REMIND] FCM error:", e);
    return false;
  }
}

serve(async (req) => {
  _req = req;
  const pre = handleCorsPreflightIfOptions(req);
  if (pre) return pre;

  // Auth: CRON_SECRET OR service-role key
  const authHeader = req.headers.get("authorization") ?? "";
  const cronSecret = Deno.env.get("CRON_SECRET") ?? "";
  const isValidCron = cronSecret && authHeader === `Bearer ${cronSecret}`;
  const isServiceRole = authHeader === `Bearer ${SERVICE_KEY}`;
  if (!isValidCron && !isServiceRole) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
  const now = new Date();
  const windowStart = new Date(now.getTime() + 3 * 60 * 1000).toISOString(); // T+3 min
  const windowEnd = new Date(now.getTime() + 7 * 60 * 1000).toISOString();   // T+7 min

  // Query appointments needing a stylist reminder in the next 3-7 minutes.
  // staff:staff(...) and businesses:businesses(...) embed for fallback data.
  const { data: appts, error } = await supabase
    .from("appointments")
    .select(`
      id, starts_at, service_name, status, staff_id, business_id,
      staff:staff_id (
        id, first_name, last_name, phone, user_id,
        upload_qr_token, upload_pin
      ),
      businesses:business_id (
        id, name, whatsapp, phone
      )
    `)
    .gte("starts_at", windowStart)
    .lte("starts_at", windowEnd)
    .is("stylist_reminded_at", null)
    .not("status", "in", "(cancelled,completed,no_show)")
    .limit(200);

  if (error) {
    console.error("[STYLIST-REMIND] Query error:", error.message);
    return json({ error: "Query failed" }, 500);
  }

  if (!appts || appts.length === 0) {
    return json({ processed: 0, reminded: 0 }, 200);
  }

  let reminded = 0;
  let pushSent = 0;
  let waSent = 0;
  let waQueued = 0;
  let noChannel = 0;

  for (const appt of appts as Array<{
    id: string;
    starts_at: string;
    service_name: string | null;
    staff_id: string | null;
    business_id: string;
    staff: {
      id: string;
      first_name: string | null;
      last_name: string | null;
      phone: string | null;
      user_id: string | null;
      upload_qr_token: string | null;
      upload_pin: string | null;
    } | null;
    businesses: {
      id: string;
      name: string | null;
      whatsapp: string | null;
      phone: string | null;
    } | null;
  }>) {
    const salonName = appt.businesses?.name ?? "tu salón";
    const stylistName = appt.staff
      ? `${appt.staff.first_name ?? ""} ${appt.staff.last_name ?? ""}`.trim()
      : "Equipo";
    const service = appt.service_name ?? "servicio";
    const qrToken = appt.staff?.upload_qr_token;
    const uploadLink = qrToken
      ? `https://beautycita.com/portfolio-upload.html?token=${qrToken}`
      : null;

    const pushTitle = `${stylistName}, tu cita empieza en 5 min`;
    const pushBody = `${service} — ${salonName}. Pide autorización al cliente para foto antes/después y abre tu QR.`;
    const waMessage =
      `⏰ *Cita en 5 minutos — ${salonName}*\n\n` +
      `Hola ${stylistName}, tu cita de *${service}* empieza pronto.\n\n` +
      `📸 Recuerda pedir autorización al cliente para la foto *antes / después*.\n` +
      (uploadLink
        ? `Escanea tu QR o abre este enlace:\n${uploadLink}\nPIN: ${appt.staff?.upload_pin ?? "----"}`
        : "Abre tu QR del panel para subir fotos.");

    // 1. Push to the linked profile if we have one + a fresh fcm_token
    let didPush = false;
    if (appt.staff?.user_id) {
      const { data: prof } = await supabase
        .from("profiles")
        .select("fcm_token")
        .eq("id", appt.staff.user_id)
        .maybeSingle();
      const fcm = prof?.fcm_token as string | null | undefined;
      if (fcm) {
        didPush = await sendStickyPush(fcm, pushTitle, pushBody, {
          type: "stylist_appointment_reminder",
          appointment_id: appt.id,
          staff_id: appt.staff_id ?? "",
          upload_url: uploadLink ?? "",
        });
        if (didPush) pushSent++;
      }
    }

    // 2. WA: stylist phone → salon phone fallback
    const waTarget = appt.staff?.phone || appt.businesses?.whatsapp || appt.businesses?.phone;
    let didWa = false;
    let queuedWa = false;
    if (waTarget) {
      const result = await sendWhatsAppWithRetry(supabase, waTarget, waMessage, {
        kind: "stylist_appointment_reminder",
        appointment_id: appt.id,
      });
      didWa = result.sent;
      queuedWa = result.queued;
      if (didWa) waSent++;
      if (queuedWa) waQueued++;
    }

    if (!didPush && !waTarget) {
      noChannel++;
      console.warn(`[STYLIST-REMIND] No reachable channel for appt ${appt.id}`);
    }

    // Dedupe marker. Mark even if every channel failed — better a missed
    // nudge than a stuck appointment firing again every 2 min.
    await supabase
      .from("appointments")
      .update({ stylist_reminded_at: now.toISOString() })
      .eq("id", appt.id);
    reminded++;
  }

  console.log(
    `[STYLIST-REMIND] ${reminded} appts processed · push=${pushSent} wa=${waSent} queued=${waQueued} no_channel=${noChannel}`,
  );
  return json({
    processed: appts.length,
    reminded,
    push_sent: pushSent,
    wa_sent: waSent,
    wa_queued: waQueued,
    no_channel: noChannel,
  }, 200);
});
