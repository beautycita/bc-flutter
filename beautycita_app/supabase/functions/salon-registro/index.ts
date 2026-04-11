// =============================================================================
// salon-registro — Multi-step salon owner registration via WhatsApp invite link
// =============================================================================
// GET  ?ref=<id>  → Serve multi-step HTML page (info → OTP → confirm → success)
// POST action=send_otp     → Send OTP via WhatsApp
// POST action=verify_otp   → Verify OTP, return HMAC token
// POST action=create_account → Create auth user + business + staff + schedule
// POST action=set_web_access → Optional: set email+password for web dashboard
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const TWILIO_ACCOUNT_SID = Deno.env.get("TWILIO_ACCOUNT_SID") ?? "";
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN") ?? "";
const TWILIO_VERIFY_SID = Deno.env.get("TWILIO_VERIFY_SID") ?? "";
const HMAC_SECRET = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // Reuse service key as HMAC secret

const OTP_EXPIRY_MINUTES = 10;
const MAX_ATTEMPTS = 3;
const SENTINEL_USER_ID = "00000000-0000-0000-0000-000000000000";
const APK_URL = "https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk";

const ALLOWED_ORIGINS = [
  "https://beautycita.com",
  "https://www.beautycita.com",
  "https://debug.beautycita.com",
];

function corsOrigin(req: Request): string {
  const o = req.headers.get("origin") ?? "";
  return ALLOWED_ORIGINS.includes(o) ? o : ALLOWED_ORIGINS[0];
}

let _req: Request;

const CORS_HEADERS_FOR = (req: Request) => ({
  "Access-Control-Allow-Origin": corsOrigin(req),
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function htmlResp(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: { "Content-Type": "text/html; charset=utf-8", ...CORS_HEADERS_FOR(_req) },
  });
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS_FOR(_req) },
  });
}

function esc(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function generateOtp(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  return String(array[0] % 1000000).padStart(6, "0");
}

function normalizePhone(raw: string): string {
  const digits = raw.replace(/[^\d+]/g, "");
  return digits.startsWith("+") ? digits : `+52${digits}`;
}

// HMAC token: proves phone was verified in this session
async function createHmacToken(phone: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(HMAC_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const ts = Math.floor(Date.now() / 1000);
  const data = `${phone}:${ts}`;
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(data));
  const hex = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `${ts}:${hex}`;
}

async function verifyHmacToken(phone: string, token: string): Promise<boolean> {
  try {
    const [tsStr, hex] = token.split(":");
    const ts = parseInt(tsStr, 10);
    // Token valid for 30 minutes
    if (Math.floor(Date.now() / 1000) - ts > 1800) return false;

    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(HMAC_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const data = `${phone}:${ts}`;
    const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(data));
    const expected = Array.from(new Uint8Array(sig))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    return hex === expected;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// OTP delivery (copied from phone-verify)
// ---------------------------------------------------------------------------

async function sendWhatsApp(
  phone: string,
  code: string,
): Promise<{ sent: boolean; channel: string }> {
  try {
    if (!BEAUTYPI_WA_URL || !BEAUTYPI_WA_TOKEN) {
      return { sent: false, channel: "whatsapp" };
    }
    const checkRes = await fetch(`${BEAUTYPI_WA_URL}/api/wa/check`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone }),
    });
    if (!checkRes.ok) return { sent: false, channel: "whatsapp" };
    const checkData = await checkRes.json();
    if (!checkData.onWhatsApp) return { sent: false, channel: "whatsapp" };

    const message =
      `*BeautyCita* - Tu codigo de verificacion es: *${code}*\n\nValido por ${OTP_EXPIRY_MINUTES} minutos. No compartas este codigo.`;
    const sendRes = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
    });
    if (!sendRes.ok) return { sent: false, channel: "whatsapp" };
    const sendData = await sendRes.json();
    return { sent: sendData.sent === true, channel: "whatsapp" };
  } catch (e) {
    console.error(`[SALON-REG][WA] Error: ${e}`);
    return { sent: false, channel: "whatsapp" };
  }
}

// ---------------------------------------------------------------------------
// SMS fallback via Twilio Verify
// ---------------------------------------------------------------------------

async function sendSms(
  phone: string,
  code: string,
): Promise<{ sent: boolean; channel: string }> {
  try {
    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_VERIFY_SID) {
      console.error("[SALON-REG][SMS] Twilio not configured");
      return { sent: false, channel: "sms" };
    }

    // Use Twilio Verify API to send OTP via SMS
    const url = `https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SID}/Verifications`;
    const auth = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

    const res = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        To: phone.startsWith("+") ? phone : `+${phone}`,
        Channel: "sms",
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error(`[SALON-REG][SMS] Twilio error: ${res.status} ${err}`);
      return { sent: false, channel: "sms" };
    }

    console.log(`[SALON-REG][SMS] OTP sent via SMS to ${phone}`);
    return { sent: true, channel: "sms" };
  } catch (e) {
    console.error(`[SALON-REG][SMS] Error: ${e}`);
    return { sent: false, channel: "sms" };
  }
}

// ---------------------------------------------------------------------------
// Category definitions
// ---------------------------------------------------------------------------

const CATEGORIES = [
  { slug: "unas", label: "Unas", emoji: "\u{1F485}" },
  { slug: "cabello", label: "Cabello", emoji: "\u2702\uFE0F" },
  { slug: "pestanas_cejas", label: "Pestanas y Cejas", emoji: "\u{1F441}\uFE0F" },
  { slug: "maquillaje", label: "Maquillaje", emoji: "\u{1F3A8}" },
  { slug: "facial", label: "Facial", emoji: "\u{1F9D6}" },
  { slug: "cuerpo_spa", label: "Cuerpo y Spa", emoji: "\u{1F9D8}" },
  { slug: "cuidado_especializado", label: "Especializado", emoji: "\u2B50" },
];

// ---------------------------------------------------------------------------
// Prefill data
// ---------------------------------------------------------------------------

interface SalonData {
  id: string;
  name: string;
  phone: string;
  address: string;
  city: string;
  photoUrl: string | null;
  rating: number | null;
  reviewsCount: number | null;
  categories: string[];
  lat: number | null;
  lng: number | null;
}

const EMPTY_SALON: SalonData = {
  id: "",
  name: "",
  phone: "+52 ",
  address: "",
  city: "",
  photoUrl: null,
  rating: null,
  reviewsCount: null,
  categories: [],
  lat: null,
  lng: null,
};

// ---------------------------------------------------------------------------
// HTML template — Multi-step registration page
// ---------------------------------------------------------------------------

function registrationPage(ref: string | null, salon: SalonData): string {
  const hasSalon = salon.name.length > 0;
  const salonJson = JSON.stringify(salon).replace(/</g, "\\u003c");

  const photoHtml = salon.photoUrl
    ? `<img src="${esc(salon.photoUrl)}" class="salon-photo" alt="${esc(salon.name)}">`
    : `<div class="salon-photo-placeholder"><svg width="36" height="36" viewBox="0 0 24 24" fill="white"><path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 14H4V6h16v12zM6 10h2v2H6zm0 4h8v2H6zm10 0h2v2h-2zm-6-4h8v2h-8z"/></svg></div>`;

  const ratingHtml =
    salon.rating && salon.rating > 0
      ? `<div class="rating-badge">\u2605 ${salon.rating.toFixed(1)}${salon.reviewsCount ? ` (${salon.reviewsCount})` : ""}</div>`
      : "";

  const categoryChips = CATEGORIES.map(
    (c) => `
    <label class="chip">
      <input type="checkbox" name="categories" value="${c.slug}"${salon.categories.includes(c.slug) ? " checked" : ""}>
      <span>${c.emoji} ${c.label}</span>
    </label>`,
  ).join("\n");

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${hasSalon ? esc(salon.name) + " - " : ""}Registra tu salon - BeautyCita</title>
  <meta property="og:title" content="${hasSalon ? esc(salon.name) + ' ya tiene clientes esperando' : 'Tu salon ya tiene clientes esperando'} — BeautyCita">
  <meta property="og:description" content="Registrate gratis en 60 segundos y empieza a recibir citas. 0% comision, siempre gratis.">
  <meta property="og:image" content="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/bc_logo.png">
  <meta property="og:type" content="website">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #F8F5FC;
      color: #2D2D2D;
      min-height: 100vh;
    }
    .header {
      background: linear-gradient(135deg, #9B72CF 0%, #7B5EA7 100%);
      padding: 32px 24px 28px;
      text-align: center;
      color: white;
    }
    .header h1 { font-size: 22px; font-weight: 700; margin-bottom: 4px; }
    .header p { font-size: 14px; opacity: 0.9; }
    .badge {
      display: inline-block;
      background: rgba(255,255,255,0.25);
      padding: 4px 14px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 600;
      margin-top: 12px;
    }
    .salon-photo {
      width: 72px; height: 72px; border-radius: 50%;
      object-fit: cover; border: 3px solid rgba(255,255,255,0.5);
      margin-bottom: 12px;
    }
    .salon-photo-placeholder {
      width: 72px; height: 72px; border-radius: 50%;
      background: rgba(255,255,255,0.2); margin: 0 auto 12px;
      display: flex; align-items: center; justify-content: center;
    }
    .rating-badge {
      display: inline-block;
      background: rgba(255,255,255,0.3);
      padding: 2px 10px; border-radius: 12px;
      font-size: 13px; font-weight: 600; margin-top: 8px;
    }
    .wrap {
      padding: 24px; max-width: 480px; margin: 0 auto;
    }

    /* Steps */
    .step { display: none; }
    .step.active { display: block; }

    label.field { display: block; margin-bottom: 20px; }
    label.field .label {
      font-size: 14px; font-weight: 600; margin-bottom: 6px; display: block;
    }
    input[type="text"], input[type="tel"], input[type="email"], input[type="password"] {
      width: 100%; padding: 14px 16px;
      border: none; border-radius: 12px;
      background: white; font-size: 16px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.06);
      outline: none; transition: box-shadow 0.2s;
    }
    input:focus { box-shadow: 0 0 0 2px #9B72CF; }
    .cat-label { font-size: 14px; font-weight: 600; margin-bottom: 10px; }
    .chips { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 24px; }
    .chip { cursor: pointer; user-select: none; }
    .chip input { display: none; }
    .chip span {
      display: inline-block; padding: 8px 14px;
      border-radius: 20px; background: white;
      font-size: 14px; font-weight: 500;
      box-shadow: 0 1px 3px rgba(0,0,0,0.06);
      transition: all 0.15s;
    }
    .chip input:checked + span {
      background: #9B72CF; color: white;
      box-shadow: 0 2px 8px rgba(232,120,138,0.3);
    }
    .btn {
      width: 100%; padding: 16px;
      background: #9B72CF; color: white;
      border: none; border-radius: 14px;
      font-size: 16px; font-weight: 700;
      letter-spacing: 0.5px; cursor: pointer;
      transition: opacity 0.2s;
    }
    .btn:disabled { opacity: 0.4; cursor: not-allowed; }
    .btn:active:not(:disabled) { opacity: 0.8; }
    .btn-secondary {
      background: transparent; color: #9B72CF;
      border: 2px solid #9B72CF; margin-top: 12px;
    }
    .btn-green { background: #25D366; }
    .error { color: #D32F2F; font-size: 13px; margin-top: 8px; display: none; }
    .note {
      text-align: center; font-size: 12px;
      color: #888; margin-top: 20px; line-height: 1.5;
    }

    /* OTP boxes */
    .otp-wrap {
      display: flex; gap: 8px; justify-content: center; margin: 24px 0;
    }
    .otp-wrap input {
      width: 48px; height: 56px; text-align: center;
      font-size: 24px; font-weight: 700;
      border-radius: 12px; border: 2px solid #ddd;
      background: white; outline: none;
      transition: border-color 0.2s;
    }
    .otp-wrap input:focus { border-color: #9B72CF; }
    .resend { text-align: center; margin-top: 12px; font-size: 13px; color: #888; }
    .resend a { color: #9B72CF; text-decoration: none; font-weight: 600; }
    .resend a.disabled { color: #ccc; pointer-events: none; }
    .channel-info { text-align: center; font-size: 13px; color: #666; margin-bottom: 16px; }

    /* Confirm card */
    .salon-card {
      background: white; border-radius: 16px;
      padding: 24px; text-align: center;
      box-shadow: 0 2px 12px rgba(0,0,0,0.06);
      margin-bottom: 24px;
    }
    .salon-card img {
      width: 80px; height: 80px; border-radius: 50%;
      object-fit: cover; margin-bottom: 12px;
      border: 3px solid #9B72CF22;
    }
    .salon-card h2 { font-size: 20px; font-weight: 700; margin-bottom: 4px; }
    .salon-card .meta { font-size: 13px; color: #666; margin-bottom: 12px; }
    .salon-card .detail-row {
      display: flex; align-items: center; gap: 8px;
      font-size: 14px; color: #444; margin-bottom: 8px;
      text-align: left;
    }

    /* Success */
    .success-icon {
      width: 80px; height: 80px; border-radius: 50%;
      background: rgba(76,175,80,0.12);
      display: flex; align-items: center; justify-content: center;
      margin: 0 auto 24px;
    }
    .success h1 { font-size: 24px; font-weight: 700; margin-bottom: 8px; text-align: center; }
    .success p { font-size: 15px; color: #666; line-height: 1.6; text-align: center; }

    /* Web access section */
    .web-access {
      background: white; border-radius: 16px; padding: 20px;
      margin-top: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.04);
    }
    .web-access h3 { font-size: 15px; font-weight: 600; margin-bottom: 4px; }
    .web-access p { font-size: 13px; color: #888; margin-bottom: 16px; }
  </style>
</head>
<body>
  <div class="header">
    ${photoHtml}
    <h1>${hasSalon ? esc(salon.name) : "Registra tu salon"}</h1>
    <p>${hasSalon ? "Verifica tus datos y activa tu perfil" : "Recibe clientas nuevas por BeautyCita"}</p>
    ${ratingHtml}
    <div class="badge">Gratis &middot; 60 segundos &middot; Sin tarjeta</div>
  </div>

  <div class="wrap">
    <!-- STEP 1: Info + Phone -->
    <div class="step active" id="step1">
      <label class="field">
        <span class="label">Tu nombre</span>
        <input type="text" id="ownerName" placeholder="Nombre y apellido" required minlength="2" autocomplete="name">
      </label>

      <label class="field">
        <span class="label">Tu numero de celular</span>
        <input type="tel" id="phone" placeholder="+52 33 1234 5678" value="${esc(salon.phone)}" required autocomplete="tel">
      </label>

      <button class="btn" id="sendOtpBtn" disabled onclick="sendOtp()">VERIFICAR MI WHATSAPP</button>
      <div class="error" id="step1Error"></div>

      <p class="note">
        Te enviaremos un codigo de verificacion por WhatsApp o SMS.
      </p>
    </div>

    <!-- STEP 2: OTP -->
    <div class="step" id="step2">
      <p class="channel-info" id="channelInfo"></p>
      <div class="otp-wrap" id="otpWrap">
        <input type="tel" maxlength="1" data-idx="0" autofocus>
        <input type="tel" maxlength="1" data-idx="1">
        <input type="tel" maxlength="1" data-idx="2">
        <input type="tel" maxlength="1" data-idx="3">
        <input type="tel" maxlength="1" data-idx="4">
        <input type="tel" maxlength="1" data-idx="5">
      </div>
      <div class="error" id="step2Error" style="text-align:center"></div>
      <div class="resend">
        <a href="#" id="resendLink" class="disabled" onclick="resendOtp(event)">Reenviar codigo</a>
        <span id="resendTimer"></span>
      </div>
    </div>

    <!-- STEP 3: Confirm salon data -->
    <div class="step" id="step3">
      <h2 style="font-size:18px;font-weight:700;text-align:center;margin-bottom:20px">Es tu salon?</h2>
      <div class="salon-card" id="salonCard"></div>

      <div class="cat-label">Servicios que ofreces</div>
      <div class="chips" id="catChips">
        ${categoryChips}
      </div>

      <button class="btn" id="createBtn" onclick="createAccount()">CREAR CUENTA DE ESTILISTA</button>
      <div class="error" id="step3Error" style="text-align:center"></div>
      <button class="btn btn-secondary" onclick="goStep(1)">No es mi salon</button>
    </div>

    <!-- STEP 4: Success -->
    <div class="step success" id="step4">
      <div class="success-icon">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="#4CAF50"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
      </div>
      <h1>Bienvenido a BeautyCita!</h1>
      <p style="font-size:15px;line-height:1.6;margin-bottom:16px">Tu cuenta fue creada. Ahora puedes gestionar tu salon, clientes y citas desde la app.</p>

      <div style="background:white;border-radius:16px;padding:20px;margin:16px 0;text-align:left">
        <p style="font-weight:700;font-size:16px;margin-bottom:12px;color:#333">Lo que obtienes — gratis, para siempre:</p>
        <div style="display:flex;align-items:start;gap:10px;margin-bottom:10px">
          <span style="color:#4CAF50;font-size:20px">&#10003;</span>
          <span style="font-size:14px;color:#555">Sistema completo de gestion: calendario, servicios, personal, clientes (CRM)</span>
        </div>
        <div style="display:flex;align-items:start;gap:10px;margin-bottom:10px">
          <span style="color:#4CAF50;font-size:20px">&#10003;</span>
          <span style="font-size:14px;color:#555">Reservas de tus propios clientes — sin comision, sin costo, sin limite</span>
        </div>
        <div style="display:flex;align-items:start;gap:10px;margin-bottom:10px">
          <span style="color:#4CAF50;font-size:20px">&#10003;</span>
          <span style="font-size:14px;color:#555">Cumplimiento fiscal automatizado — somos la unica plataforma en Mexico con retencion ISR/IVA integrada conforme al SAT</span>
        </div>
        <div style="display:flex;align-items:start;gap:10px;margin-bottom:10px">
          <span style="color:#4CAF50;font-size:20px">&#10003;</span>
          <span style="font-size:14px;color:#555">Facturacion electronica (CFDI) incluida sin costo adicional</span>
        </div>

        <div style="display:flex;align-items:start;gap:10px;margin-bottom:10px">
          <span style="color:#9B72CF;font-size:20px">&#9733;</span>
          <span style="font-size:14px;color:#555"><strong>Sello de Salon Verificado</strong> — al completar tu registro, verificamos tu licencia comercial y tu salon recibe nuestro sello de confianza. Tus clientes saben que eres un negocio serio y verificado.</span>
        </div>
        <div style="display:flex;align-items:start;gap:10px;margin-bottom:10px">
          <span style="color:#4CAF50;font-size:20px">&#8634;</span>
          <span style="font-size:14px;color:#555"><strong>Ya usas otro sistema?</strong> Tenemos importacion automatica de tus datos — clientes, servicios, historial de citas. Migra a BeautyCita en minutos y deja de pagar por lo que nosotros te damos gratis.</span>
        </div>

        <div style="border-top:1px solid #eee;margin-top:14px;padding-top:14px">
          <p style="font-size:13px;color:#888;line-height:1.5">Solo cobramos una pequena comision del 3% cuando <strong>nosotros</strong> te enviamos un cliente nuevo a traves de la plataforma. Tus propios clientes? Siempre gratis.</p>
          <a href="https://beautycita.com/porque-beautycita" style="display:block;text-align:center;margin-top:12px;color:#9B72CF;font-size:14px;font-weight:600;text-decoration:none">Como es esto posible? Conoce nuestra historia &rarr;</a>
        </div>
      </div>

      <a href="${APK_URL}" class="btn btn-green" style="display:block;text-align:center;text-decoration:none;margin-top:24px">
        DESCARGAR LA APP
      </a>
      <p class="note" style="margin-top:8px">Gestiona reservas, servicios y pagos desde la app</p>

      <!-- Optional: web access setup -->
      <div class="web-access" id="webAccess">
        <h3>Acceso al panel web (opcional)</h3>
        <p>Configura email y contrasena para entrar desde tu computadora</p>
        <label class="field">
          <span class="label">Email</span>
          <input type="email" id="webEmail" placeholder="tu@email.com" autocomplete="email">
        </label>
        <label class="field">
          <span class="label">Contrasena</span>
          <input type="password" id="webPass" placeholder="Minimo 8 caracteres" minlength="8" autocomplete="new-password">
        </label>
        <button class="btn" id="webAccessBtn" onclick="setWebAccess()">GUARDAR ACCESO WEB</button>
        <div class="error" id="step4Error" style="text-align:center"></div>
      </div>
    </div>
  </div>

  <script>
    const BASE_URL = window.location.pathname + window.location.search;
    const salon = ${salonJson};
    const ref = ${ref ? `"${esc(ref)}"` : "null"};
    let verifyToken = null;
    let otpChannel = null;
    let resendCooldown = 0;
    let resendInterval = null;

    // Step navigation
    function goStep(n) {
      document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
      document.getElementById('step' + n).classList.add('active');
      if (n === 2) {
        const inputs = document.querySelectorAll('#otpWrap input');
        inputs.forEach(i => i.value = '');
        inputs[0].focus();
      }
    }

    // Step 1: Validate inputs
    const nameInput = document.getElementById('ownerName');
    const phoneInput = document.getElementById('phone');
    const sendBtn = document.getElementById('sendOtpBtn');

    function validateStep1() {
      const name = nameInput.value.trim();
      const phone = phoneInput.value.replace(/[^\\d]/g, '');
      sendBtn.disabled = !(name.length >= 2 && phone.length >= 10);
    }
    nameInput.addEventListener('input', validateStep1);
    phoneInput.addEventListener('input', validateStep1);
    validateStep1();

    // Send OTP
    async function sendOtp() {
      const errEl = document.getElementById('step1Error');
      errEl.style.display = 'none';
      sendBtn.disabled = true;
      sendBtn.textContent = 'ENVIANDO...';

      const phone = phoneInput.value.trim();
      try {
        const res = await fetch(BASE_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action: 'send_otp', phone }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Error al enviar codigo');

        otpChannel = data.channel;
        const channelText = data.channel === 'whatsapp' ? 'WhatsApp' : 'SMS';
        document.getElementById('channelInfo').textContent =
          'Te enviamos un codigo de 6 digitos por ' + channelText;

        goStep(2);
        startResendTimer();
      } catch (err) {
        errEl.textContent = err.message;
        errEl.style.display = 'block';
        sendBtn.disabled = false;
        sendBtn.textContent = 'VERIFICAR MI WHATSAPP';
      }
    }

    // OTP input handling
    document.querySelectorAll('#otpWrap input').forEach((inp, idx, all) => {
      inp.addEventListener('input', (e) => {
        const val = e.target.value.replace(/\\D/g, '');
        e.target.value = val.slice(0, 1);
        if (val && idx < 5) all[idx + 1].focus();

        // Auto-submit when all 6 filled
        const code = Array.from(all).map(i => i.value).join('');
        if (code.length === 6) verifyOtp(code);
      });
      inp.addEventListener('keydown', (e) => {
        if (e.key === 'Backspace' && !e.target.value && idx > 0) {
          all[idx - 1].focus();
        }
      });
      // Handle paste
      inp.addEventListener('paste', (e) => {
        e.preventDefault();
        const paste = (e.clipboardData || window.clipboardData).getData('text').replace(/\\D/g, '');
        for (let i = 0; i < Math.min(paste.length, 6); i++) {
          all[i].value = paste[i];
        }
        if (paste.length >= 6) verifyOtp(paste.slice(0, 6));
        else if (paste.length > 0) all[Math.min(paste.length, 5)].focus();
      });
    });

    // Verify OTP
    async function verifyOtp(code) {
      const errEl = document.getElementById('step2Error');
      errEl.style.display = 'none';
      document.querySelectorAll('#otpWrap input').forEach(i => i.disabled = true);

      try {
        const res = await fetch(BASE_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'verify_otp',
            phone: phoneInput.value.trim(),
            code,
          }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Codigo incorrecto');

        verifyToken = data.token;

        // Build confirm card
        buildConfirmCard();
        goStep(3);
      } catch (err) {
        errEl.textContent = err.message;
        errEl.style.display = 'block';
        document.querySelectorAll('#otpWrap input').forEach(i => {
          i.disabled = false;
          i.value = '';
        });
        document.querySelector('#otpWrap input').focus();
      }
    }

    // Resend timer
    function startResendTimer() {
      resendCooldown = 60;
      const link = document.getElementById('resendLink');
      const timer = document.getElementById('resendTimer');
      link.classList.add('disabled');

      if (resendInterval) clearInterval(resendInterval);
      resendInterval = setInterval(() => {
        resendCooldown--;
        if (resendCooldown <= 0) {
          clearInterval(resendInterval);
          link.classList.remove('disabled');
          timer.textContent = '';
        } else {
          timer.textContent = ' (' + resendCooldown + 's)';
        }
      }, 1000);
    }

    async function resendOtp(e) {
      e.preventDefault();
      if (resendCooldown > 0) return;
      await sendOtp();
    }

    // Build confirm card with salon data
    function buildConfirmCard() {
      const card = document.getElementById('salonCard');
      const name = salon.name || 'Tu salon';
      const photoHtml = salon.photoUrl
        ? '<img src="' + salon.photoUrl + '" alt="' + name + '">'
        : '<div style="width:80px;height:80px;border-radius:50%;background:#9B72CF22;display:flex;align-items:center;justify-content:center;margin:0 auto 12px"><svg width="40" height="40" viewBox="0 0 24 24" fill="#9B72CF"><path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2z"/></svg></div>';
      const ratingHtml = salon.rating ? '<div class="meta">\\u2605 ' + salon.rating.toFixed(1) + (salon.reviewsCount ? ' (' + salon.reviewsCount + ' resenas)' : '') + '</div>' : '';
      const addressHtml = salon.address ? '<div class="detail-row">\\uD83D\\uDCCD ' + salon.address + '</div>' : '';
      const phoneHtml = '<div class="detail-row">\\uD83D\\uDCDE ' + phoneInput.value.trim() + '</div>';

      card.innerHTML = photoHtml + '<h2>' + name + '</h2>' + ratingHtml + addressHtml + phoneHtml;
    }

    // Create account
    async function createAccount() {
      const errEl = document.getElementById('step3Error');
      errEl.style.display = 'none';
      const btn = document.getElementById('createBtn');
      btn.disabled = true;
      btn.textContent = 'CREANDO CUENTA...';

      const cats = Array.from(document.querySelectorAll('#catChips input:checked')).map(el => el.value);

      try {
        const res = await fetch(BASE_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'create_account',
            phone: phoneInput.value.trim(),
            owner_name: nameInput.value.trim(),
            token: verifyToken,
            ref,
            categories: cats,
          }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Error al crear cuenta');

        goStep(4);
      } catch (err) {
        errEl.textContent = err.message;
        errEl.style.display = 'block';
        btn.disabled = false;
        btn.textContent = 'CREAR CUENTA DE ESTILISTA';
      }
    }

    // Set web access (optional)
    async function setWebAccess() {
      const errEl = document.getElementById('step4Error');
      errEl.style.display = 'none';
      const btn = document.getElementById('webAccessBtn');
      const email = document.getElementById('webEmail').value.trim();
      const pass = document.getElementById('webPass').value;

      if (!email || !email.includes('@')) {
        errEl.textContent = 'Ingresa un email valido';
        errEl.style.display = 'block';
        return;
      }
      if (pass.length < 8) {
        errEl.textContent = 'La contrasena debe tener al menos 8 caracteres';
        errEl.style.display = 'block';
        return;
      }

      btn.disabled = true;
      btn.textContent = 'GUARDANDO...';

      try {
        const res = await fetch(BASE_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'set_web_access',
            phone: phoneInput.value.trim(),
            email,
            password: pass,
            token: verifyToken,
          }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Error al guardar');

        document.getElementById('webAccess').innerHTML =
          '<div style="text-align:center;color:#4CAF50;font-weight:600">\\u2705 Acceso web configurado</div>';
      } catch (err) {
        errEl.textContent = err.message;
        errEl.style.display = 'block';
        btn.disabled = false;
        btn.textContent = 'GUARDAR ACCESO WEB';
      }
    }
  </script>
</body>
</html>`;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  _req = req;
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS_FOR(req) });
  }

  const url = new URL(req.url);
  const ref = url.searchParams.get("ref");

  // ─── GET: Serve registration page ─────────────────────────────────
  if (req.method === "GET") {
    let salon: SalonData = { ...EMPTY_SALON };

    if (ref) {
      try {
        const supabase = createClient(supabaseUrl, serviceKey);
        const { data: ds } = await supabase
          .from("discovered_salons")
          .select(
            "id, business_name, phone, whatsapp, location_address, location_city, feature_image_url, rating_average, rating_count, specialties, latitude, longitude",
          )
          .eq("id", ref)
          .single();

        if (ds) {
          salon = {
            id: ds.id,
            name: ds.business_name ?? "",
            phone: ds.whatsapp ?? ds.phone ?? "+52 ",
            address: [ds.location_address, ds.location_city]
              .filter(Boolean)
              .join(", "),
            city: ds.location_city ?? "",
            photoUrl: ds.feature_image_url ?? null,
            rating: ds.rating_average ?? null,
            reviewsCount: ds.rating_count ?? null,
            categories: ds.specialties ?? [],
            lat: ds.latitude ?? null,
            lng: ds.longitude ?? null,
          };
        }
      } catch (err) {
        console.warn("[SALON-REG] Could not fetch discovered salon:", err);
      }
    }

    return htmlResp(registrationPage(ref, salon));
  }

  // ─── POST: Handle actions ─────────────────────────────────────────
  if (req.method === "POST") {
    try {
      const body = await req.json();
      const { action } = body;
      const supabase = createClient(supabaseUrl, serviceKey);

      // ── SEND OTP ──────────────────────────────────────────────
      if (action === "send_otp") {
        const rawPhone = body.phone;
        if (!rawPhone || typeof rawPhone !== "string") {
          return json({ error: "Numero de celular requerido" }, 400);
        }
        const phone = normalizePhone(rawPhone);
        if (phone.replace(/\D/g, "").length < 12) {
          return json({ error: "Numero invalido" }, 400);
        }

        // Rate limit: max 3 per phone per 15 min
        const { count } = await supabase
          .from("phone_verification_codes")
          .select("*", { count: "exact", head: true })
          .eq("phone", phone)
          .gte(
            "created_at",
            new Date(Date.now() - 15 * 60 * 1000).toISOString(),
          );

        if ((count || 0) >= 3) {
          return json(
            { error: "Demasiados intentos. Espera 15 minutos." },
            429,
          );
        }

        // Check phone not already registered as business
        const { data: existingBiz } = await supabase
          .from("businesses")
          .select("id, name")
          .or(`phone.eq.${phone},whatsapp.eq.${phone}`)
          .limit(1)
          .maybeSingle();

        if (existingBiz) {
          return json(
            {
              error: "Ya existe un salon registrado con este numero de telefono.",
            },
            400,
          );
        }

        // Generate OTP and pre-insert DB record BEFORE sending
        // (edge runtime timeout can kill us after slow SMS/WA calls)
        const otp = generateOtp();
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

        const { error: insertErr } = await supabase.from("phone_verification_codes").insert({
          user_id: SENTINEL_USER_ID,
          phone,
          code: otp,
          channel: "sms",
          expires_at: expiresAt,
        });
        if (insertErr) {
          console.error(`[SALON-REG] DB insert failed: ${insertErr.message}`);
          return json({ error: "Error interno. Intenta de nuevo." }, 500);
        }
        console.log(`[SALON-REG] OTP record inserted for ${phone}`);

        // Try WhatsApp first, SMS fallback — fire and don't wait for completion
        // The DB record is already saved so verify_otp will work even if we get killed
        let channel = "sms";
        try {
          const waResult = await sendWhatsApp(phone, otp);
          if (waResult.sent) {
            channel = "whatsapp";
            await supabase.from("phone_verification_codes")
              .update({ channel: "whatsapp" })
              .eq("phone", phone)
              .eq("code", otp);
          } else {
            console.log(`[SALON-REG] WA failed for ${phone}, falling back to SMS`);
            const smsResult = await sendSms(phone, otp);
            if (!smsResult.sent) {
              return json({ error: "No se pudo enviar el codigo. Intenta de nuevo." }, 500);
            }
          }
        } catch (e) {
          console.error(`[SALON-REG] Send error: ${e}`);
          // DB record exists with our code — try SMS as last resort
          await sendSms(phone, otp);
        }

        console.log(`[SALON-REG] OTP sent to ${phone} via ${channel}`);
        return json({ sent: true, channel });
      }

      // ── VERIFY OTP ────────────────────────────────────────────
      if (action === "verify_otp") {
        const phone = normalizePhone(body.phone || "");
        const code = body.code;

        if (!phone || !code) {
          return json({ error: "phone and code required" }, 400);
        }

        const { data: record } = await supabase
          .from("phone_verification_codes")
          .select("*")
          .eq("user_id", SENTINEL_USER_ID)
          .eq("phone", phone)
          .eq("verified", false)
          .gte("expires_at", new Date().toISOString())
          .order("created_at", { ascending: false })
          .limit(1)
          .single();

        if (!record) {
          return json(
            {
              error:
                "Codigo expirado o no encontrado. Solicita uno nuevo.",
            },
            400,
          );
        }

        if (record.attempts >= MAX_ATTEMPTS) {
          return json(
            { error: "Demasiados intentos. Solicita un nuevo codigo." },
            400,
          );
        }

        await supabase
          .from("phone_verification_codes")
          .update({ attempts: record.attempts + 1 })
          .eq("id", record.id);

        let verified = false;

        if (record.channel === "sms") {
          // Verify via Twilio Verify API
          try {
            const url = `https://verify.twilio.com/v2/Services/${TWILIO_VERIFY_SID}/VerificationCheck`;
            const auth = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);
            const res = await fetch(url, {
              method: "POST",
              headers: {
                Authorization: `Basic ${auth}`,
                "Content-Type": "application/x-www-form-urlencoded",
              },
              body: new URLSearchParams({
                To: phone.startsWith("+") ? phone : `+${phone}`,
                Code: code,
              }),
            });
            const data = await res.json();
            verified = data.status === "approved";
          } catch (e) {
            console.error(`[SALON-REG] Twilio verify error: ${e}`);
          }
        } else {
          // WA OTP — verify against our stored code
          verified = record.code === code;
        }

        if (!verified) {
          return json(
            {
              error: "Codigo incorrecto",
              remaining: MAX_ATTEMPTS - record.attempts - 1,
            },
            400,
          );
        }

        // Mark verified
        await supabase
          .from("phone_verification_codes")
          .update({
            verified: true,
            verified_at: new Date().toISOString(),
          })
          .eq("id", record.id);

        // Create HMAC token
        const token = await createHmacToken(phone);
        console.log(`[SALON-REG] Phone ${phone} verified`);

        return json({ verified: true, token });
      }

      // ── CREATE ACCOUNT ────────────────────────────────────────
      if (action === "create_account") {
        const phone = normalizePhone(body.phone || "");
        const ownerName = (body.owner_name || "").trim();
        const token = body.token;
        const refId = body.ref;
        const categories = body.categories || [];

        if (!phone || !ownerName || !token) {
          return json({ error: "Datos incompletos" }, 400);
        }

        // Verify HMAC token
        if (!(await verifyHmacToken(phone, token))) {
          return json(
            { error: "Token invalido. Verifica tu numero de nuevo." },
            403,
          );
        }

        // Search for existing user by phone
        let userId: string | null = null;
        const { data: profileByPhone } = await supabase
          .from("profiles")
          .select("id")
          .eq("phone", phone)
          .limit(1)
          .maybeSingle();

        if (profileByPhone) {
          userId = profileByPhone.id;
          console.log(
            `[SALON-REG] Found existing user ${userId} with phone ${phone}`,
          );
        }

        if (!userId) {
          // Create new Supabase auth user with phone
          const { data: newUser, error: createErr } =
            await supabase.auth.admin.createUser({
              phone,
              phone_confirm: true,
              user_metadata: {
                full_name: ownerName,
                registration_source: "salon_invite",
              },
            });

          if (createErr) {
            // If phone already taken, try to find the user
            if (
              createErr.message.includes("already") ||
              createErr.message.includes("exists")
            ) {
              // Fix #8: Query profiles table instead of paginating auth.users
              const { data: foundProfile } = await supabase
                .from("profiles")
                .select("id")
                .eq("phone", phone)
                .limit(1)
                .maybeSingle();
              if (foundProfile) {
                userId = foundProfile.id;
                console.log(
                  `[SALON-REG] Found existing user via profile ${userId}`,
                );
              } else {
                return json(
                  { error: "Ya existe una cuenta con este numero." },
                  400,
                );
              }
            } else {
              console.error("[SALON-REG] Create user error:", createErr);
              return json(
                { error: "Error al crear cuenta: " + createErr.message },
                500,
              );
            }
          } else {
            userId = newUser.user.id;
            console.log(`[SALON-REG] Created auth user ${userId}`);
          }
        }

        // Check if user already has a business
        const { data: existingBiz } = await supabase
          .from("businesses")
          .select("id, name")
          .eq("owner_id", userId)
          .maybeSingle();

        if (existingBiz) {
          return json(
            {
              error: "Ya tienes un salon registrado.",
              business_id: existingBiz.id,
            },
            400,
          );
        }

        // Fetch discovered salon data for enrichment
        let discoveredSalon: Record<string, unknown> | null = null;
        if (refId) {
          const { data: ds } = await supabase
            .from("discovered_salons")
            .select("*")
            .eq("id", refId)
            .single();
          if (ds) {
            // Fix #7: Block duplicate registration
            if (ds.status === "registered") {
              return json(
                { error: "Este salon ya fue registrado." },
                400,
              );
            }
            discoveredSalon = ds;
          }
        }

        // Update/create profile
        await supabase.from("profiles").upsert(
          {
            id: userId,
            full_name: ownerName,
            username: "user_" + userId!.substring(0, 8),
            phone,
            phone_verified: true,
            phone_verified_at: new Date().toISOString(),
            role: "stylist",
          },
          { onConflict: "id" },
        );

        // Create business
        const bizName = discoveredSalon
          ? (discoveredSalon.business_name as string) || ownerName
          : ownerName;

        const bizData: Record<string, unknown> = {
          owner_id: userId,
          name: bizName,
          phone,
          whatsapp: phone,
          service_categories: categories,
          is_active: true,
          tier: 1,
          onboarding_step: "services",
        };

        if (discoveredSalon) {
          if (discoveredSalon.location_address)
            bizData.address = discoveredSalon.location_address;
          if (discoveredSalon.location_city)
            bizData.city = discoveredSalon.location_city;
          if (discoveredSalon.latitude) bizData.lat = discoveredSalon.latitude;
          if (discoveredSalon.longitude) bizData.lng = discoveredSalon.longitude;
          if (discoveredSalon.feature_image_url)
            bizData.photo_url = discoveredSalon.feature_image_url;
        }

        const { data: business, error: bizError } = await supabase
          .from("businesses")
          .insert(bizData)
          .select()
          .single();

        if (bizError) {
          console.error("[SALON-REG] Create business error:", bizError);
          return json(
            { error: "Error al crear salon: " + bizError.message },
            500,
          );
        }

        // Create staff entry
        const nameParts = ownerName.split(" ");
        const { data: staff, error: staffErr } = await supabase
          .from("staff")
          .insert({
            business_id: business.id,
            user_id: userId,
            first_name: nameParts[0],
            last_name: nameParts.slice(1).join(" ") || null,
            is_active: true,
            accept_online_booking: true,
            sort_order: 0,
            position: "owner",
          })
          .select()
          .single();

        if (staffErr) {
          console.error("[SALON-REG] Create staff error:", staffErr);
          await supabase.from("businesses").delete().eq("id", business.id);
          return json({ error: "Error al crear perfil de estilista" }, 500);
        }

        // Create default schedule — use discovered salon working_hours if available
        let defaultStart = "09:00";
        let defaultEnd = "19:00";
        if (discoveredSalon?.working_hours) {
          const hoursMatch = String(discoveredSalon.working_hours).match(/(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})/);
          if (hoursMatch) {
            defaultStart = hoursMatch[1].padStart(5, "0");
            defaultEnd = hoursMatch[2].padStart(5, "0");
            console.log(`[SALON-REG] Using discovered salon hours: ${defaultStart}-${defaultEnd}`);
          }
        }

        const schedule = [];
        for (let day = 1; day <= 6; day++) {
          schedule.push({
            staff_id: staff.id,
            day_of_week: day,
            start_time: defaultStart,
            end_time: defaultEnd,
            is_available: true,
          });
        }
        schedule.push({
          staff_id: staff.id,
          day_of_week: 0,
          start_time: defaultStart,
          end_time: defaultEnd,
          is_available: false,
        });

        await supabase.from("staff_schedules").insert(schedule);

        // Create default service
        const { error: serviceError } = await supabase
          .from("services")
          .insert({
            business_id: business.id,
            name: "Servicio General",
            duration_minutes: 30,
            price: 0,
            active: true,
          });
        if (serviceError) {
          console.error("[SALON-REG] Failed to create default service:", serviceError);
        }

        // Mark business as having schedule and services
        await supabase
          .from("businesses")
          .update({ has_schedule: true, has_services: true })
          .eq("id", business.id);

        // Link discovered salon
        if (refId) {
          await supabase
            .from("discovered_salons")
            .update({
              status: "registered",
              registered_business_id: business.id,
              registered_at: new Date().toISOString(),
            })
            .eq("id", refId);
        }

        console.log(
          `[SALON-REG] Created business ${business.id} for user ${userId}`,
        );
        return json({
          success: true,
          business_id: business.id,
          business_name: business.name,
        });
      }

      // ── SET WEB ACCESS ────────────────────────────────────────
      if (action === "set_web_access") {
        const phone = normalizePhone(body.phone || "");
        const email = (body.email || "").trim();
        const password = body.password;
        const token = body.token;

        if (!phone || !email || !password || !token) {
          return json({ error: "Datos incompletos" }, 400);
        }

        if (!(await verifyHmacToken(phone, token))) {
          return json({ error: "Token invalido" }, 403);
        }

        if (password.length < 8) {
          return json(
            { error: "La contrasena debe tener al menos 8 caracteres" },
            400,
          );
        }

        // Find most recent user by phone
        const { data: profile } = await supabase
          .from("profiles")
          .select("id")
          .eq("phone", phone)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();

        if (!profile) {
          return json({ error: "Usuario no encontrado" }, 404);
        }

        // Update auth user with email + password
        const { error: updateErr } =
          await supabase.auth.admin.updateUserById(profile.id, {
            email,
            password,
            email_confirm: true,
          });

        if (updateErr) {
          console.error("[SALON-REG] Set web access error:", updateErr);
          return json(
            { error: "Error: " + updateErr.message },
            500,
          );
        }

        console.log(
          `[SALON-REG] Web access set for user ${profile.id}: ${email}`,
        );
        return json({ success: true });
      }

      return json({ error: `Unknown action: ${action}` }, 400);
    } catch (err) {
      console.error("[SALON-REG] Error:", err);
      return json({ error: String(err) }, 500);
    }
  }

  return json({ error: "Method not allowed" }, 405);
});
