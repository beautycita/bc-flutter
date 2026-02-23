/**
 * phone-verify — Send & verify OTP codes via WhatsApp (beautypi) or SMS (Twilio).
 *
 * Actions:
 *   send-code   { phone: "+52..." }  — Generate 6-digit OTP, send via WA, fallback SMS
 *   verify-code { phone: "+52...", code: "123456" }  — Verify OTP, mark profile verified
 *
 * Env vars:
 *   BEAUTYPI_WA_URL   — e.g. http://beautypi:3200
 *   BEAUTYPI_WA_TOKEN — Bearer token for WA API
 *   TWILIO_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE — SMS fallback
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") || "http://100.93.1.103:3200";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") || "bc-wa-api-2026";
const TWILIO_SID = Deno.env.get("TWILIO_SID") || "";
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN") || "";
const TWILIO_PHONE = Deno.env.get("TWILIO_PHONE") || "";
const OTP_EXPIRY_MINUTES = 5;
const MAX_ATTEMPTS = 3;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function generateOtp(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  return String(array[0] % 1000000).padStart(6, "0");
}

/** Send OTP via beautypi WhatsApp API */
async function sendWhatsApp(phone: string, code: string): Promise<{ sent: boolean; channel: string }> {
  try {
    // First check if number is on WhatsApp
    const checkRes = await fetch(`${BEAUTYPI_WA_URL}/api/wa/check`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone }),
    });

    if (!checkRes.ok) {
      console.log(`[WA] Check failed: ${checkRes.status}`);
      return { sent: false, channel: "whatsapp" };
    }

    const checkData = await checkRes.json();
    if (!checkData.onWhatsApp) {
      console.log(`[WA] ${phone} not on WhatsApp`);
      return { sent: false, channel: "whatsapp" };
    }

    // Send the verification message
    const message = `*BeautyCita* - Tu codigo de verificacion es: *${code}*\n\nValido por ${OTP_EXPIRY_MINUTES} minutos. No compartas este codigo.`;

    const sendRes = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
    });

    if (!sendRes.ok) {
      console.log(`[WA] Send failed: ${sendRes.status}`);
      return { sent: false, channel: "whatsapp" };
    }

    const sendData = await sendRes.json();
    return { sent: sendData.sent === true, channel: "whatsapp" };
  } catch (e) {
    console.error(`[WA] Error: ${e}`);
    return { sent: false, channel: "whatsapp" };
  }
}

/** Send OTP via Twilio SMS */
async function sendSms(phone: string, code: string): Promise<{ sent: boolean; channel: string }> {
  if (!TWILIO_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE) {
    console.log("[SMS] Twilio not configured");
    return { sent: false, channel: "sms" };
  }

  try {
    const body = new URLSearchParams({
      To: phone,
      From: TWILIO_PHONE,
      Body: `BeautyCita: Tu codigo de verificacion es ${code}. Valido por ${OTP_EXPIRY_MINUTES} minutos.`,
    });

    const res = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_SID}/Messages.json`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${btoa(`${TWILIO_SID}:${TWILIO_AUTH_TOKEN}`)}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: body.toString(),
      }
    );

    if (!res.ok) {
      const err = await res.text();
      console.error(`[SMS] Twilio error: ${err}`);
      return { sent: false, channel: "sms" };
    }

    return { sent: true, channel: "sms" };
  } catch (e) {
    console.error(`[SMS] Error: ${e}`);
    return { sent: false, channel: "sms" };
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Auth
  const authHeader = req.headers.get("authorization") || "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // User client (to get user ID)
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser();

  if (authError || !user) {
    return json({ error: "Not authenticated" }, 401);
  }

  // Service client (for DB operations)
  const db = createClient(supabaseUrl, serviceKey);

  const { action, phone, code } = await req.json();

  // ─── SEND CODE ──────────────────────────────────────────────
  if (action === "send-code") {
    if (!phone || typeof phone !== "string" || phone.length < 10) {
      return json({ error: "Valid phone number required" }, 400);
    }

    // Rate limit: max 3 codes per phone in 15 minutes
    const { count } = await db
      .from("phone_verification_codes")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("phone", phone)
      .gte("created_at", new Date(Date.now() - 15 * 60 * 1000).toISOString());

    if ((count || 0) >= 3) {
      return json({ error: "Demasiados intentos. Espera 15 minutos." }, 429);
    }

    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000).toISOString();

    // Try WhatsApp first, then SMS
    let result = await sendWhatsApp(phone, otp);
    if (!result.sent) {
      result = await sendSms(phone, otp);
    }

    if (!result.sent) {
      return json({ error: "No se pudo enviar el codigo. Intenta mas tarde." }, 500);
    }

    // Store OTP
    await db.from("phone_verification_codes").insert({
      user_id: user.id,
      phone,
      code: otp,
      channel: result.channel,
      expires_at: expiresAt,
    });

    return json({
      sent: true,
      channel: result.channel,
      expires_in: OTP_EXPIRY_MINUTES * 60,
    });
  }

  // ─── VERIFY CODE ────────────────────────────────────────────
  if (action === "verify-code") {
    if (!phone || !code) {
      return json({ error: "phone and code required" }, 400);
    }

    // Get latest unexpired, unverified code for this user+phone
    const { data: record } = await db
      .from("phone_verification_codes")
      .select("*")
      .eq("user_id", user.id)
      .eq("phone", phone)
      .eq("verified", false)
      .gte("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .single();

    if (!record) {
      return json({ error: "Codigo expirado o no encontrado. Solicita uno nuevo." }, 400);
    }

    if (record.attempts >= MAX_ATTEMPTS) {
      return json({ error: "Demasiados intentos. Solicita un nuevo codigo." }, 400);
    }

    // Increment attempts
    await db
      .from("phone_verification_codes")
      .update({ attempts: record.attempts + 1 })
      .eq("id", record.id);

    if (record.code !== code) {
      return json({ error: "Codigo incorrecto", remaining: MAX_ATTEMPTS - record.attempts - 1 }, 400);
    }

    // Mark verified
    await db
      .from("phone_verification_codes")
      .update({ verified: true, verified_at: new Date().toISOString() })
      .eq("id", record.id);

    // Update user profile
    await db
      .from("profiles")
      .update({
        phone,
        phone_verified: true,
        phone_verified_at: new Date().toISOString(),
      })
      .eq("id", user.id);

    return json({ verified: true });
  }

  return json({ error: `Unknown action: ${action}` }, 400);
});
