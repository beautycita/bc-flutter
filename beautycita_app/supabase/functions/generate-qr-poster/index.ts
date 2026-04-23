// =============================================================================
// generate-qr-poster — Return a print-ready HTML page with a QR code
// =============================================================================
// Two variants:
//   poster_type=internal  → minimal QR + small-print aviso de privacidad
//   poster_type=external  → BeautyCita-branded QR with tagline
// Returns text/html with @media print rules; salon prints → PDF.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { requireFeature } from "../_shared/check-toggle.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const PUBLIC_BASE = Deno.env.get("PUBLIC_BASE_URL") ?? "https://beautycita.com";

let _req: Request;
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(_req), "Content-Type": "application/json" },
  });
}

function htmlResponse(html: string): Response {
  return new Response(html, {
    status: 200,
    headers: {
      ...corsHeaders(_req),
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "private, max-age=300",
    },
  });
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]!));
}

function qrImageUrl(data: string): string {
  // Use a well-known public QR generator API. Renders 400x400 PNG, ECC level H.
  // Privacy-safe: no personal data in the QR target (just a public URL).
  const qr = encodeURIComponent(data);
  return `https://api.qrserver.com/v1/create-qr-code/?data=${qr}&size=400x400&ecc=H&margin=10`;
}

function internalPoster(params: {
  salonName: string;
  targetUrl: string;
}): string {
  const { salonName, targetUrl } = params;
  const qr = qrImageUrl(targetUrl);
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>${escapeHtml(salonName)} — Registro de clientes</title>
<style>
  @page { size: A5; margin: 1cm; }
  html, body { margin: 0; padding: 0; font-family: -apple-system, 'Segoe UI', sans-serif; color: #111; background: #fff; }
  .sheet { width: 148mm; min-height: 210mm; padding: 12mm; box-sizing: border-box; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10mm; }
  .salon { font-size: 18pt; font-weight: 700; text-align: center; letter-spacing: 0.3pt; }
  .qr { width: 100mm; height: 100mm; border: 1pt solid #eee; padding: 4mm; box-sizing: border-box; }
  .qr img { width: 100%; height: 100%; }
  .privacy { font-size: 7pt; line-height: 1.35; color: #555; text-align: center; max-width: 120mm; }
  .print-btn { display: block; margin: 8mm auto 0 auto; padding: 8pt 16pt; background: #ec4899; color: #fff; border: none; border-radius: 6pt; font-size: 10pt; cursor: pointer; }
  @media print { .print-btn { display: none; } }
</style>
</head>
<body>
<div class="sheet">
  <div class="salon">${escapeHtml(salonName)}</div>
  <div class="qr"><img src="${qr}" alt="QR registro"></div>
  <div class="privacy">
    Al escanear y completar el formulario, aceptas el Aviso de Privacidad y los Terminos y Condiciones de BeautyCita.
    Mas informacion: beautycita.com/privacidad
  </div>
  <button class="print-btn" onclick="window.print()">Imprimir / Guardar como PDF</button>
</div>
</body>
</html>`;
}

function externalPoster(params: {
  salonName: string;
  targetUrl: string;
}): string {
  const { salonName, targetUrl } = params;
  const qr = qrImageUrl(targetUrl);
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>BeautyCita — ${escapeHtml(salonName)}</title>
<style>
  @page { size: A5; margin: 1cm; }
  html, body { margin: 0; padding: 0; font-family: -apple-system, 'Segoe UI', sans-serif; color: #111; background: #fff; }
  .sheet { width: 148mm; min-height: 210mm; padding: 10mm; box-sizing: border-box; display: flex; flex-direction: column; align-items: center; text-align: center; }
  .brand { font-size: 26pt; font-weight: 800; color: #ec4899; letter-spacing: 0.5pt; margin-bottom: 4mm; }
  .brand .e { color: #111; font-weight: 700; }
  .tagline { font-size: 12pt; color: #444; margin-bottom: 8mm; max-width: 120mm; }
  .salon { font-size: 14pt; font-weight: 600; margin-bottom: 6mm; }
  .qr { width: 105mm; height: 105mm; border: 2pt solid #ec4899; border-radius: 6pt; padding: 4mm; box-sizing: border-box; margin-bottom: 8mm; }
  .qr img { width: 100%; height: 100%; }
  .cta { font-size: 11pt; font-weight: 600; color: #ec4899; margin-bottom: 2mm; }
  .footer { font-size: 8pt; color: #666; margin-top: auto; }
  .print-btn { display: block; margin: 8mm auto 0 auto; padding: 8pt 16pt; background: #ec4899; color: #fff; border: none; border-radius: 6pt; font-size: 10pt; cursor: pointer; }
  @media print { .print-btn { display: none; } }
</style>
</head>
<body>
<div class="sheet">
  <div class="brand">Beauty<span class="e">Cita</span></div>
  <div class="tagline">Reserva inteligente de servicios de belleza</div>
  <div class="salon">${escapeHtml(salonName)}</div>
  <div class="qr"><img src="${qr}" alt="QR BeautyCita"></div>
  <div class="cta">Escanea y reserva tu cita</div>
  <div class="footer">beautycita.com &middot; Disponible en iOS, Android y web</div>
  <button class="print-btn" onclick="window.print()">Imprimir / Guardar como PDF</button>
</div>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  _req = req;
  const preflight = handleCorsPreflightIfOptions(req);
  if (preflight) return preflight;
  if (req.method !== "GET" && req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const blocked = await requireFeature("enable_qr_free_tier");
  if (blocked) return blocked;

  // Auth via user token (must own the business)
  const authHeader = req.headers.get("authorization") ?? "";
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: "Unauthorized" }, 401);

  const url = new URL(req.url);
  const businessId = url.searchParams.get("business_id");
  const posterType = url.searchParams.get("poster_type");

  if (!businessId || !posterType) {
    return json({ error: "business_id and poster_type required" }, 400);
  }
  if (posterType !== "internal" && posterType !== "external") {
    return json({ error: "poster_type must be 'internal' or 'external'" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: biz } = await supabase
    .from("businesses")
    .select("id, name, owner_id, internal_qr_slug, slug, free_tier_agreements_accepted_at")
    .eq("id", businessId)
    .maybeSingle();

  if (!biz) return json({ error: "Business not found" }, 404);
  if (biz.owner_id !== user.id) return json({ error: "Forbidden" }, 403);
  if (!biz.free_tier_agreements_accepted_at) {
    return json({ error: "Free-tier agreement not accepted" }, 403);
  }

  const salonName = (biz.name as string) ?? "Salon";

  if (posterType === "internal") {
    if (!biz.internal_qr_slug) {
      return json({ error: "internal_qr_slug missing — activate program first" }, 409);
    }
    const targetUrl = `${PUBLIC_BASE}/registro/${biz.internal_qr_slug}`;
    return htmlResponse(internalPoster({ salonName, targetUrl }));
  }

  // external
  const slug = (biz.slug as string) ?? biz.id;
  const targetUrl = `${PUBLIC_BASE}/expresscita/${slug}`;
  return htmlResponse(externalPoster({ salonName, targetUrl }));
});
