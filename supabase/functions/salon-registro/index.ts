// salon-registro edge function
// Serves a mobile-friendly registration page for salon owners.
// Salon owners reach this via the WhatsApp invite link (beautycita.com/salon/<id>).
// When ref param is provided, pre-populates form with discovered salon data.
// GET  → HTML registration form (with prefill if ref found)
// POST → Create business record + return success page

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};

function htmlResp(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: { "Content-Type": "text/html; charset=utf-8", ...CORS_HEADERS },
  });
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

// ---------------------------------------------------------------------------
// Category definitions (must match Flutter SalonOnboardingScreen)
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
// Prefill data interface
// ---------------------------------------------------------------------------

interface Prefill {
  name: string;
  phone: string;
  address: string;
  categories: string[];
  photoUrl: string | null;
  rating: number | null;
}

const EMPTY_PREFILL: Prefill = {
  name: "",
  phone: "+52 ",
  address: "",
  categories: [],
  photoUrl: null,
  rating: null,
};

// Escape HTML to prevent XSS from salon data
function esc(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// ---------------------------------------------------------------------------
// HTML template
// ---------------------------------------------------------------------------

function registrationPage(ref: string | null, prefill: Prefill): string {
  const hasPrefill = prefill.name.length > 0;

  const categoryChips = CATEGORIES.map(
    (c) => `
    <label class="chip">
      <input type="checkbox" name="categories" value="${c.slug}"${prefill.categories.includes(c.slug) ? " checked" : ""}>
      <span>${c.emoji} ${c.label}</span>
    </label>`,
  ).join("\n");

  // Header content changes based on whether we have salon data
  const photoHtml = prefill.photoUrl
    ? `<img src="${esc(prefill.photoUrl)}" class="salon-photo" alt="${esc(prefill.name)}">`
    : "";

  const ratingHtml =
    prefill.rating && prefill.rating > 0
      ? `<div class="rating-badge">\u2605 ${prefill.rating.toFixed(1)}</div>`
      : "";

  const headerTitle = hasPrefill
    ? `Hola, ${esc(prefill.name)}!`
    : "Registra tu salon";

  const headerSubtitle = hasPrefill
    ? "Verifica tus datos y registrate en segundos"
    : "Recibe clientes nuevas por BeautyCita";

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${hasPrefill ? esc(prefill.name) + " - " : ""}Registra tu salon - BeautyCita</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #FFF8F0;
      color: #2D2D2D;
      min-height: 100vh;
    }
    .header {
      background: linear-gradient(135deg, #E8788A 0%, #D4637A 100%);
      padding: 32px 24px 28px;
      text-align: center;
      color: white;
    }
    .header h1 { font-size: 24px; font-weight: 700; margin-bottom: 4px; }
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
      width: 72px;
      height: 72px;
      border-radius: 50%;
      object-fit: cover;
      border: 3px solid rgba(255,255,255,0.5);
      margin-bottom: 12px;
    }
    .rating-badge {
      display: inline-block;
      background: rgba(255,255,255,0.3);
      padding: 2px 10px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 600;
      margin-top: 8px;
    }
    .form-wrap {
      padding: 24px;
      max-width: 480px;
      margin: 0 auto;
    }
    label.field { display: block; margin-bottom: 20px; }
    label.field .label {
      font-size: 14px;
      font-weight: 600;
      margin-bottom: 6px;
      display: block;
    }
    input[type="text"], input[type="tel"] {
      width: 100%;
      padding: 14px 16px;
      border: none;
      border-radius: 12px;
      background: white;
      font-size: 16px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.06);
      outline: none;
      transition: box-shadow 0.2s;
    }
    input:focus { box-shadow: 0 0 0 2px #E8788A; }
    .cat-label { font-size: 14px; font-weight: 600; margin-bottom: 10px; }
    .chips {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-bottom: 24px;
    }
    .chip {
      cursor: pointer;
      user-select: none;
    }
    .chip input { display: none; }
    .chip span {
      display: inline-block;
      padding: 8px 14px;
      border-radius: 20px;
      background: white;
      font-size: 14px;
      font-weight: 500;
      box-shadow: 0 1px 3px rgba(0,0,0,0.06);
      transition: all 0.15s;
    }
    .chip input:checked + span {
      background: #E8788A;
      color: white;
      box-shadow: 0 2px 8px rgba(232,120,138,0.3);
    }
    .submit-btn {
      width: 100%;
      padding: 16px;
      background: #E8788A;
      color: white;
      border: none;
      border-radius: 14px;
      font-size: 16px;
      font-weight: 700;
      letter-spacing: 0.5px;
      cursor: pointer;
      transition: opacity 0.2s;
    }
    .submit-btn:disabled { opacity: 0.4; cursor: not-allowed; }
    .submit-btn:active:not(:disabled) { opacity: 0.8; }
    .error { color: #D32F2F; font-size: 13px; margin-top: 8px; display: none; }
    .note {
      text-align: center;
      font-size: 12px;
      color: #888;
      margin-top: 20px;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="header">
    ${photoHtml}
    <h1>${headerTitle}</h1>
    <p>${headerSubtitle}</p>
    ${ratingHtml}
    <div class="badge">Gratis &middot; 60 segundos &middot; Sin tarjeta</div>
  </div>

  <div class="form-wrap">
    <form id="regForm" method="POST">
      <input type="hidden" name="ref" value="${ref ?? ""}">

      <label class="field">
        <span class="label">Nombre del salon</span>
        <input type="text" name="name" placeholder="Ej: Salon Rosa" value="${esc(prefill.name)}" required minlength="2" autocomplete="organization">
      </label>

      <label class="field">
        <span class="label">WhatsApp</span>
        <input type="tel" name="phone" placeholder="+52 33 1234 5678" value="${esc(prefill.phone)}" required autocomplete="tel">
      </label>

      <label class="field">
        <span class="label">Direccion (opcional)</span>
        <input type="text" name="address" placeholder="Calle, colonia, ciudad" value="${esc(prefill.address)}" autocomplete="street-address">
      </label>

      <div class="cat-label">${hasPrefill ? "Confirma tus servicios" : "Que servicios ofreces?"}</div>
      <div class="chips">
        ${categoryChips}
      </div>

      <button type="submit" class="submit-btn" id="submitBtn" disabled>${hasPrefill ? "CONFIRMAR Y REGISTRARME" : "REGISTRARME GRATIS"}</button>
      <div class="error" id="errorMsg"></div>
    </form>

    <p class="note">
      Al registrarte aceptas los
      <a href="https://beautycita.com/privacy" style="color:#E8788A;">terminos y condiciones</a>
      de BeautyCita.
    </p>
  </div>

  <script>
    const form = document.getElementById('regForm');
    const btn = document.getElementById('submitBtn');
    const errEl = document.getElementById('errorMsg');

    // Enable button when name + phone + at least 1 category
    function validate() {
      const name = form.name.value.trim();
      const phone = form.phone.value.replace(/[^\\d]/g, '');
      const cats = form.querySelectorAll('input[name="categories"]:checked');
      btn.disabled = !(name.length >= 2 && phone.length >= 10 && cats.length > 0);
    }

    form.addEventListener('input', validate);
    form.addEventListener('change', validate);

    // Validate on load so prefilled forms enable the button immediately
    validate();

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      btn.disabled = true;
      btn.textContent = 'REGISTRANDO...';
      errEl.style.display = 'none';

      const cats = Array.from(form.querySelectorAll('input[name="categories"]:checked'))
        .map(el => el.value);

      const body = {
        name: form.name.value.trim(),
        phone: form.phone.value.trim(),
        address: form.address.value.trim() || null,
        categories: cats,
        ref: form.ref.value || null,
      };

      try {
        const resp = await fetch(window.location.pathname + window.location.search, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });

        const data = await resp.json();

        if (!resp.ok) {
          throw new Error(data.error || 'Error al registrar');
        }

        // Show success
        document.body.innerHTML = \`
          <div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:#FFF8F0;padding:32px;">
            <div style="text-align:center;max-width:360px;">
              <div style="width:80px;height:80px;border-radius:50%;background:rgba(76,175,80,0.12);display:flex;align-items:center;justify-content:center;margin:0 auto 24px;">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="#4CAF50"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
              </div>
              <h1 style="font-family:-apple-system,sans-serif;font-size:24px;font-weight:700;color:#2D2D2D;margin-bottom:8px;">Bienvenido a BeautyCita!</h1>
              <p style="font-family:-apple-system,sans-serif;font-size:15px;color:#666;line-height:1.6;">
                Tu salon ya esta visible para clientas cercanas. Te contactaran por WhatsApp.
              </p>
            </div>
          </div>
        \`;
      } catch (err) {
        errEl.textContent = err.message;
        errEl.style.display = 'block';
        btn.disabled = false;
        btn.textContent = '${hasPrefill ? "CONFIRMAR Y REGISTRARME" : "REGISTRARME GRATIS"}';
      }
    });
  </script>
</body>
</html>`;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  const url = new URL(req.url);
  const ref = url.searchParams.get("ref");

  // GET -> serve registration page (with prefill from discovered_salons if ref provided)
  if (req.method === "GET") {
    let prefill: Prefill = { ...EMPTY_PREFILL };

    if (ref) {
      try {
        const supabase = createClient(supabaseUrl, serviceKey);
        const { data: salon } = await supabase
          .from("discovered_salons")
          .select(
            "business_name, phone, whatsapp, location_address, location_city, feature_image_url, rating_average, specialties",
          )
          .eq("id", ref)
          .single();

        if (salon) {
          prefill.name = salon.business_name ?? "";
          prefill.phone = salon.whatsapp ?? salon.phone ?? "+52 ";
          prefill.address =
            [salon.location_address, salon.location_city].filter(Boolean).join(", ");
          prefill.categories = salon.specialties ?? [];
          prefill.photoUrl = salon.feature_image_url ?? null;
          prefill.rating = salon.rating_average ?? null;
        }
      } catch (err) {
        console.warn("Could not fetch discovered salon for prefill:", err);
        // Non-fatal — show empty form
      }
    }

    return htmlResp(registrationPage(ref, prefill));
  }

  // POST -> create business record
  if (req.method === "POST") {
    try {
      const body = await req.json();
      const { name, phone, address, categories, ref: refCode } = body;

      if (!name || name.trim().length < 2) {
        return json(
          { error: "Nombre del salon es requerido (min 2 caracteres)" },
          400,
        );
      }

      const rawPhone = (phone || "").replace(/[^\d+]/g, "");
      if (rawPhone.replace(/\D/g, "").length < 10) {
        return json({ error: "Numero de WhatsApp invalido" }, 400);
      }

      if (
        !categories ||
        !Array.isArray(categories) ||
        categories.length === 0
      ) {
        return json({ error: "Selecciona al menos un servicio" }, 400);
      }

      const normalizedPhone = rawPhone.startsWith("+")
        ? rawPhone
        : `+52${rawPhone}`;

      const supabase = createClient(supabaseUrl, serviceKey);

      // Create business (Tier 1 = discovery)
      const { data: business, error: insertErr } = await supabase
        .from("businesses")
        .insert({
          name: name.trim(),
          phone: normalizedPhone,
          whatsapp: normalizedPhone,
          address: address || null,
          tier: 1,
          is_active: true,
          service_categories: categories,
        })
        .select("id")
        .single();

      if (insertErr) {
        console.error("Business insert error:", insertErr);
        return json(
          { error: "No se pudo registrar. Intenta de nuevo." },
          500,
        );
      }

      // If ref code points to a discovered_salon, link it
      if (refCode) {
        const { error: updateErr } = await supabase
          .from("discovered_salons")
          .update({
            status: "registered",
            registered_business_id: business.id,
            registered_at: new Date().toISOString(),
          })
          .eq("id", refCode);

        if (updateErr) {
          console.warn("Could not link discovered salon:", updateErr);
          // Non-fatal — registration still succeeds
        }
      }

      return json({
        success: true,
        business_id: business.id,
        message: "Salon registrado exitosamente",
      });
    } catch (err) {
      console.error("salon-registro error:", err);
      return json({ error: String(err) }, 500);
    }
  }

  return json({ error: "Method not allowed" }, 405);
});
