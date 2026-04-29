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
import { enqueueWa, WA_PRIORITY } from "../_shared/wa_queue.ts";

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

/** Send OTP via the WA server's fast-path endpoint.
 *
 * OTPs MUST arrive in seconds — they're useless after a minute. So we
 * skip the global wa_message_queue (which paces everything at 45s and
 * drains via a 1-min cron) and call the WA server's `/api/wa/send-otp`
 * directly. That endpoint enforces its own narrower OTP-only safeguards
 * (30s per-recipient cooldown, global daily cap, idempotency dedup) so
 * the line stays protected even though it's bypassing the queue.
 *
 * If the fast-path fails for any reason, we fall back to the queue with
 * CRITICAL priority so the OTP still has a chance to arrive (slowly).
 */
async function sendWhatsApp(phone: string, code: string): Promise<{ sent: boolean; channel: string }> {
  if (!BEAUTYPI_WA_URL) return { sent: false, channel: "whatsapp" };
  const message = `*BeautyCita* - Tu codigo de verificacion es: *${code}*\n\nValido por ${OTP_EXPIRY_MINUTES} minutos. No compartas este codigo.`;

  // Fast-path — synchronous direct call to the WA server.
  try {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 15000); // 15s budget — OTP must be fast
    const res = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send-otp`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
      signal: ac.signal,
    });
    clearTimeout(t);
    if (res.ok) {
      const body = await res.json().catch(() => ({}));
      if (body?.sent === true) {
        console.log(`[WA-OTP] fast-path delivered to ${phone.slice(0, 6)}***`);
        return { sent: true, channel: "whatsapp" };
      }
      // 200 with sent:false (idempotency dedup, cooldown). Don't
      // retry — the user's prior code is still valid.
      if (body?.skipped) {
        console.log(`[WA-OTP] skipped: ${body.reason}`);
        return { sent: true, channel: "whatsapp" };
      }
    } else if (res.status === 404) {
      // Recipient not on WhatsApp — caller will fall back to SMS.
      console.log(`[WA-OTP] ${phone.slice(0, 6)}*** not on WhatsApp`);
      return { sent: false, channel: "whatsapp" };
    } else {
      const errBody = await res.text().catch(() => "");
      console.warn(`[WA-OTP] fast-path failed ${res.status}: ${errBody.slice(0, 200)} — falling back to queue`);
    }
  } catch (e) {
    console.warn(`[WA-OTP] fast-path error: ${e} — falling back to queue`);
  }

  // Fallback: queue with CRITICAL priority. Slower but more resilient.
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );
    const queueId = await enqueueWa(supabase, phone, message, {
      priority: WA_PRIORITY.CRITICAL,
      source: "phone-verify",
      idempotencyKey: `otp-${phone}-${code}`,
    });
    return { sent: queueId !== null, channel: "whatsapp" };
  } catch (e) {
    console.error(`[WA-OTP] queue fallback also failed: ${e}`);
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

    // Generate OTP upfront — same code for all channels, we control generation end-to-end
    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000).toISOString();

    // Atomically claim a send-slot. The RPC takes a per-(user,phone) advisory
    // lock, re-checks the 60s dedup window AND the 15-min rate limit, and
    // INSERTs a placeholder row if it wins the race. Concurrent callers see
    // each other's row and short-circuit instead of all enqueuing WA.
    const { data: claim, error: claimErr } = await db.rpc("phone_verify_claim_slot", {
      p_user_id: user.id,
      p_phone: phone,
      p_code_hash: await hashOtp(otp),
      p_expires_at: expiresAt,
    });

    if (claimErr) {
      console.error(`[phone-verify] claim_slot failed: ${claimErr.message}`);
      return json({ error: "Internal error" }, 500);
    }

    if (!claim?.claimed) {
      if (claim?.reason === "rate_limited") {
        return json({ error: "Demasiados intentos. Espera 15 minutos." }, 429);
      }
      // Lost the dedup race or 60s window already covered — return success
      // with the existing record's channel so the client UX continues.
      console.log(`[phone-verify] Dedup hit for ${phone.slice(0, 6)}*** (channel=${claim?.existing_channel})`);
      return json({
        sent: true,
        channel: claim?.existing_channel ?? "whatsapp",
        expires_in: OTP_EXPIRY_MINUTES * 60,
        deduplicated: true,
      });
    }

    const slotId = claim.id as string;

    // We won the race. Send WA. Channel preference: Infobip (whitelisted)
    // → bpi WhatsApp. Twilio removed 2026-04-23.
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

    if (!result.sent) {
      // Roll back the claimed slot so the user can retry without waiting
      // out the 60s dedup window for a code they never received.
      await db.from("phone_verification_codes").delete().eq("id", slotId);
      return json({ error: "No se pudo enviar el codigo. Intenta de nuevo." }, 500);
    }

    // Promote the placeholder channel to the actual one used.
    await db.from("phone_verification_codes")
      .update({ channel: result.channel })
      .eq("id", slotId);

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

    // Mark verified — compare-and-swap on verified=false so two concurrent
    // verify-code calls can't both win (lookup at line above already filters
    // verified=false, this guards the update-side TOCTOU).
    const { data: claimedRows } = await db
      .from("phone_verification_codes")
      .update({ verified: true, verified_at: new Date().toISOString() })
      .eq("id", record.id)
      .eq("verified", false)
      .select("id");

    if (!claimedRows || claimedRows.length === 0) {
      return json({ error: "Codigo ya verificado" }, 409);
    }

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
