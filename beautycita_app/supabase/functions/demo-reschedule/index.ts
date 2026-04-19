// =============================================================================
// demo-reschedule — send labeled demo messages to the demo user's phone.
// =============================================================================
// All messages route to the caller's own verified phone (they registered
// it on the demo-wa-funnel to get here). Messages are LABELED to make clear
// which party they'd go to in real life:
//   • Mensaje al CLIENTE       — what the customer would see
//   • Mensaje a la ESTILISTA   — what the assigned stylist would see
//   • Mensaje a la NUEVA ESTILISTA — if a staff reassignment occurred
//
// Payload:
//   kind           : "reschedule" | "cancel"             (defaults to "reschedule")
//   service_name   : required
//   new_start      : required for reschedule, optional for cancel
//   client_name    : string
//   staff_name     : string  (the assigned stylist at the time of action)
//   old_staff_name : string  (when set + different from staff_name →
//                              3rd message goes to the "new stylist")
//   salon_name     : string
//   salon_phone    : string
//
// =============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";

const WA_API_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const WA_API_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Rate limit: 3 demo reschedule runs per user per 10 minutes (each run can
// fire up to 3 messages, so 9 WA sends/10min ceiling in the worst case).
const rateLimitMap = new Map<string, number[]>();
const RATE_WINDOW_MS = 10 * 60 * 1000;
const RATE_MAX = 3;

// Delay between sends so the demo user sees them arrive in sequence like
// real push ordering, not all at once.
const INTER_MESSAGE_DELAY_MS = 12_000;

interface DemoReschedulePayload {
  kind?: "reschedule" | "cancel";
  service_name?: string;
  new_start?: string;
  client_name?: string;
  staff_name?: string;
  old_staff_name?: string;
  salon_name?: string;
  salon_phone?: string;
}

function formatDateEs(isoDate: string): { date: string; time: string } {
  const d = new Date(isoDate);
  const days = ["dom", "lun", "mar", "mie", "jue", "vie", "sab"];
  const months = [
    "ene", "feb", "mar", "abr", "may", "jun",
    "jul", "ago", "sep", "oct", "nov", "dic",
  ];
  const date = `${days[d.getDay()]}, ${d.getDate()} ${months[d.getMonth()]}, ${d.getFullYear()}`;
  const hours = d.getHours();
  const minutes = d.getMinutes().toString().padStart(2, "0");
  const ampm = hours >= 12 ? "PM" : "AM";
  const h12 = hours % 12 || 12;
  return { date, time: `${h12}:${minutes} ${ampm}` };
}

async function sendDemo(phone: string, message: string): Promise<boolean> {
  if (!WA_API_URL) return false;
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 5000);
  try {
    const res = await fetch(`${WA_API_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${WA_API_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
      signal: ac.signal,
    });
    return res.ok;
  } catch {
    return false;
  } finally {
    clearTimeout(t);
  }
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

    const body: DemoReschedulePayload = await req.json();
    const kind = body.kind === "cancel" ? "cancel" : "reschedule";
    const isCancel = kind === "cancel";

    if (!body.service_name) {
      return new Response(
        JSON.stringify({ error: "service_name required" }),
        { status: 400, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }
    if (kind === "reschedule" && !body.new_start) {
      return new Response(
        JSON.stringify({ error: "new_start required for reschedule" }),
        { status: 400, headers: { ...corsHeaders(req), "Content-Type": "application/json" } }
      );
    }

    const fmt = body.new_start ? formatDateEs(body.new_start) : null;
    const phone = profile.phone.replace(/\D/g, "");
    const salon = body.salon_name || "Ejemplo Salon";
    const salonPhone = body.salon_phone || "+52 322 142 9800";
    const client = body.client_name || "Cliente";
    const service = body.service_name;
    const currentStaff = body.staff_name || "la estilista";
    const isReassignment = Boolean(
      body.old_staff_name &&
        body.staff_name &&
        body.old_staff_name !== body.staff_name,
    );
    const oldStaff = body.old_staff_name || currentStaff;

    // ─────────────────────────────────────────────────────────────────
    // Message 1: to the CUSTOMER
    // ─────────────────────────────────────────────────────────────────
    const clientMsg = (isCancel
      ? [
          `⚡ *[DEMO → CLIENTE]*`,
          ``,
          `*BeautyCita - Cita Cancelada*`,
          `Hola ${client}, tu cita de ${service} ha sido cancelada.`,
          ``,
          `Si necesitas reagendar, contacta al salon:`,
          `📞 ${salonPhone} | 💬 WhatsApp`,
          ``,
          `_Este es el mensaje que recibiria tu cliente._`,
        ]
      : [
          `⚡ *[DEMO → CLIENTE]*`,
          ``,
          `*BeautyCita - Cita Reagendada*`,
          `Hola ${client}, tu cita de ${service} ha sido reagendada.`,
          ``,
          `📅 Nueva fecha: ${fmt!.date}, ${fmt!.time}`,
          `💇 Estilista: ${isReassignment ? body.staff_name : currentStaff}`,
          `📍 Salon: ${salon}`,
          ``,
          `Si no puedes asistir, contacta al salon:`,
          `📞 ${salonPhone} | 💬 WhatsApp`,
          ``,
          `_Este es el mensaje que recibiria tu cliente._`,
        ]
    ).join("\n");

    // ─────────────────────────────────────────────────────────────────
    // Message 2: to the assigned STYLIST. On reassignment, this goes
    // to the OLD stylist (they're losing the booking); on a plain
    // reschedule or cancel, it goes to the currently-assigned one.
    // ─────────────────────────────────────────────────────────────────
    const stylistLabel = isReassignment
      ? "ESTILISTA ANTERIOR (reasignación)"
      : isCancel
        ? "ESTILISTA (cancelación)"
        : "ESTILISTA (reagendada)";

    const stylistMsg = (isCancel
      ? [
          `⚡ *[DEMO → ${stylistLabel}]*`,
          ``,
          `*BeautyCita - Cita Cancelada*`,
          `La cita de ${service} con ${client} ha sido cancelada.`,
          ``,
          `📍 Salon: ${salon}`,
          ``,
          `_Este es el mensaje que recibiria ${isReassignment ? oldStaff : currentStaff}._`,
        ]
      : isReassignment
        ? [
            `⚡ *[DEMO → ${stylistLabel}]*`,
            ``,
            `*BeautyCita - Cita Reasignada*`,
            `La cita de ${service} con ${client} ha sido reasignada a ${body.staff_name}.`,
            ``,
            `📅 Ya no aparecerá en tu agenda para ${fmt!.date}, ${fmt!.time}.`,
            `📍 Salon: ${salon}`,
            ``,
            `_Este es el mensaje que recibiria ${oldStaff}._`,
          ]
        : [
            `⚡ *[DEMO → ${stylistLabel}]*`,
            ``,
            `*BeautyCita - Cita Reagendada*`,
            `La cita de ${service} con ${client} ha sido movida.`,
            ``,
            `📅 Nueva fecha: ${fmt!.date}, ${fmt!.time}`,
            `📍 Salon: ${salon}`,
            ``,
            `_Este es el mensaje que recibiria ${currentStaff}._`,
          ]
    ).join("\n");

    // ─────────────────────────────────────────────────────────────────
    // Message 3 (optional): to the NEW stylist on reassignment.
    // ─────────────────────────────────────────────────────────────────
    const newStaffMsg = isReassignment && !isCancel
      ? [
          `⚡ *[DEMO → NUEVA ESTILISTA]*`,
          ``,
          `*BeautyCita - Cita Asignada*`,
          `Se te asignó la cita de ${service} con ${client}.`,
          ``,
          `📅 Fecha: ${fmt!.date}, ${fmt!.time}`,
          `📍 Salon: ${salon}`,
          ``,
          `_Este es el mensaje que recibiria ${body.staff_name}._`,
        ].join("\n")
      : null;

    // Send in sequence so the demo user sees the labeled messages
    // arrive in the same order they'd arrive for the real parties.
    let sent = 0;
    if (await sendDemo(phone, clientMsg)) sent++;
    await new Promise((r) => setTimeout(r, INTER_MESSAGE_DELAY_MS));
    if (await sendDemo(phone, stylistMsg)) sent++;
    if (newStaffMsg) {
      await new Promise((r) => setTimeout(r, INTER_MESSAGE_DELAY_MS));
      if (await sendDemo(phone, newStaffMsg)) sent++;
    }

    console.log(`[demo-reschedule] kind=${kind} reassignment=${isReassignment} sent=${sent}`);

    return new Response(
      JSON.stringify({ success: true, messages_sent: sent, kind, reassignment: isReassignment }),
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
