/**
 * phone-verify — Send & verify OTP codes via WhatsApp (beautypi).
 *
 * Actions:
 *   send-code   { phone: "+52..." }  — Generate OTP, send via WhatsApp
 *   verify-code { phone: "+52...", code: "123456" }  — Verify OTP, mark profile verified
 *
 * Env vars:
 *   BEAUTYPI_WA_URL       — e.g. http://100.93.1.103:3200
 *   BEAUTYPI_WA_TOKEN     — Bearer token for WA API
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendInfobipWhatsApp } from "../_shared/infobip.ts";

async function hashOtp(otp: string): Promise<string> {
  const data = new TextEncoder().encode(otp);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, "0")).join("");
}

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

const corsHeaders = (req: Request) => ({
  "Access-Control-Allow-Origin": corsOrigin(req),
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
});

const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const TWILIO_ACCOUNT_SID = Deno.env.get("TWILIO_ACCOUNT_SID") ?? "";
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN") ?? "";
const TWILIO_VERIFY_SID = Deno.env.get("TWILIO_VERIFY_SID") ?? "";
const OTP_EXPIRY_MINUTES = 10;
const MAX_ATTEMPTS = 3;

let _req: Request;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

function generateOtp(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  return String(array[0] % 1000000).padStart(6, "0");
}

/** Send OTP via beautypi WhatsApp API (25s timeout per step) */
async function sendWhatsApp(phone: string, code: string): Promise<{ sent: boolean; channel: string }> {
  if (!BEAUTYPI_WA_URL) return { sent: false, channel: "whatsapp" };
  try {
    const ac1 = new AbortController();
    const t1 = setTimeout(() => ac1.abort(), 25000);
    const checkRes = await fetch(`${BEAUTYPI_WA_URL}/api/wa/check`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone }),
      signal: ac1.signal,
    });
    clearTimeout(t1);

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

    const ac2 = new AbortController();
    const t2 = setTimeout(() => ac2.abort(), 25000);
    const sendRes = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
      signal: ac2.signal,
    });
    clearTimeout(t2);

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


Deno.serve(async (req) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {

  // Auth
  const authHeader = req.headers.get("authorization") || "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  console.log("[phone-verify] Request received");

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser();

  if (authError || !user) {
    console.log(`[phone-verify] Auth failed: ${authError?.message ?? "no user"}`);
    return json({ error: "Not authenticated" }, 401);
  }

  console.log(`[phone-verify] User ${user.id}, parsing body...`);
  const db = createClient(supabaseUrl, serviceKey);
  const { action, phone, code } = await req.json();
  console.log(`[phone-verify] Action: ${action}, phone: ${phone ? phone.slice(0, 6) + "***" : "none"}`);

  // ─── SEND CODE ──────────────────────────────────────────────
  if (action === "send-code") {
    if (!phone || typeof phone !== "string" || phone.length < 10) {
      return json({ error: "Valid phone number required" }, 400);
    }

    // Rate limit: max 3 pending (unverified) codes per phone in 15 minutes.
    // Only count codes the user hasn't successfully consumed — otherwise a
    // user who verifies once and needs to re-send (e.g. changed phone, then
    // returned) would be locked out for the rest of the 15-min window.
    const { count } = await db
      .from("phone_verification_codes")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)
      .eq("phone", phone)
      .eq("verified", false)
      .gte("created_at", new Date(Date.now() - 15 * 60 * 1000).toISOString());

    console.log(`[phone-verify] Rate limit check: ${count ?? 0} codes in 15min`);
    if ((count || 0) >= 3) {
      return json({ error: "Demasiados intentos. Espera 15 minutos." }, 429);
    }

    // Generate OTP upfront — same code for all channels (no Twilio Verify, use our code everywhere)
    const otp = generateOtp();

    // Check for recent send to this phone (dedup: if we sent in last 60s, don't send again)
    const { data: recentSend } = await db
      .from("phone_verification_codes")
      .select("id, channel, created_at")
      .eq("phone", phone)
      .eq("verified", false)
      .gte("created_at", new Date(Date.now() - 60 * 1000).toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (recentSend) {
      console.log(`[phone-verify] Dedup: already sent to ${phone.slice(0, 6)}*** ${Math.round((Date.now() - new Date(recentSend.created_at).getTime()) / 1000)}s ago via ${recentSend.channel}`);
      return json({ sent: true, channel: recentSend.channel, expires_in: OTP_EXPIRY_MINUTES * 60, deduplicated: true });
    }

    // Channel preference: Infobip (whitelisted phones only) → bpi WA → Twilio SMS.
    // Infobip is sandbox until prod sender registered; whitelist gates exposure.
    let result: { sent: boolean; channel: string };
    const otpBody = `BeautyCita - Tu codigo es: ${otp}\nValido por ${OTP_EXPIRY_MINUTES} min. No lo compartas.`;
    const infobipResult = await sendInfobipWhatsApp(phone, otpBody);
    if (infobipResult.sent) {
      console.log(`[phone-verify] OTP sent via Infobip WA to ${phone.slice(0, 6)}***`);
      result = { sent: true, channel: "infobip-wa" };
    } else {
      if (infobipResult.reason && infobipResult.reason !== "not_whitelisted" && infobipResult.reason !== "not_configured") {
        console.warn(`[phone-verify] Infobip skipped (${infobipResult.reason}); falling back`);
      }
      console.log(`[phone-verify] Trying bpi WhatsApp for ${phone.slice(0, 6)}***`);
      result = await sendWhatsApp(phone, otp);
    }

    // If WA failed, fall back to Twilio Programmable SMS (NOT Twilio Verify — we send our OWN code)
    if (!result.sent && TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN) {
      console.log(`[phone-verify] WA failed for ${phone.slice(0, 6)}***, falling back to SMS with same OTP`);
      try {
        // Use Twilio Programmable SMS (Messages API) — NOT Verify — so we control the code
        const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
        const auth = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);
        const toNumber = phone.startsWith("+") ? phone : `+${phone}`;
        const smsRes = await fetch(url, {
          method: "POST",
          headers: { Authorization: `Basic ${auth}`, "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            To: toNumber,
            From: Deno.env.get("TWILIO_FROM_NUMBER") ?? "+15005550006",
            Body: `BeautyCita - Tu codigo de verificacion es: ${otp}\n\nValido por ${OTP_EXPIRY_MINUTES} minutos. No compartas este codigo.`,
          }),
        });
        if (smsRes.ok) {
          result = { sent: true, channel: "sms" };
          console.log(`[phone-verify] OTP sent via SMS to ${phone.slice(0, 6)}***`);
        } else {
          const err = await smsRes.text();
          console.error(`[phone-verify] SMS also failed: ${err}`);
          return json({ error: "No se pudo enviar el codigo. Intenta de nuevo." }, 500);
        }
      } catch (e) {
        console.error(`[phone-verify] SMS error: ${e}`);
        return json({ error: "No se pudo enviar el codigo. Intenta de nuevo." }, 500);
      }
    } else if (!result.sent) {
      return json({ error: "No se pudo enviar el codigo. Intenta de nuevo." }, 500);
    }

    // Store OTP in DB — same code for both channels now (no more TWILIO_MANAGED)
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
    await db.from("phone_verification_codes").insert({
      user_id: user.id,
      phone,
      code: await hashOtp(otp),
      channel: result.channel,
      expires_at: expiresAt,
    });

    console.log(`[phone-verify] OTP sent via ${result.channel} to ${phone.slice(0, 6)}***`);
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

    // Direct code comparison — same code for all channels (WA and SMS)
    const verified = record.code === await hashOtp(code);

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

    // Check if a business matches this phone (for admin visibility only — NO auto-transfer)
    const digits = phone.replace(/[^\d]/g, "");
    const last10 = digits.length >= 10 ? digits.slice(-10) : digits;
    let businessMatch = null;

    if (last10.length === 10) {
      const { data: existingBiz } = await db
        .from("businesses")
        .select("id, name")
        .or(`phone.ilike.%${last10}`)
        .neq("owner_id", user.id)
        .limit(1)
        .maybeSingle();

      if (existingBiz) {
        businessMatch = { id: existingBiz.id, name: existingBiz.name };
        console.log(`[phone-verify] Business match found: "${existingBiz.name}" — flagged for manual review (no auto-transfer)`);
      }
    }

    return json({ verified: true, business_match: businessMatch });
  }

  return json({ error: `Unknown action: ${action}` }, 400);

  } catch (e) {
    console.error(`[phone-verify] Unhandled error: ${e}`);
    return json({ error: "Internal server error" }, 500);
  }
});
