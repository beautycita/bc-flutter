// =============================================================================
// cash-trust-notify — Drain pending cash_state_log rows + send salon emails
// =============================================================================
// Cron-driven: every 2 minutes via pg_cron + private.cron_config secret.
// Reads businesses_cash_state_log rows where email_sent_at IS NULL,
// resolves the matching notification_templates row, sends SMTP, marks sent.
//
// Templates (event_type, channel=email, recipient_type=salon):
//   - cash_activated   → vars: salon_name, min_tx
//   - cash_suspended   → vars: salon_name, tax_debt, threshold, payment_url
//   - cash_reactivated → vars: salon_name
//
// Auth: X-Cron-Secret header from cron_config.cron_secret.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.16";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { applyTemplate } from "../_shared/notification_templates.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const SMTP_HOST = Deno.env.get("SMTP_HOST") ?? "smtp.ionos.mx";
const SMTP_PORT = parseInt(Deno.env.get("SMTP_PORT") ?? "587");
const SMTP_USER = Deno.env.get("SMTP_USER") ?? "";
const SMTP_PASS = Deno.env.get("SMTP_PASS") ?? "";
const SMTP_FROM = Deno.env.get("SMTP_FROM") ?? "no-reply@beautycita.com";
const SMTP_FROM_NAME = Deno.env.get("SMTP_FROM_NAME") ?? "BeautyCita";

const PUBLIC_BASE_URL = Deno.env.get("PUBLIC_BASE_URL") ?? "https://beautycita.com";

const DRAIN_PER_TICK = 50;

function json(body: unknown, status = 200, req?: Request): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...(req ? corsHeaders(req) : {}), "Content-Type": "application/json" },
  });
}

let _smtp: any = null;
function smtp() {
  if (_smtp) return _smtp;
  if (!SMTP_USER || !SMTP_PASS) throw new Error("SMTP not configured");
  _smtp = nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_PORT === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
  return _smtp;
}

async function sendEmail(to: string, subject: string, body: string) {
  await smtp().sendMail({
    from: { name: SMTP_FROM_NAME, address: SMTP_FROM },
    to,
    subject,
    text: body,
  });
}

interface TemplateBlob {
  subject: string;
  body: string;
}

function parseTemplate(raw: string): TemplateBlob {
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed.subject === "string" && typeof parsed.body === "string") {
      return parsed;
    }
  } catch (_) { /* fallthrough */ }
  return { subject: "BeautyCita", body: raw };
}

serve(async (req) => {
  const cors = handleCorsPreflightIfOptions(req);
  if (cors) return cors;

  // Auth: cron secret OR service-role key
  const cronSecret = req.headers.get("X-Cron-Secret") ?? "";
  const auth = req.headers.get("Authorization") ?? "";
  const isService = auth === `Bearer ${SUPABASE_SERVICE_KEY}`;
  const expectedSecret = Deno.env.get("CRON_SECRET") ?? "";

  if (!isService && (!cronSecret || cronSecret !== expectedSecret)) {
    return json({ error: "Unauthorized" }, 401, req);
  }

  const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // Pull pending state-log rows (email_sent_at IS NULL).
  const { data: pending, error: pendingErr } = await db
    .from("businesses_cash_state_log")
    .select("id, business_id, transition, tax_debt_at, tx_count_at, state_fingerprint, created_at")
    .is("email_sent_at", null)
    .order("created_at", { ascending: true })
    .limit(DRAIN_PER_TICK);

  if (pendingErr) return json({ error: pendingErr.message }, 500, req);
  if (!pending || pending.length === 0) {
    return json({ ok: true, processed: 0 }, 200, req);
  }

  const minTx = await db
    .from("app_config")
    .select("value")
    .eq("key", "cash_trust_min_tx")
    .single()
    .then((r: any) => parseInt(r?.data?.value ?? "50"));
  const threshold = await db
    .from("app_config")
    .select("value")
    .eq("key", "cash_block_tax_debt_threshold")
    .single()
    .then((r: any) => parseFloat(r?.data?.value ?? "1000"));

  let sent = 0, skipped = 0, failed = 0;
  const errors: string[] = [];

  for (const row of pending) {
    try {
      const { data: biz } = await db
        .from("businesses")
        .select("id, name, email, owner_id, is_test")
        .eq("id", row.business_id)
        .single();

      if (!biz || biz.is_test) {
        await db.from("businesses_cash_state_log")
          .update({ email_sent_at: new Date().toISOString() })
          .eq("id", row.id);
        skipped++;
        continue;
      }

      // Recipient: business email, fallback to owner profile email
      let to = biz.email as string | null;
      if (!to && biz.owner_id) {
        const { data: prof } = await db
          .from("profiles")
          .select("id")
          .eq("id", biz.owner_id)
          .single();
        if (prof) {
          const { data: { user } } = await db.auth.admin.getUserById(prof.id);
          to = user?.email ?? null;
        }
      }
      if (!to) {
        await db.from("businesses_cash_state_log")
          .update({ email_sent_at: new Date().toISOString() })
          .eq("id", row.id);
        skipped++;
        continue;
      }

      const eventType = `cash_${row.transition}`;
      const { data: tpl } = await db
        .from("notification_templates")
        .select("template_es")
        .eq("event_type", eventType)
        .eq("channel", "email")
        .eq("recipient_type", "salon")
        .eq("is_active", true)
        .single();

      if (!tpl?.template_es) {
        skipped++;
        continue;
      }

      const blob = parseTemplate(tpl.template_es);
      const vars: Record<string, string> = {
        salon_name: biz.name ?? "Salon",
        min_tx: String(minTx),
        tax_debt: row.tax_debt_at != null ? Number(row.tax_debt_at).toFixed(2) : "0",
        threshold: threshold.toFixed(2),
        payment_url: `${PUBLIC_BASE_URL}/business/cash-trust-pay`,
      };
      const subject = applyTemplate(blob.subject, vars);
      const body = applyTemplate(blob.body, vars);

      await sendEmail(to, subject, body);

      await db.from("businesses_cash_state_log")
        .update({ email_sent_at: new Date().toISOString() })
        .eq("id", row.id);

      sent++;
    } catch (e) {
      failed++;
      errors.push(`${row.id}: ${String(e).slice(0, 200)}`);
    }
  }

  return json({ ok: true, processed: pending.length, sent, skipped, failed, errors }, 200, req);
});
