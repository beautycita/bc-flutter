// =============================================================================
// wa-queue-drain — Process pending rows in wa_notification_queue
// =============================================================================
// Invoked by cron (pg_cron → pg_notify → an external trigger, OR by an
// external cron hitting this endpoint). Drains up to N pending rows per call,
// sends via beautypi WA, and marks rows sent/failed.
//
// Templates understood by this drainer are purely server-side — we don't rely
// on WhatsApp Business pre-approved templates here since these go via the
// personal WA number. Body strings are rendered here with the queued variables.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";

const BATCH_SIZE = 20;
const MAX_ATTEMPTS = 3;
const RETRY_BACKOFF_MIN = [5, 15, 60]; // minutes between attempts 1→2, 2→3, 3→dead

const TEMPLATES: Record<string, (v: Record<string, string>) => string> = {
  walkin_confirmed: (v) =>
    `*${v.business_name ?? "Salon"}*: cita confirmada.\n\n` +
    `Servicio: ${v.service_name ?? "-"}\n` +
    `Con: ${v.staff_name ?? "-"}\n` +
    `Cuando: ${v.scheduled_at ?? "-"}\n\n` +
    `Es presencial, pagas al salon.`,
  walkin_salon_ghost: (v) =>
    `Lo sentimos — ${v.business_name ?? "el salon"} no pudo confirmar tu cita a tiempo. ` +
    `Si gustas reservar con otro salon cercano, descarga BeautyCita: https://beautycita.com/descarga`,
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function sendWa(phone: string, message: string): Promise<boolean> {
  if (!BEAUTYPI_WA_URL) return false;
  try {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 20_000);
    const res = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
      signal: ac.signal,
    });
    clearTimeout(t);
    if (!res.ok) return false;
    const data = await res.json();
    return data.sent === true;
  } catch (e) {
    console.error(`[wa-queue-drain] send error: ${e}`);
    return false;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("authorization") ?? "";
  const isCron = CRON_SECRET && authHeader === `Bearer ${CRON_SECRET}`;
  const isService = authHeader === `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`;
  if (!isCron && !isService) return json({ error: "Unauthorized" }, 401);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: pending } = await supabase
    .from("wa_notification_queue")
    .select("id, phone, template, variables, attempts")
    .eq("status", "pending")
    .lte("next_attempt_at", new Date().toISOString())
    .order("created_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (!pending || pending.length === 0) {
    return json({ drained: 0 });
  }

  let sent = 0;
  let failed = 0;
  let dead = 0;

  for (const row of pending) {
    const renderer = TEMPLATES[row.template as string];
    if (!renderer) {
      // Unknown template — mark dead, don't retry forever
      await supabase
        .from("wa_notification_queue")
        .update({
          status: "dead",
          last_error: `Unknown template: ${row.template}`,
        })
        .eq("id", row.id);
      dead++;
      continue;
    }

    const message = renderer((row.variables ?? {}) as Record<string, string>);
    const ok = await sendWa(row.phone as string, message);

    if (ok) {
      await supabase
        .from("wa_notification_queue")
        .update({ status: "sent", sent_at: new Date().toISOString(), attempts: (row.attempts as number) + 1 })
        .eq("id", row.id);
      sent++;
    } else {
      const nextAttempts = (row.attempts as number) + 1;
      if (nextAttempts >= MAX_ATTEMPTS) {
        await supabase
          .from("wa_notification_queue")
          .update({
            status: "dead",
            attempts: nextAttempts,
            last_error: "Max attempts exceeded",
          })
          .eq("id", row.id);
        dead++;
      } else {
        const backoffMin = RETRY_BACKOFF_MIN[nextAttempts - 1] ?? 60;
        await supabase
          .from("wa_notification_queue")
          .update({
            attempts: nextAttempts,
            last_error: "Send returned not-ok",
            next_attempt_at: new Date(Date.now() + backoffMin * 60_000).toISOString(),
          })
          .eq("id", row.id);
        failed++;
      }
    }
  }

  console.log(`[wa-queue-drain] sent=${sent} failed=${failed} dead=${dead}`);
  return json({ sent, failed, dead, total: pending.length });
});
