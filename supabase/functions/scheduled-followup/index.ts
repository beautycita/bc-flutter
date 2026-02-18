// scheduled-followup edge function
// Called by pg_cron to send follow-up reminders to discovered salons.
// Runs daily at 10am Mexico City time.
//
// Follow-up rules:
// 1. Salon was first selected 24-48h ago (first reminder)
// 2. Salon was selected 7 days ago (weekly reminder)
// 3. Salon hasn't signed up yet (status != 'registered')
// 4. Salon hasn't reached max outreach attempts
// 5. Respects 48h minimum between messages

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const TWILIO_ACCOUNT_SID = Deno.env.get("TWILIO_ACCOUNT_SID") ?? "";
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN") ?? "";
const TWILIO_WHATSAPP_FROM = Deno.env.get("TWILIO_WHATSAPP_FROM") ?? "";

const MAX_OUTREACH_ATTEMPTS = 10;
const MIN_HOURS_BETWEEN_MESSAGES = 48;

// Follow-up message templates (Spanish)
const FOLLOWUP_MESSAGES = {
  first_24h: `Hola {{name}}! Ayer una clienta quiso reservar contigo en BeautyCita. ¿Ya viste el mensaje? Regístrate gratis en 60 seg y empieza a recibir reservas: {{link}}`,
  weekly: `{{name}}, esta semana {{count}} clientas te buscaron en BeautyCita. No pierdas más reservas. Es gratis y toma 60 seg: {{link}}`,
  reminder: `{{name}}, tienes {{count}} clientas esperando poder reservar contigo. BeautyCita es gratis para ti. Regístrate: {{link}}`,
};

// ---------------------------------------------------------------------------
// Email fallback via send-email edge function
// ---------------------------------------------------------------------------
async function sendPromotionEmail(
  salonName: string,
  email: string,
  interestCount: number,
  salonLink: string
): Promise<boolean> {
  try {
    const resp = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        template: "promotion",
        to: email,
        subject: `${interestCount} clientas te buscan en BeautyCita`,
        variables: {
          PROMO_TITLE: `${interestCount} clientas te buscan`,
          PROMO_PREHEADER: `${salonName}, no pierdas mas reservas`,
          PROMO_AMOUNT: "GRATIS",
          PROMO_SUBTITLE: "Registro en 60 segundos",
          PROMO_DESCRIPTION: `${salonName}, ${interestCount} clientas intentaron reservar contigo en BeautyCita esta semana. Registrate gratis y empieza a recibir reservas hoy mismo.`,
          PROMO_CODE: "",
          PROMO_CTA_URL: salonLink,
          PROMO_CTA_TEXT: "REGISTRARME GRATIS",
          PROMO_EXPIRY: "",
          UNSUBSCRIBE_URL: `${salonLink}?unsub=1`,
        },
      }),
    });
    if (!resp.ok) {
      console.error(`[EMAIL-FOLLOWUP] Failed: ${await resp.text()}`);
      return false;
    }
    console.log(`[EMAIL-FOLLOWUP] Sent promotion to ${email}`);
    return true;
  } catch (err) {
    console.error(`[EMAIL-FOLLOWUP] Error:`, err);
    return false;
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

async function sendWhatsApp(to: string, body: string): Promise<boolean> {
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_WHATSAPP_FROM) {
    console.log(`[TWILIO-DISABLED] Would send to ${to}: ${body}`);
    return false;
  }

  const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      From: `whatsapp:${TWILIO_WHATSAPP_FROM}`,
      To: `whatsapp:${to}`,
      Body: body,
    }),
  });

  if (!resp.ok) {
    const err = await resp.text();
    console.error(`[TWILIO-ERROR] ${resp.status}: ${err}`);
    return false;
  }

  return true;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type, apikey",
      },
    });
  }

  // Verify this is called by a cron job or has admin auth
  const authHeader = req.headers.get("authorization") ?? "";
  const cronSecret = Deno.env.get("CRON_SECRET") ?? "";

  if (authHeader !== `Bearer ${cronSecret}` && !authHeader.includes("supabase")) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  const now = new Date();
  const nowISO = now.toISOString();

  try {
    // Find salons needing follow-up
    // Conditions:
    // - Has been selected (first_selected_at is not null)
    // - Not registered yet
    // - Hasn't reached max outreach attempts
    // - Last outreach was at least 48h ago (or never)

    const cutoff48h = new Date(now.getTime() - 48 * 60 * 60 * 1000).toISOString();
    const cutoff24h = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
    const cutoff7d = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();

    const { data: candidates, error } = await supabase
      .from("discovered_salons")
      .select("*")
      .not("first_selected_at", "is", null)
      .not("status", "eq", "registered")
      .not("status", "eq", "declined")
      .not("status", "eq", "unreachable")
      .lt("outreach_count", MAX_OUTREACH_ATTEMPTS)
      .or(`last_outreach_at.is.null,last_outreach_at.lt.${cutoff48h}`)
      .limit(100);

    if (error) {
      console.error("Query error:", error);
      return json({ error: error.message }, 500);
    }

    const sent: string[] = [];
    const skipped: string[] = [];
    const failed: string[] = [];

    for (const salon of candidates ?? []) {
      // Need either phone or email to reach this salon
      const phone = salon.whatsapp || salon.phone;
      const email = salon.email;
      if (!phone && !email) {
        skipped.push(`${salon.business_name}: no phone or email`);
        continue;
      }

      // Determine message type based on timing
      let messageTemplate: string;
      const firstSelectedAt = new Date(salon.first_selected_at);
      const hoursSinceFirstSelected = (now.getTime() - firstSelectedAt.getTime()) / (1000 * 60 * 60);

      if (hoursSinceFirstSelected >= 24 && hoursSinceFirstSelected < 48 && (salon.outreach_count ?? 0) < 2) {
        // First 24h follow-up
        messageTemplate = FOLLOWUP_MESSAGES.first_24h;
      } else if (hoursSinceFirstSelected >= 7 * 24) {
        // Weekly reminder
        messageTemplate = FOLLOWUP_MESSAGES.weekly;
      } else if ((salon.interest_count ?? 0) >= 3) {
        // Generic reminder for high-interest salons
        messageTemplate = FOLLOWUP_MESSAGES.reminder;
      } else {
        skipped.push(`${salon.business_name}: doesn't meet criteria`);
        continue;
      }

      // Build message
      const link = `https://beautycita.com/salon/${salon.id}`;
      const message = messageTemplate
        .replace("{{name}}", salon.business_name)
        .replace("{{link}}", link)
        .replace("{{count}}", String(salon.interest_count ?? 1));

      // Send via WhatsApp (preferred) or email (fallback)
      let success = false;
      let channel = "whatsapp";

      if (phone) {
        success = await sendWhatsApp(phone, message);
        if (!success && !TWILIO_ACCOUNT_SID) success = true; // Twilio disabled = dry run
      }

      // Fallback to email if WhatsApp failed or no phone
      if (!success && email) {
        success = await sendPromotionEmail(
          salon.business_name,
          email,
          salon.interest_count ?? 1,
          link
        );
        channel = "email";
      }

      if (success) {
        await supabase
          .from("discovered_salons")
          .update({
            last_outreach_at: nowISO,
            outreach_count: (salon.outreach_count ?? 0) + 1,
            outreach_channel: channel,
            status: "outreach_sent",
          })
          .eq("id", salon.id);

        sent.push(salon.business_name);
        console.log(`[FOLLOWUP] Sent to ${salon.business_name} via ${channel}`);
      } else {
        failed.push(salon.business_name);
      }
    }

    return json({
      processed: (candidates ?? []).length,
      sent: sent.length,
      skipped: skipped.length,
      failed: failed.length,
      details: { sent, skipped: skipped.slice(0, 10), failed },
    });
  } catch (err) {
    console.error("scheduled-followup error:", err);
    return json({ error: String(err) }, 500);
  }
});
