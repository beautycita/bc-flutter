// salon-registro edge function
// Serves a mobile-friendly registration page for salon owners.
// Salon owners reach this via the WhatsApp invite link.
// GET  → HTML registration form
// POST → Create business record + return success page

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};

function html(body: string, status = 200) {
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
  { slug: "unas", label: "Unas", emoji: "💅" },
  { slug: "cabello", label: "Cabello", emoji: "✂️" },
  { slug: "pestanas_cejas", label: "Pestanas y Cejas", emoji: "👁️" },
  { slug: "maquillaje", label: "Maquillaje", emoji: "🎨" },
  { slug: "facial", label: "Facial", emoji: "🧖" },
  { slug: "cuerpo_spa", label: "Cuerpo y Spa", emoji: "🧘" },
  { slug: "cuidado_especializado", label: "Especializado", emoji: "⭐" },
];

// ---------------------------------------------------------------------------
// HTML templates
// ---------------------------------------------------------------------------

function registrationPage(ref: string | null): string {
  const categoryChips = CATEGORIES.map(
    (c) => `
    <label class="chip">
      <input type="checkbox" name="categories" value="${c.slug}">
      <span>${c.emoji} ${c.label}</span>
    </label>`
  ).join("\n");

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Registra tu salon - BeautyCita</title>
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
    <h1>Registra tu salon</h1>
    <p>Recibe clientes nuevas por BeautyCita</p>
    <div class="badge">Gratis &middot; 60 segundos &middot; Sin tarjeta</div>
  </div>

  <div class="form-wrap">
    <form id="regForm" method="POST">
      <input type="hidden" name="ref" value="${ref ?? ""}">

      <label class="field">
        <span class="label">Nombre del salon</span>
        <input type="text" name="name" placeholder="Ej: Salon Rosa" required minlength="2" autocomplete="organization">
      </label>

      <label class="field">
        <span class="label">WhatsApp</span>
        <input type="tel" name="phone" placeholder="+52 33 1234 5678" value="+52 " required autocomplete="tel">
      </label>

      <label class="field">
        <span class="label">Direccion (opcional)</span>
        <input type="text" name="address" placeholder="Calle, colonia, ciudad" autocomplete="street-address">
      </label>

      <div class="cat-label">Que servicios ofreces?</div>
      <div class="chips">
        ${categoryChips}
      </div>

      <button type="submit" class="submit-btn" id="submitBtn" disabled>REGISTRARME GRATIS</button>
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
        const resp = await fetch(window.location.pathname, {
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
        btn.textContent = 'REGISTRARME GRATIS';
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

  // GET → serve registration page
  if (req.method === "GET") {
    return html(registrationPage(ref));
  }

  // POST → create business record
  if (req.method === "POST") {
    try {
      const body = await req.json();
      const { name, phone, address, categories, ref: refCode } = body;

      if (!name || name.trim().length < 2) {
        return json({ error: "Nombre del salon es requerido (min 2 caracteres)" }, 400);
      }

      const rawPhone = (phone || "").replace(/[^\d+]/g, "");
      if (rawPhone.replace(/\D/g, "").length < 10) {
        return json({ error: "Numero de WhatsApp invalido" }, 400);
      }

      if (!categories || !Array.isArray(categories) || categories.length === 0) {
        return json({ error: "Selecciona al menos un servicio" }, 400);
      }

      const normalizedPhone = rawPhone.startsWith("+") ? rawPhone : `+52${rawPhone}`;

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
        return json({ error: "No se pudo registrar. Intenta de nuevo." }, 500);
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
