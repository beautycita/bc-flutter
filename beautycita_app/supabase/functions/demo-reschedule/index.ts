import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const WA_API_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const WA_API_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";


// Rate limit: 3 demo reschedules per user per 10 minutes
const rateLimitMap = new Map<string, number[]>();
const RATE_WINDOW_MS = 10 * 60 * 1000;
const RATE_MAX = 3;

function formatDateEs(isoDate: string): { date: string; time: string } {
  const d = new Date(isoDate);
  const days = ["dom", "lun", "mar", "mie", "jue", "vie", "sab"];
  const months = [
    "ene", "feb", "mar", "abr", "may", "jun",
    "jul", "ago", "sep", "oct", "nov", "dic",
  ];
  const day = days[d.getDay()];
  const month = months[d.getMonth()];
  const date = `${day}, ${d.getDate()} ${month}, ${d.getFullYear()}`;
  const hours = d.getHours();
  const minutes = d.getMinutes().toString().padStart(2, "0");
  const ampm = hours >= 12 ? "PM" : "AM";
  const h12 = hours % 12 || 12;
  const time = `${h12}:${minutes} ${ampm}`;
  return { date, time };
}

serve(async (req: Request) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });
  }

  try {
    // Auth: require authenticated user
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders(req), "Content-Type": "application/json" },
      });
    }

    // Rate limit
    const now = Date.now();
    const timestamps = rateLimitMap.get(user.id) ?? [];
    const recent = timestamps.filter((t) => now - t < RATE_WINDOW_MS);
    if (recent.length >= RATE_MAX) {
      return new Response(
        JSON.stringify({ error: "Demo limit reached. Try again in a few minutes." }),
        { status: 429, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }
    recent.push(now);
    rateLimitMap.set(user.id, recent);

    // Get user's verified phone from profile
    const adminClient = createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const { data: profile } = await adminClient
      .from("profiles")
      .select("phone")
      .eq("id", user.id)
      .single();

    if (!profile?.phone) {
      return new Response(
        JSON.stringify({ error: "Phone not verified" }),
        { status: 400, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }

    // Parse request body
    const {
      service_name,
      client_name,
      staff_name,
      salon_name,
      new_start,
      salon_phone,
    } = await req.json();

    if (!service_name || !new_start) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }

    const { date, time } = formatDateEs(new_start);
    const phone = profile.phone.replace(/\D/g, "");

    // Message 1: Stylist (immediate)
    const stylistMsg = [
      `⚡ *[DEMO] Mensaje para la estilista*`,
      ``,
      `*BeautyCita - Cita Reagendada*`,
      `La cita de ${service_name} con tu cliente ${client_name || "Cliente"} ha sido movida.`,
      ``,
      `📅 Nueva fecha: ${date}, ${time}`,
      `📍 Salon: ${salon_name || "Tu Salon"}`,
      ``,
      `_Este mensaje se envia automaticamente cuando un gerente mueve una cita en el calendario._`,
    ].join("\n");

    const ac1 = new AbortController();
    const t1 = setTimeout(() => ac1.abort(), 5000);
    await fetch(`${WA_API_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${WA_API_TOKEN}`,
      },
      body: JSON.stringify({ phone, message: stylistMsg }),
      signal: ac1.signal,
    });
    clearTimeout(t1);

    console.log(`[demo-reschedule] Stylist msg sent to ${phone.slice(-4)}`);

    // Message 2: Client (20 second delay)
    await new Promise((resolve) => setTimeout(resolve, 20000));

    const clientMsg = [
      `⚡ *[DEMO] Mensaje para el/la cliente*`,
      ``,
      `*BeautyCita - Cita Reagendada*`,
      `Tu cita de ${service_name} ha sido reagendada.`,
      ``,
      `📅 Nueva fecha: ${date}, ${time}`,
      `💇 Estilista: ${staff_name || "Tu Estilista"}`,
      `📍 Salon: ${salon_name || "Tu Salon"}`,
      ``,
      `Si no puedes asistir, contacta al salon:`,
      `📞 ${salon_phone || "+52 322 142 9800"} | 💬 WhatsApp`,
      ``,
      `_Este mensaje se envia automaticamente para que tu cliente siempre este informado._`,
    ].join("\n");

    const ac2 = new AbortController();
    const t2 = setTimeout(() => ac2.abort(), 5000);
    await fetch(`${WA_API_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${WA_API_TOKEN}`,
      },
      body: JSON.stringify({ phone, message: clientMsg }),
      signal: ac2.signal,
    });
    clearTimeout(t2);

    console.log(`[demo-reschedule] Client msg sent to ${phone.slice(-4)}`);

    return new Response(
      JSON.stringify({ success: true, messages_sent: 2 }),
      { status: 200, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("[demo-reschedule] Error:", e);
    return new Response(
      JSON.stringify({ error: "Failed to send demo messages" }),
      { status: 500, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
    );
  }
});
