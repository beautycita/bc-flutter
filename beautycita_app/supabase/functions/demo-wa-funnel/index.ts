/**
 * demo-wa-funnel — WhatsApp-powered demo funnel for beautycita.com
 *
 * Actions (POST):
 *   send_code       { phone }                — Send 6-digit verification code via WA
 *   verify          { phone, code }          — Verify code, return demo_token
 *   demo_opened     { demo_token }           — Mark demo as opened
 *   demo_closed     { demo_token }           — Mark demo as closed, send download WA
 *   followup_check  { cron_secret }          — 24h follow-up for unregistered users
 *
 * Env vars:
 *   BEAUTYPI_WA_URL       — e.g. http://172.22.0.1:3200
 *   BEAUTYPI_WA_TOKEN     — Bearer token for WA API
 *   DEMO_FUNNEL_SECRET    — Secret for signing demo tokens
 *   CRON_SECRET           — Secret for cron-triggered followup_check
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── CORS ───────────────────────────────────────────────────────────────────

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
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
});

// ─── WhatsApp API ───────────────────────────────────────────────────────────

const WA_API = Deno.env.get("BEAUTYPI_WA_URL") || "http://172.22.0.1:3200";
const WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") || "";

async function sendWA(phone: string, message: string): Promise<boolean> {
  if (!WA_API) return false;
  try {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 5000);
    const res = await fetch(`${WA_API}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
      signal: ac.signal,
    });
    clearTimeout(t);
    if (!res.ok) {
      console.error(`[demo-wa] WA send failed: ${res.status}`);
      return false;
    }
    const data = await res.json();
    return data.sent === true;
  } catch (e) {
    console.error(`[demo-wa] WA error: ${e}`);
    return false;
  }
}

// ─── Rate Limiting (in-memory) ──────────────────────────────────────────────

const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(phone: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(phone);
  if (!entry || now >= entry.resetAt) {
    rateLimitMap.set(phone, { count: 1, resetAt: now + 60 * 60 * 1000 });
    return true;
  }
  if (entry.count >= 3) return false;
  entry.count++;
  return true;
}

// ─── Demo Token ─────────────────────────────────────────────────────────────

const DEMO_SECRET =
  Deno.env.get("DEMO_FUNNEL_SECRET") || "demo-funnel-default-secret";

async function signToken(recordId: number, phone: string): Promise<string> {
  const payload = { id: recordId, phone, exp: Date.now() + 2 * 60 * 60 * 1000 };
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(DEMO_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const payloadB64 = btoa(JSON.stringify(payload));
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(payloadB64));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)));
  return `${payloadB64}.${sigB64}`;
}

async function verifyToken(
  token: string
): Promise<{ id: number; phone: string } | null> {
  try {
    const [payloadB64, sigB64] = token.split(".");
    if (!payloadB64 || !sigB64) return null;
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(DEMO_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"]
    );
    const sigBytes = Uint8Array.from(atob(sigB64), (c) => c.charCodeAt(0));
    const valid = await crypto.subtle.verify(
      "HMAC",
      key,
      sigBytes,
      encoder.encode(payloadB64)
    );
    if (!valid) return null;
    const payload = JSON.parse(atob(payloadB64));
    if (payload.exp < Date.now()) return null;
    return { id: payload.id, phone: payload.phone };
  } catch {
    return null;
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function generateCode(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  return String(array[0] % 1000000).padStart(6, "0");
}

let _req: Request;

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

// ─── Main Handler ───────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  _req = req;

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const db = createClient(supabaseUrl, serviceKey);

    const body = await req.json();
    const { action } = body;
    console.log(`[demo-wa] Action: ${action}`);

    // ─── SEND CODE ────────────────────────────────────────────
    if (action === "send_code") {
      const { phone } = body;
      if (!phone || typeof phone !== "string" || phone.length < 10) {
        return json({ error: "Valid phone number required" }, 400);
      }

      // In-memory rate limit
      if (!checkRateLimit(phone)) {
        return json(
          { error: "Demasiados intentos. Espera 1 hora." },
          429
        );
      }

      // DB rate limit: max 3 codes per phone per hour
      const oneHourAgo = new Date(
        Date.now() - 60 * 60 * 1000
      ).toISOString();
      const { count } = await db
        .from("demo_verifications")
        .select("*", { count: "exact", head: true })
        .eq("phone", phone)
        .gte("created_at", oneHourAgo);

      if ((count ?? 0) >= 3) {
        return json(
          { error: "Demasiados intentos. Espera 1 hora." },
          429
        );
      }

      const code = generateCode();

      // Insert record
      const { data: record, error: insertErr } = await db
        .from("demo_verifications")
        .insert({ phone, code })
        .select("id")
        .single();

      if (insertErr || !record) {
        console.error(`[demo-wa] Insert error: ${insertErr?.message}`);
        return json({ error: "Internal error" }, 500);
      }

      // Send WA
      const message =
        `*BeautyCita Demo*\n\n` +
        `Tu codigo de verificacion: *${code}*\n\n` +
        `Ingresalo en beautycita.com para explorar todas las herramientas de tu nuevo salon management system — gratis, sin compromiso.`;

      const sent = await sendWA(phone, message);
      if (!sent) {
        return json(
          {
            error:
              "No se pudo enviar el codigo por WhatsApp. Verifica que tu numero tenga WhatsApp activo.",
          },
          500
        );
      }

      console.log(`[demo-wa] Code sent to ${phone.slice(0, 6)}***`);
      return json({ sent: true });
    }

    // ─── VERIFY ───────────────────────────────────────────────
    if (action === "verify") {
      const { phone, code } = body;
      if (!phone || !code) {
        return json({ error: "phone and code required" }, 400);
      }

      // Find latest code for this phone, < 10 min old, not yet verified
      const tenMinAgo = new Date(
        Date.now() - 10 * 60 * 1000
      ).toISOString();

      const { data: record } = await db
        .from("demo_verifications")
        .select("*")
        .eq("phone", phone)
        .is("verified_at", null)
        .gte("created_at", tenMinAgo)
        .order("created_at", { ascending: false })
        .limit(1)
        .single();

      if (!record) {
        return json(
          { error: "Codigo expirado o no encontrado. Solicita uno nuevo." },
          400
        );
      }

      if (record.code !== code) {
        return json({ error: "Codigo incorrecto" }, 400);
      }

      // Mark verified
      await db
        .from("demo_verifications")
        .update({ verified_at: new Date().toISOString() })
        .eq("id", record.id);

      // Generate demo token
      const demo_token = await signToken(record.id, phone);

      console.log(`[demo-wa] Verified ${phone.slice(0, 6)}***`);
      return json({ verified: true, demo_token });
    }

    // ─── DEMO OPENED ─────────────────────────────────────────
    if (action === "demo_opened") {
      const { demo_token } = body;
      if (!demo_token) {
        return json({ error: "demo_token required" }, 400);
      }

      const tokenData = await verifyToken(demo_token);
      if (!tokenData) {
        return json({ error: "Invalid or expired demo token" }, 401);
      }

      await db
        .from("demo_verifications")
        .update({ demo_opened_at: new Date().toISOString() })
        .eq("id", tokenData.id);

      console.log(
        `[demo-wa] Demo opened for ${tokenData.phone.slice(0, 6)}***`
      );
      return json({ ok: true });
    }

    // ─── DEMO CLOSED ─────────────────────────────────────────
    if (action === "demo_closed") {
      const { demo_token } = body;
      if (!demo_token) {
        return json({ error: "demo_token required" }, 400);
      }

      const tokenData = await verifyToken(demo_token);
      if (!tokenData) {
        return json({ error: "Invalid or expired demo token" }, 401);
      }

      // Check if close message already sent
      const { data: record } = await db
        .from("demo_verifications")
        .select("followup_sent_at")
        .eq("id", tokenData.id)
        .single();

      if (!record) {
        return json({ error: "Record not found" }, 404);
      }

      // Update demo_closed_at
      await db
        .from("demo_verifications")
        .update({ demo_closed_at: new Date().toISOString() })
        .eq("id", tokenData.id);

      // Send ONE-TIME close message
      if (!record.followup_sent_at) {
        const message =
          `*BeautyCita*\n\n` +
          `Gracias por explorar BeautyCita! \u{1F389}\n\n` +
          `Descarga la app para comenzar a recibir clientes:\n` +
          `\u{1F4F1} https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk\n\n` +
          `Conoces a alguien que tambien tenga un salon? Reenvia este mensaje — les va a encantar. \u{1F488}`;

        await sendWA(tokenData.phone, message);

        await db
          .from("demo_verifications")
          .update({ followup_sent_at: new Date().toISOString() })
          .eq("id", tokenData.id);

        console.log(
          `[demo-wa] Close message sent to ${tokenData.phone.slice(0, 6)}***`
        );
      }

      return json({ ok: true });
    }

    // ─── FOLLOWUP CHECK (cron) ────────────────────────────────
    if (action === "followup_check") {
      const cronSecret = Deno.env.get("CRON_SECRET") || "";
      if (!body.cron_secret || body.cron_secret !== cronSecret) {
        return json({ error: "Unauthorized" }, 401);
      }

      const twentyFourHoursAgo = new Date(
        Date.now() - 24 * 60 * 60 * 1000
      ).toISOString();

      // Find candidates: verified, closed, close message sent, not registered,
      // created > 24h ago, second followup not yet sent
      const { data: candidates, error: queryErr } = await db
        .from("demo_verifications")
        .select("id, phone")
        .not("verified_at", "is", null)
        .not("demo_closed_at", "is", null)
        .not("followup_sent_at", "is", null)
        .eq("app_registered", false)
        .is("second_followup_sent_at", null)
        .lte("created_at", twentyFourHoursAgo);

      if (queryErr) {
        console.error(`[demo-wa] Followup query error: ${queryErr.message}`);
        return json({ error: "Query failed" }, 500);
      }

      if (!candidates || candidates.length === 0) {
        console.log("[demo-wa] No followup candidates");
        return json({ processed: 0 });
      }

      let sent = 0;
      let registered = 0;

      for (const candidate of candidates) {
        // Check if phone exists in profiles (registered app user)
        const { data: profile } = await db
          .from("profiles")
          .select("id")
          .eq("phone", candidate.phone)
          .limit(1)
          .single();

        if (profile) {
          // User registered — mark and skip
          await db
            .from("demo_verifications")
            .update({ app_registered: true })
            .eq("id", candidate.id);
          registered++;
          continue;
        }

        // Not registered — send follow-up
        const message =
          `*BeautyCita*\n\n` +
          `Hola! \u{1F44B} Desde que exploraste BeautyCita, varios clientes han buscado salones en tu zona.\n\n` +
          `No pierdas la oportunidad de aparecer en sus resultados. Descarga la app y registra tu salon en 60 segundos:\n` +
          `\u{1F4F1} https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk\n\n` +
          `Es gratis. Sin cuota mensual. Sin trucos. \u{1F488}`;

        await sendWA(candidate.phone, message);

        await db
          .from("demo_verifications")
          .update({ second_followup_sent_at: new Date().toISOString() })
          .eq("id", candidate.id);

        sent++;
        console.log(
          `[demo-wa] 24h followup sent to ${candidate.phone.slice(0, 6)}***`
        );
      }

      console.log(
        `[demo-wa] Followup done: ${sent} sent, ${registered} already registered`
      );
      return json({ processed: candidates.length, sent, registered });
    }

    return json({ error: `Unknown action: ${action}` }, 400);
  } catch (e) {
    console.error(`[demo-wa] Unhandled error: ${e}`);
    return json({ error: "Internal server error" }, 500);
  }
});
