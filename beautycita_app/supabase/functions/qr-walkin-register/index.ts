// =============================================================================
// qr-walkin-register — Public form endpoint for salon internal-QR client registration
// =============================================================================
// Design: /home/bc/futureBeauty/docs/plans/2026-04-23-salon-qr-90day.md
// Flow:
//   1. Anonymous client scans salon's internal QR, fills form
//   2. If phone-new: send OTP, return { needs_otp: true }
//   3. If phone-existing + same device: skip OTP
//   4. On success: upsert registration + insert pending appointment + notify salon
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { requireFeature } from "../_shared/check-toggle.ts";
import { checkRateLimit, ipKey } from "../_shared/rate-limit.ts";
import { cacheGet, cacheSet, cacheDel } from "../_shared/redis.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const HASH_SALT = Deno.env.get("QR_HASH_SALT") ?? "beautycita-qr-default-salt";

const OTP_TTL_SECONDS = 600; // 10 minutes
const DEFAULT_SHARED_DEVICE_THRESHOLD = 5;
const DEFAULT_PER_PHONE_LIMIT = 3;
const DEFAULT_FREE_TIER_DAYS = 90;

let _req: Request;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function extractIp(req: Request): string {
  const cf = req.headers.get("cf-connecting-ip");
  if (cf) return cf;
  const xff = req.headers.get("x-forwarded-for");
  if (xff) return xff.split(",")[0].trim();
  return "unknown";
}

function generateOtp(): string {
  const a = new Uint32Array(1);
  crypto.getRandomValues(a);
  return String(a[0] % 1_000_000).padStart(6, "0");
}

/** Direct WA send (no phone-verify dep — that fn requires auth). */
async function sendOtpViaWa(phone: string, code: string, businessName: string): Promise<boolean> {
  if (!BEAUTYPI_WA_URL) return false;
  try {
    const msg =
      `*${businessName}* solicita tu confirmacion para registrarte como cliente en BeautyCita.\n\n` +
      `Tu codigo es: *${code}*\n\nValido por 10 minutos.`;
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 20_000);
    const res = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message: msg }),
      signal: ac.signal,
    });
    clearTimeout(t);
    if (!res.ok) return false;
    const data = await res.json();
    return data.sent === true;
  } catch (e) {
    console.error(`[qr-walkin-register] OTP send failed: ${e}`);
    return false;
  }
}

async function loadNumericConfig(
  supabase: ReturnType<typeof createClient>,
  key: string,
  fallback: number,
): Promise<number> {
  const { data } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", key)
    .maybeSingle();
  const n = Number(data?.value);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

Deno.serve(async (req: Request) => {
  _req = req;
  const preflight = handleCorsPreflightIfOptions(req);
  if (preflight) return preflight;
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // Feature toggle
  const blocked = await requireFeature("enable_qr_free_tier");
  if (blocked) return blocked;

  // Per-IP rate limit (coarse abuse protection)
  if (!checkRateLimit(`qr-reg:${ipKey(req)}`, 10, 60_000)) {
    return json({ error: "Too many requests" }, 429);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const {
    business_slug,
    full_name,
    phone,
    service_id,
    client_notes,
    device_uuid,
    otp_code,
    accepted_privacy,
    accepted_tos,
    accepted_cookies,
  } = body as Record<string, string | boolean | undefined>;

  // Input validation
  if (typeof business_slug !== "string" || !business_slug ||
      typeof full_name !== "string" || !full_name ||
      typeof phone !== "string" || !phone ||
      typeof service_id !== "string" || !service_id ||
      typeof device_uuid !== "string" || !device_uuid) {
    return json({ error: "Missing required fields" }, 400);
  }
  if (accepted_privacy !== true || accepted_tos !== true || accepted_cookies !== true) {
    return json({ error: "All three agreements must be accepted" }, 400);
  }
  if (!/^\+[1-9]\d{6,14}$/.test(phone)) {
    return json({ error: "Phone must be E.164 format" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // 1. Resolve business
  const { data: biz } = await supabase
    .from("businesses")
    .select(
      "id, name, owner_id, is_active, free_tier_agreements_accepted_at, free_tier_started_at",
    )
    .eq("internal_qr_slug", business_slug)
    .maybeSingle();
  if (!biz) return json({ error: "Negocio no encontrado" }, 404);
  if (!biz.is_active) return json({ error: "Negocio no disponible" }, 403);
  if (!biz.free_tier_agreements_accepted_at) {
    return json({ error: "Programa no activado para este salon" }, 403);
  }

  // 2. Validate service belongs to business
  const { data: svc } = await supabase
    .from("services")
    .select("id, name, price")
    .eq("id", service_id)
    .eq("business_id", biz.id)
    .eq("is_active", true)
    .maybeSingle();
  if (!svc) return json({ error: "Servicio no disponible" }, 400);

  // 3. Fingerprint
  const ip = extractIp(req);
  const ua = req.headers.get("user-agent") ?? "";
  const saltDate = new Date().toISOString().slice(0, 10);
  const ipHash = await sha256Hex(`${ip}|${HASH_SALT}|${saltDate}`);
  const uaHash = await sha256Hex(`${ua}|${HASH_SALT}|${saltDate}`);

  // 4. Shared-device check (ip_hash, ua_hash, device_uuid)
  const sharedThreshold = await loadNumericConfig(
    supabase,
    "qr_shared_device_threshold",
    DEFAULT_SHARED_DEVICE_THRESHOLD,
  );
  const twentyFourAgo = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  const { data: sharedRows } = await supabase
    .from("salon_walkin_registrations")
    .select("phone")
    .eq("ip_hash", ipHash)
    .eq("user_agent_hash", uaHash)
    .eq("device_uuid", device_uuid)
    .gte("created_at", twentyFourAgo);
  const distinctPhones = new Set((sharedRows ?? []).map((r: Record<string, unknown>) => r.phone as string));
  distinctPhones.add(phone);
  if (distinctPhones.size > sharedThreshold) {
    await supabase.from("admin_alerts").insert({
      category: "shared_device",
      severity: "warning",
      payload: {
        business_id: biz.id,
        ip_hash: ipHash,
        user_agent_hash: uaHash,
        device_uuid,
        phone_count_24h: distinctPhones.size,
      },
    });
    return json({ error: "Limit reached. Descarga la app para continuar." }, 429);
  }

  // 5. Per-phone rate limit
  const perPhoneLimit = await loadNumericConfig(
    supabase,
    "qr_per_phone_rate_limit",
    DEFAULT_PER_PHONE_LIMIT,
  );
  const { count: phoneCount } = await supabase
    .from("salon_walkin_registrations")
    .select("id", { count: "exact", head: true })
    .eq("phone", phone)
    .gte("created_at", twentyFourAgo);
  if ((phoneCount ?? 0) >= perPhoneLimit) {
    return json({ error: "Demasiados registros recientes con este numero." }, 429);
  }

  // 6. 90-day window
  const freeTierDays = await loadNumericConfig(
    supabase,
    "qr_free_tier_days",
    DEFAULT_FREE_TIER_DAYS,
  );
  let windowState: "grace" | "open" | "grandfathered" | "closed";
  if (!biz.free_tier_started_at) {
    windowState = "grace";
  } else {
    const daysSince = (Date.now() - new Date(biz.free_tier_started_at).getTime()) / 86_400_000;
    if (daysSince < freeTierDays) {
      windowState = "open";
    } else {
      const { data: existingReg } = await supabase
        .from("salon_walkin_registrations")
        .select("id")
        .eq("business_id", biz.id)
        .eq("phone", phone)
        .maybeSingle();
      windowState = existingReg ? "grandfathered" : "closed";
    }
  }
  if (windowState === "closed") {
    return json({ redirect_to: "bc_signup", reason: "tier_expired" });
  }

  // 7. OTP gate
  const { data: existingForPair } = await supabase
    .from("salon_walkin_registrations")
    .select("id, device_uuid")
    .eq("business_id", biz.id)
    .eq("phone", phone)
    .maybeSingle();

  const sameDevicePriorVisit =
    existingForPair && existingForPair.device_uuid === device_uuid;

  if (!sameDevicePriorVisit) {
    const otpKey = `qr:otp:${biz.id}:${phone}`;

    if (!otp_code) {
      const code = generateOtp();
      const codeHash = await sha256Hex(`${code}|${HASH_SALT}`);
      await cacheSet(
        otpKey,
        JSON.stringify({ hash: codeHash, created_at: Date.now() }),
        OTP_TTL_SECONDS,
      );
      const sent = await sendOtpViaWa(phone, code, biz.name);
      return json({ needs_otp: true, otp_sent: sent });
    }

    const cached = await cacheGet(otpKey);
    if (!cached) return json({ error: "OTP expirado. Solicita uno nuevo." }, 401);
    let parsed: { hash: string } | null = null;
    try {
      parsed = JSON.parse(cached);
    } catch { /* fall through */ }
    if (!parsed) return json({ error: "OTP invalido" }, 401);
    if (typeof otp_code !== "string" || !/^\d{6}$/.test(otp_code)) {
      return json({ error: "OTP invalido" }, 401);
    }
    const submittedHash = await sha256Hex(`${otp_code}|${HASH_SALT}`);
    if (submittedHash !== parsed.hash) {
      return json({ error: "OTP invalido" }, 401);
    }
    await cacheDel(otpKey);
  }

  // 8. Upsert registration
  const { data: upserted, error: upErr } = await supabase
    .from("salon_walkin_registrations")
    .upsert(
      {
        business_id: biz.id,
        phone,
        full_name,
        device_uuid,
        ip_hash: ipHash,
        user_agent_hash: uaHash,
      },
      { onConflict: "business_id,phone" },
    )
    .select("id")
    .single();
  if (upErr || !upserted) {
    console.error("[qr-walkin-register] Upsert failed:", upErr);
    return json({ error: "No se pudo registrar" }, 500);
  }

  // 9. Insert pending appointment
  const { data: pending, error: pendErr } = await supabase
    .from("walkin_pending_appointments")
    .insert({
      business_id: biz.id,
      registration_id: upserted.id,
      service_id: svc.id,
      service_name: svc.name,
      client_notes: typeof client_notes === "string" ? client_notes : null,
    })
    .select("id")
    .single();
  if (pendErr || !pending) {
    console.error("[qr-walkin-register] Pending insert failed:", pendErr);
    return json({ error: "No se pudo crear la cita" }, 500);
  }

  // 10. Notify salon owner (fire-and-forget — do NOT block the response)
  const shortId = String(pending.id).slice(0, 8).toUpperCase();
  (async () => {
    try {
      await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user_id: biz.owner_id,
          notification_type: "new_booking",
          custom_title: "Nuevo cliente en recepcion",
          custom_body: `${full_name} espera asignacion — ${svc.name} (#${shortId})`,
          data: { type: "walkin_new_pending", pending_id: pending.id },
        }),
      });
    } catch (e) {
      console.error(`[qr-walkin-register] Push failed: ${(e as Error).message}`);
    }
  })();

  return json({
    success: true,
    pending_id: pending.id,
    grandfathered: windowState === "grandfathered",
  });
});
