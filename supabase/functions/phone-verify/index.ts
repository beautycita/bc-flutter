/**
 * phone-verify — Send & verify OTP codes via WhatsApp (beautypi) or Twilio Verify (SMS fallback).
 *
 * Actions:
 *   send-code   { phone: "+52..." }  — Generate OTP, send via WA; fallback to Twilio Verify SMS
 *   verify-code { phone: "+52...", code: "123456" }  — Verify OTP, mark profile verified
 *
 * Priority: WhatsApp (beautypi) → Twilio Verify (SMS)
 *
 * Env vars:
 *   BEAUTYPI_WA_URL       — e.g. http://100.93.1.103:3200
 *   BEAUTYPI_WA_TOKEN     — Bearer token for WA API
 *   TWILIO_ACCOUNT_SID    — Twilio account SID (for Verify fallback)
 *   TWILIO_AUTH_TOKEN      — Twilio auth token
 *   TWILIO_VERIFY_SID     — Twilio Verify service SID
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") || "http://100.93.1.103:3200";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") || "bc-wa-api-2026";
const TWILIO_ACCOUNT_SID = Deno.env.get("TWILIO_ACCOUNT_SID") || "";
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN") || "";
const TWILIO_VERIFY_SID = Deno.env.get("TWILIO_VERIFY_SID") || "";
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

/** Start Twilio Verify SMS verification */
async function twilioVerifySend(phone: string): Promise<{ sent: boolean; channel: string }> {
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_VERIFY_SID) {
    console.log("[TWILIO-VERIFY] Not configured");
    return { sent: false, channel: "sms" };
  }

  try {
    const url = `https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SID}/Verifications`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: phone, Channel: "sms" }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error(`[TWILIO-VERIFY] Send error ${res.status}: ${err}`);
      return { sent: false, channel: "sms" };
    }

    console.log(`[TWILIO-VERIFY] OTP sent to ${phone}`);
    return { sent: true, channel: "sms" };
  } catch (e) {
    console.error(`[TWILIO-VERIFY] Error: ${e}`);
    return { sent: false, channel: "sms" };
  }
}

/** Check Twilio Verify code */
async function twilioVerifyCheck(phone: string, code: string): Promise<boolean> {
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_VERIFY_SID) {
    return false;
  }

  try {
    const url = `https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SID}/VerificationCheck`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: phone, Code: code }),
    });

    if (!res.ok) return false;
    const data = await res.json();
    return data.status === "approved";
  } catch (e) {
    console.error(`[TWILIO-VERIFY] Check error: ${e}`);
    return false;
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

    // Try WhatsApp first — generate OTP upfront so we send the real code in one shot
    const otp = generateOtp();
    let result = await sendWhatsApp(phone, otp);

    if (result.sent) {
      // WA succeeded — store our OTP in DB
      const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000).toISOString();

      await db.from("phone_verification_codes").insert({
        user_id: user.id,
        phone,
        code: otp,
        channel: "whatsapp",
        expires_at: expiresAt,
      });

      result = { sent: true, channel: "whatsapp" };
    } else {
      // WA failed — fallback to Twilio Verify (manages its own OTP)
      result = await twilioVerifySend(phone);

      if (result.sent) {
        // Store a marker row so verify-code knows to use Twilio Verify
        const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000).toISOString();
        await db.from("phone_verification_codes").insert({
          user_id: user.id,
          phone,
          code: "__TWILIO_VERIFY__",
          channel: "sms",
          expires_at: expiresAt,
        });
      }
    }

    if (!result.sent) {
      return json({ error: "No se pudo enviar el codigo. Intenta mas tarde." }, 500);
    }

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

    let verified = false;

    if (record.code === "__TWILIO_VERIFY__") {
      // This was sent via Twilio Verify — check with Twilio
      verified = await twilioVerifyCheck(phone, code);
    } else {
      // This was sent via WhatsApp — check our own OTP
      verified = record.code === code;
    }

    if (!verified) {
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
