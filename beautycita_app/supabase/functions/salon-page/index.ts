// =============================================================================
// salon-page — Public salon storefront with booking
// =============================================================================
// Serves at: beautycita.com/s/{slug}
// Shows: hero, before/after gallery, services, staff, reviews, real-time booking
// No login required to browse. Login required to book.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { checkRateLimit, ipKey } from "../_shared/rate-limit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

serve(async (req) => {
  const url = new URL(req.url);
  const slug = url.searchParams.get("slug") ?? url.pathname.replace(/^\/salon-page\/?/, "").replace(/^\//, "");

  // Debug removed — page is working

  if (!slug) {
    return new Response("Not found", { status: 404 });
  }

  // Public endpoint — IP-based rate limit
  if (!checkRateLimit(`salon:${ipKey(req)}`, 60, 60_000)) {
    return new Response("Too many requests", { status: 429 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Fetch salon data — use simple filters, service role bypasses RLS
  const { data: biz, error: bizErr } = await supabase
    .from("businesses")
    .select("id, name, slug, photo_url, address, phone, whatsapp, email, description, average_rating, total_reviews, hours, accept_walkins, auto_confirm, lat, lng, website, instagram_handle, facebook_url, tiktok_handle, is_active, is_verified, on_hold")
    .eq("slug", slug)
    .maybeSingle();

  if (bizErr) {
    console.error(`[SALON-PAGE] DB error: ${bizErr.message}`);
    return new Response("Service temporarily unavailable", { status: 500 });
  }

  // Check active/verified after fetch (avoids RLS complications)
  if (!biz || !biz.is_active || !biz.is_verified) {
    console.log(`[SALON-PAGE] biz found=${!!biz} active=${biz?.is_active} verified=${biz?.is_verified}`);
    return new Response(notFoundPage(slug), { status: 404, headers: { "Content-Type": "text/html; charset=utf-8" } });
  }


  if (!biz) {
    return new Response(notFoundPage(slug), { status: 404, headers: { "Content-Type": "text/html; charset=utf-8" } });
  }

  // Fetch services
  const { data: services } = await supabase
    .from("services")
    .select("id, name, price, duration_minutes, description, service_type, is_active")
    .eq("business_id", biz.id)
    .eq("is_active", true)
    .order("price");

  // Fetch staff (only stylists and owners with services)
  const { data: staff } = await supabase
    .from("staff")
    .select("id, first_name, last_name, avatar_url, experience_years, average_rating, total_reviews, position, bio")
    .eq("business_id", biz.id)
    .eq("is_active", true)
    .in("position", ["owner", "stylist"]);

  // Fetch portfolio photos (published to feed).
  // Include staff_id so the public page can surface a per-stylist gallery
  // link on each staff card. hidden_from_staff_view only affects the
  // stylist's own view; the salon portfolio shows everything.
  const { data: photos } = await supabase
    .from("portfolio_photos")
    .select("id, staff_id, before_url, after_url, service_name, caption, overlays, created_at")
    .eq("business_id", biz.id)
    .eq("is_complete", true)
    .or("publish_to_feed.is.null,publish_to_feed.eq.true")
    .order("created_at", { ascending: false })
    .limit(200);

  // Fetch reviews
  const { data: reviews } = await supabase
    .from("reviews")
    .select("id, rating, comment, created_at, service_type, profiles(username, full_name)")
    .eq("business_id", biz.id)
    .eq("is_visible", true)
    .order("created_at", { ascending: false })
    .limit(10);

  // Fetch products (if POS enabled)
  const { data: products } = await supabase
    .from("products")
    .select("id, name, price, photo_url, in_stock")
    .eq("business_id", biz.id)
    .eq("in_stock", true)
    .order("name")
    .limit(8);

  const html = buildPage(biz, services ?? [], staff ?? [], photos ?? [], reviews ?? [], products ?? []);
  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=3600, s-maxage=3600, stale-while-revalidate=600",
    },
  });
});

function buildPage(
  biz: any,
  services: any[],
  staff: any[],
  photos: any[],
  reviews: any[],
  products: any[],
): string {
  const rating = biz.average_rating ? Number(biz.average_rating).toFixed(1) : null;
  const stars = rating ? "★".repeat(Math.round(Number(rating))) + "☆".repeat(5 - Math.round(Number(rating))) : "";
  const hours = biz.hours ? parseHours(biz.hours) : null;
  const waLink = biz.whatsapp ? `https://wa.me/${biz.whatsapp.replace(/[^0-9+]/g, "")}` : null;
  const bookUrl = `https://beautycita.com/cita-express/${biz.id}`;

  const servicesHtml = services.map(s => `
    <div class="service-card">
      <div class="svc-info">
        <div class="svc-name">${esc(s.name)}</div>
        <div class="svc-meta">${s.duration_minutes} min${s.description ? ' · ' + esc(s.description).substring(0, 60) : ''}</div>
      </div>
      <div class="svc-right">
        <div class="svc-price">$${Number(s.price).toFixed(0)}</div>
        <a href="${bookUrl}" class="btn-book">Reservar</a>
      </div>
    </div>
  `).join("");

  const staffHtml = staff.map(s => {
    const name = `${s.first_name} ${s.last_name ?? ""}`.trim();
    const exp = s.experience_years > 0 ? `${s.experience_years} años exp.` : "Nuevo";
    const safeAvatarUrl = (s.avatar_url || '').replace(/[()'"\\]/g, '');
    const stylistPhotoCount = (photos ?? []).filter(p => p.staff_id === s.id).length;
    return `
      <div class="staff-card">
        <div class="staff-avatar" ${safeAvatarUrl ? `style="background-image:url(${safeAvatarUrl})"` : ""}>
          ${!safeAvatarUrl ? name.charAt(0).toUpperCase() : ""}
        </div>
        <div class="staff-name">${esc(name)}</div>
        <div class="staff-meta">${esc(s.position === "owner" ? "Propietario" : "Estilista")} · ${exp}</div>
        ${s.bio ? `<div class="staff-bio">${esc(s.bio).substring(0, 80)}</div>` : ""}
        ${stylistPhotoCount > 0 ? `<a class="staff-gallery-link" href="javascript:void(0)" data-staff-id="${esc(s.id)}" data-staff-name="${esc(name)}">Galería (${stylistPhotoCount})</a>` : ""}
      </div>
    `;
  }).join("");

  const overlayHtmlFor = (overlays: unknown) => {
    if (!Array.isArray(overlays) || overlays.length === 0) return "";
    return overlays.map(raw => {
      const o = raw as { sticker_id?: string; x?: number; y?: number; scale?: number; rotation?: number };
      const idRaw = String(o.sticker_id ?? "");
      if (!/^[a-z0-9_]+$/i.test(idRaw)) return "";
      const sz = Math.max(0.1, Math.min(1.5, Number(o.scale) || 0.3)) * 100;
      const x = Math.max(0, Math.min(1, Number(o.x) || 0.5)) * 100;
      const y = Math.max(0, Math.min(1, Number(o.y) || 0.5)) * 100;
      const r = Math.max(-180, Math.min(180, Number(o.rotation) || 0));
      return `<img class="sticker-overlay" style="position:absolute;width:${sz}%;aspect-ratio:1;left:${x}%;top:${y}%;transform:translate(-50%,-50%) rotate(${r}deg);pointer-events:none;" src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/sticker_overlays/${idRaw}.png" loading="lazy">`;
    }).join("");
  };

  const photosHtml = photos.map(p => `
    <div class="photo-pair" style="position:relative;">
      ${p.before_url ? `<img src="${escUrl(p.before_url)}" alt="Antes" loading="lazy">` : ""}
      ${p.after_url ? `<img src="${escUrl(p.after_url)}" alt="Despues" loading="lazy">` : ""}
      ${overlayHtmlFor((p as Record<string, unknown>).overlays)}
      ${p.service_name ? `<div class="photo-label">${esc(p.service_name)}</div>` : ""}
    </div>
  `).join("");

  const reviewsHtml = reviews.map(r => {
    const author = r.profiles?.full_name || r.profiles?.username || "Cliente";
    const rStars = "★".repeat(r.rating) + "☆".repeat(5 - r.rating);
    const date = new Date(r.created_at);
    const ago = Math.floor((Date.now() - date.getTime()) / 86400000);
    const agoStr = ago === 0 ? "hoy" : ago === 1 ? "ayer" : `hace ${ago}d`;
    return `
      <div class="review-card">
        <div class="review-stars">${rStars}</div>
        <div class="review-text">${r.comment ? esc(r.comment).substring(0, 200) : ""}</div>
        <div class="review-author">— ${esc(author)}, ${agoStr}</div>
      </div>
    `;
  }).join("");

  const productsHtml = products.length > 0 ? `
    <section class="section">
      <h2>Productos</h2>
      <div class="products-grid">
        ${products.map(p => `
          <div class="product-card">
            ${p.photo_url ? `<img src="${escUrl(p.photo_url)}" alt="${esc(p.name)}" loading="lazy">` : '<div class="product-placeholder"></div>'}
            <div class="product-name">${esc(p.name)}</div>
            <div class="product-price">$${Number(p.price).toFixed(0)} MXN</div>
          </div>
        `).join("")}
      </div>
    </section>
  ` : "";

  const socialLinks = [
    biz.instagram_handle ? `<a href="https://instagram.com/${encodeURIComponent(biz.instagram_handle)}" target="_blank">📸 @${esc(biz.instagram_handle)}</a>` : null,
    biz.facebook_url ? `<a href="${escUrl(biz.facebook_url)}" target="_blank">📘 Facebook</a>` : null,
    biz.tiktok_handle ? `<a href="https://tiktok.com/@${encodeURIComponent(biz.tiktok_handle)}" target="_blank">🎵 @${esc(biz.tiktok_handle)}</a>` : null,
    biz.website ? `<a href="${escUrl(biz.website)}" target="_blank">🌐 Web</a>` : null,
  ].filter(Boolean).join(" · ");

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${esc(biz.name)} — BeautyCita</title>
<meta name="description" content="${esc(biz.description || biz.name + ' — Reserva tu cita de belleza')}">
<meta property="og:title" content="${esc(biz.name)} — BeautyCita">
<meta property="og:description" content="${esc(biz.description || 'Reserva tu cita')}">
${biz.photo_url ? `<meta property="og:image" content="${escUrl(biz.photo_url)}">` : ""}
<meta property="og:url" content="https://beautycita.com/s/${encodeURIComponent(biz.slug)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(biz.name)} — BeautyCita">
<meta name="twitter:description" content="${esc(biz.description || 'Reserva tu cita de belleza')}">
${biz.photo_url ? `<meta name="twitter:image" content="${escUrl(biz.photo_url)}">` : ""}
<style>
  :root { --primary: #C8A2C8; --dark: #1a1a2e; --surface: #ffffff; --text: #1f2937; --muted: #6b7280; --border: #e5e7eb; --green: #059669; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f9fafb; color: var(--text); }
  .hero { background: linear-gradient(135deg, #C8A2C8 0%, #AA7EAA 100%); color: white; padding: 40px 20px 30px; text-align: center; position: relative; }
  .hero-photo { width: 90px; height: 90px; border-radius: 50%; border: 3px solid white; object-fit: cover; margin-bottom: 12px; }
  .hero h1 { font-size: 26px; font-weight: 800; margin-bottom: 4px; }
  .hero .rating { font-size: 18px; letter-spacing: 2px; }
  .hero .rating-num { font-size: 14px; opacity: 0.9; }
  .hero .address { font-size: 13px; opacity: 0.8; margin-top: 8px; }
  .hero-actions { display: flex; gap: 8px; justify-content: center; margin-top: 16px; flex-wrap: wrap; }
  .hero-actions a { background: rgba(255,255,255,0.2); color: white; text-decoration: none; padding: 8px 16px; border-radius: 20px; font-size: 13px; font-weight: 600; backdrop-filter: blur(4px); border: 1px solid rgba(255,255,255,0.3); }
  .hero-actions a.primary { background: white; color: var(--dark); }
  .container { max-width: 600px; margin: 0 auto; padding: 0 16px; }
  .section { margin-top: 24px; }
  .section h2 { font-size: 18px; font-weight: 700; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 2px solid var(--border); }
  .hours-grid { display: grid; grid-template-columns: auto 1fr; gap: 4px 12px; font-size: 13px; }
  .hours-day { font-weight: 600; }
  .hours-time { color: var(--muted); }
  .service-card { display: flex; align-items: center; padding: 14px; background: white; border-radius: 12px; margin-bottom: 8px; border: 1px solid var(--border); }
  .svc-info { flex: 1; }
  .svc-name { font-weight: 600; font-size: 15px; }
  .svc-meta { font-size: 12px; color: var(--muted); margin-top: 2px; }
  .svc-right { text-align: right; }
  .svc-price { font-weight: 700; font-size: 16px; color: var(--green); }
  .btn-book { display: inline-block; margin-top: 4px; padding: 6px 14px; background: var(--primary); color: white; border-radius: 8px; text-decoration: none; font-size: 12px; font-weight: 600; }
  .staff-card { display: inline-block; width: 140px; text-align: center; margin-right: 12px; vertical-align: top; }
  .staff-avatar { width: 70px; height: 70px; border-radius: 50%; background: #f3e8ff; margin: 0 auto 8px; display: flex; align-items: center; justify-content: center; font-size: 24px; font-weight: 700; color: var(--primary); background-size: cover; background-position: center; }
  .staff-name { font-weight: 600; font-size: 14px; }
  .staff-meta { font-size: 11px; color: var(--muted); }
  .staff-bio { font-size: 11px; color: var(--muted); margin-top: 4px; font-style: italic; }
  .staff-scroll { overflow-x: auto; white-space: nowrap; padding-bottom: 8px; }
  .staff-gallery-link { display:inline-block; margin-top:6px; font-size:11px; color:var(--primary); text-decoration:none; border:1px solid var(--primary); padding:3px 10px; border-radius:10px; cursor:pointer; }
  .staff-gallery-link:hover { background:var(--primary); color:white; }
  .gallery-modal { position:fixed; inset:0; background:rgba(0,0,0,0.85); display:none; z-index:200; overflow-y:auto; padding:60px 16px 20px; }
  .gallery-modal.open { display:block; }
  .gallery-modal-header { position:fixed; top:0; left:0; right:0; background:rgba(0,0,0,0.95); color:white; padding:14px 16px; display:flex; align-items:center; justify-content:space-between; z-index:201; }
  .gallery-modal-title { font-weight:700; font-size:15px; }
  .gallery-modal-close { background:none; border:none; color:white; font-size:24px; cursor:pointer; padding:0 8px; line-height:1; }
  .gallery-grid { display:grid; grid-template-columns:1fr 1fr; gap:6px; max-width:720px; margin:0 auto; }
  .gallery-pair { display:grid; grid-template-columns:1fr 1fr; gap:2px; grid-column:span 2; }
  .gallery-pair img, .gallery-pair video { width:100%; aspect-ratio:1; object-fit:cover; border-radius:6px; background:#111; }
  .gallery-caption { grid-column:span 2; color:#ddd; font-size:11px; text-align:center; padding:2px 0 6px; }
  .photo-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .photo-pair { position: relative; }
  .photo-pair img { width: 100%; border-radius: 10px; display: block; }
  .photo-label { position: absolute; bottom: 6px; left: 6px; background: rgba(0,0,0,0.6); color: white; font-size: 10px; padding: 2px 8px; border-radius: 4px; }
  .review-card { background: white; border-radius: 12px; padding: 14px; margin-bottom: 8px; border: 1px solid var(--border); }
  .review-stars { color: #fbbf24; font-size: 16px; letter-spacing: 1px; }
  .review-text { font-size: 13px; margin-top: 6px; line-height: 1.4; color: var(--text); }
  .review-author { font-size: 11px; color: var(--muted); margin-top: 6px; }
  .products-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .product-card { background: white; border-radius: 12px; overflow: hidden; border: 1px solid var(--border); }
  .product-card img { width: 100%; height: 120px; object-fit: cover; }
  .product-placeholder { width: 100%; height: 120px; background: #f3f4f6; }
  .product-name { padding: 8px 10px 2px; font-size: 13px; font-weight: 600; }
  .product-price { padding: 0 10px 8px; font-size: 12px; color: var(--green); font-weight: 700; }
  .social-links { text-align: center; margin: 20px 0; }
  .social-links a { color: var(--muted); text-decoration: none; font-size: 13px; }
  .cta-bar { position: fixed; bottom: 0; left: 0; right: 0; background: white; border-top: 1px solid var(--border); padding: 12px 16px; display: flex; gap: 10px; z-index: 100; }
  .cta-bar a { flex: 1; text-align: center; padding: 12px; border-radius: 12px; font-weight: 700; font-size: 15px; text-decoration: none; }
  .cta-bar .cta-book { background: var(--primary); color: white; }
  .cta-bar .cta-wa { background: #25D366; color: white; }
  .footer { text-align: center; padding: 20px; margin-bottom: 70px; font-size: 11px; color: var(--muted); }
  .footer a { color: var(--primary); text-decoration: none; }
  .desc { font-size: 14px; color: var(--text); line-height: 1.5; margin-bottom: 16px; }
</style>
</head>
<body>

<div class="hero">
  ${biz.photo_url ? `<img src="${escUrl(biz.photo_url)}" class="hero-photo" alt="${esc(biz.name)}">` : ""}
  <h1>${esc(biz.name)}</h1>
  ${rating ? `<div class="rating">${stars} <span class="rating-num">${rating} (${biz.total_reviews} reseñas)</span></div>` : ""}
  ${biz.address ? `<div class="address">📍 ${esc(biz.address)}</div>` : ""}
  <div class="hero-actions">
    <a href="${bookUrl}" class="primary">📅 Reservar ahora</a>
    ${waLink ? `<a href="${escUrl(waLink)}" target="_blank">💬 WhatsApp</a>` : ""}
    ${biz.phone ? `<a href="tel:${escUrl(biz.phone)}">📞 Llamar</a>` : ""}
  </div>
</div>

<div class="container">
  ${biz.description ? `<section class="section"><p class="desc">${esc(biz.description)}</p></section>` : ""}

  ${hours ? `
    <section class="section">
      <h2>Horario</h2>
      <div class="hours-grid">${hours}</div>
    </section>
  ` : ""}

  ${services.length > 0 ? `
    <section class="section">
      <h2>Servicios</h2>
      ${servicesHtml}
    </section>
  ` : ""}

  ${staff.length > 0 ? `
    <section class="section">
      <h2>Nuestro equipo</h2>
      <div class="staff-scroll">${staffHtml}</div>
    </section>
  ` : ""}

  ${photos.length > 0 ? `
    <section class="section">
      <h2>Antes y Despues</h2>
      <div class="photo-grid">${photosHtml}</div>
    </section>
  ` : ""}

  ${reviews.length > 0 ? `
    <section class="section">
      <h2>Reseñas</h2>
      ${reviewsHtml}
    </section>
  ` : ""}

  ${productsHtml}

  ${socialLinks ? `<div class="social-links">${socialLinks}</div>` : ""}

  <div class="footer">
    <a href="https://beautycita.com">BeautyCita</a> — Reservas inteligentes de belleza<br>
    RFC: BEA260313MI8
  </div>
</div>

<div class="cta-bar">
  <a href="${bookUrl}" class="cta-book">📅 Reservar</a>
  ${waLink ? `<a href="${escUrl(waLink)}" class="cta-wa" target="_blank">💬 WhatsApp</a>` : ""}
</div>

<!-- Per-stylist gallery modal — opens when a staff card's "Galería" link is tapped -->
<div class="gallery-modal" id="galleryModal" onclick="if(event.target===this)closeGallery()">
  <div class="gallery-modal-header">
    <div class="gallery-modal-title" id="galleryTitle">Galería</div>
    <button class="gallery-modal-close" onclick="closeGallery()" aria-label="Cerrar">×</button>
  </div>
  <div class="gallery-grid" id="galleryGrid"></div>
</div>

<script>
// All portfolio photos for this salon, pre-rendered server-side. Filter by
// staff_id when a stylist's Galería link is tapped. Videos detected by
// extension — after_url can be mp4/webm/mov for video portfolio pieces.
const __SALON_PHOTOS = ${JSON.stringify((photos ?? []).map(p => ({
  id: p.id, staff_id: p.staff_id,
  before_url: p.before_url, after_url: p.after_url,
  service_name: p.service_name, created_at: p.created_at,
  overlays: Array.isArray(p.overlays) ? p.overlays : [],
})))};
const __STICKER_BASE = 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/sticker_overlays/';
function __overlayHtml(overlays) {
  if (!Array.isArray(overlays) || !overlays.length) return '';
  return overlays.map(o => {
    const sz = Math.max(0.1, Math.min(1.5, Number(o.scale) || 0.3)) * 100;
    const x = Math.max(0, Math.min(1, Number(o.x) || 0.5)) * 100;
    const y = Math.max(0, Math.min(1, Number(o.y) || 0.5)) * 100;
    const r = Math.max(-180, Math.min(180, Number(o.rotation) || 0));
    const id = String(o.sticker_id || '').replace(/[^a-z0-9_]/gi, '');
    return '<img class="sticker-overlay" style="position:absolute;width:' + sz + '%;aspect-ratio:1;left:' + x + '%;top:' + y + '%;transform:translate(-50%,-50%) rotate(' + r + 'deg);pointer-events:none;" src="' + __STICKER_BASE + id + '.png" loading="lazy">';
  }).join('');
}
const __isVideo = (u) => u && /\\.(mp4|webm|mov)(\\?|$)/i.test(u);
const __escAttr = (s) => String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');

function openGallery(staffId, staffName) {
  const pics = __SALON_PHOTOS.filter(p => p.staff_id === staffId);
  document.getElementById('galleryTitle').textContent = 'Galería — ' + staffName;
  const grid = document.getElementById('galleryGrid');
  grid.innerHTML = pics.length === 0
    ? '<div style="color:#ccc;text-align:center;grid-column:span 2;padding:40px">Sin fotos publicadas</div>'
    : pics.map(p => {
        const afterInner = p.after_url
          ? (__isVideo(p.after_url)
              ? '<video src="' + __escAttr(p.after_url) + '" controls playsinline muted preload="metadata"></video>'
              : '<img src="' + __escAttr(p.after_url) + '" loading="lazy">')
          : '<div style="aspect-ratio:1;background:#222;border-radius:6px"></div>';
        const afterCell = '<div style="position:relative;">' + afterInner + __overlayHtml(p.overlays) + '</div>';
        const beforeCell = p.before_url
          ? '<img src="' + __escAttr(p.before_url) + '" loading="lazy">'
          : '<div style="aspect-ratio:1;background:#222;border-radius:6px"></div>';
        const cap = p.service_name ? '<div class="gallery-caption">' + __escAttr(p.service_name) + '</div>' : '';
        return '<div class="gallery-pair">' + beforeCell + afterCell + cap + '</div>';
      }).join('');
  document.getElementById('galleryModal').classList.add('open');
  document.body.style.overflow = 'hidden';
}

function closeGallery() {
  document.getElementById('galleryModal').classList.remove('open');
  document.body.style.overflow = '';
}

// Wire up the Galería links on staff cards
document.querySelectorAll('.staff-gallery-link').forEach(a => {
  a.addEventListener('click', () => {
    openGallery(a.getAttribute('data-staff-id'), a.getAttribute('data-staff-name'));
  });
});
</script>

</body>
</html>`;
}

function parseHours(hours: any): string {
  const dayNames: Record<string, string> = {
    monday: "Lunes", tuesday: "Martes", wednesday: "Miercoles",
    thursday: "Jueves", friday: "Viernes", saturday: "Sabado", sunday: "Domingo",
  };
  const parsed = typeof hours === "string" ? JSON.parse(hours) : hours;
  if (!parsed || typeof parsed !== "object") return "";

  return Object.entries(dayNames).map(([key, label]) => {
    const day = parsed[key];
    if (!day || !day.open || !day.close) return `<span class="hours-day">${label}</span><span class="hours-time">Cerrado</span>`;
    return `<span class="hours-day">${label}</span><span class="hours-time">${day.open} — ${day.close}</span>`;
  }).join("");
}

function notFoundPage(slug: string): string {
  return `<!DOCTYPE html><html><head><title>No encontrado</title></head><body style="font-family:sans-serif;text-align:center;padding:60px"><h1>Salon no encontrado</h1><p>"${esc(slug)}" no existe o no esta activo.</p><p><a href="https://beautycita.com">Ir a BeautyCita</a></p></body></html>`;
}

function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

/** Escape a URL for use in href/src attributes — strips javascript: and data: URIs, encodes quotes. */
function escUrl(s: string | null | undefined): string {
  if (!s) return "";
  const trimmed = s.trim();
  // Block javascript: and data: URIs
  if (/^\s*(javascript|data):/i.test(trimmed)) return "";
  return trimmed.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/'/g, "&#x27;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
