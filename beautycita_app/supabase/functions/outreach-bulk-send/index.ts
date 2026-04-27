// =============================================================================
// outreach-bulk-send — admin/superadmin bulk send to discovered_salons + businesses
// =============================================================================
// Actions:
//   enqueue       — admin: validate, create job + recipients, return job_id
//   drain         — cron (X-Cron-Secret): process up to 8 WA + 30 email per tick
//   get_job       — admin: return job + counts + recent recipient outcomes
//   cancel_job    — admin: cancel queued sends
//   preview       — admin: render a template for one recipient (resolved text + footer)
//   unsubscribe   — public (no auth): validate HMAC token, write opt-out, return ok
//
// Compliance:
//   - Anti-spam footer auto-appended every send (LFPDPPP / CAN-SPAM)
//   - 14-day cooldown on invite templates per discovered_salon
//   - opt-out registry checked before every send
//   - HMAC unsubscribe link per recipient
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.16";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";
import { enqueueWa, WA_PRIORITY } from "../_shared/wa_queue.ts";

// ── env ─────────────────────────────────────────────────────────────────────
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const WA_API_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const WA_API_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";

const SMTP_HOST = Deno.env.get("SMTP_HOST") ?? "smtp.ionos.mx";
const SMTP_PORT = parseInt(Deno.env.get("SMTP_PORT") ?? "587");
const SMTP_USER = Deno.env.get("SMTP_USER") ?? "";
const SMTP_PASS = Deno.env.get("SMTP_PASS") ?? "";
const SMTP_OUTREACH_FROM = Deno.env.get("SMTP_OUTREACH_FROM") ?? "hello@beautycita.com";
const SMTP_OUTREACH_FROM_NAME = "Equipo de BeautyCita";

const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const UNSUB_SECRET = Deno.env.get("OUTREACH_UNSUB_SECRET") ?? CRON_SECRET; // fallback during rollout

// WA is enqueue-only — the per-tick cap just controls how fast we hand the
// recipients off to the global throttle queue. Bumping to MAX_RECIPIENTS_PER_JOB
// so a 100-recipient bulk job clears in a single drain tick (the global queue
// then paces actual delivery at 1/20s).
const DRAIN_PER_TICK_WA = 100;
const DRAIN_PER_TICK_EMAIL = 30;
const MAX_RECIPIENTS_PER_JOB = 100;
const INVITE_COOLDOWN_DAYS = 14;

// ── helpers ─────────────────────────────────────────────────────────────────

function json(body: unknown, status = 200, req?: Request): Response {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (req) Object.assign(headers, corsHeaders(req));
  return new Response(JSON.stringify(body), { status, headers });
}

function normalizePhone(p: string | null | undefined): string | null {
  if (!p) return null;
  const digits = p.replace(/[^0-9]/g, "");
  return digits.length >= 10 ? digits.slice(-10) : null;
}

function normalizeEmail(e: string | null | undefined): string | null {
  if (!e) return null;
  const v = e.trim().toLowerCase();
  return v.includes("@") ? v : null;
}

async function hmacToken(payload: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(UNSUB_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(payload));
  const b64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return b64;
}

async function buildUnsubLink(recipient: { phone?: string | null; email?: string | null }, channel: string): Promise<string> {
  const phone = normalizePhone(recipient.phone);
  const email = normalizeEmail(recipient.email);
  const id = phone ?? email ?? "";
  const payload = `${channel}.${id}`;
  const sig = await hmacToken(payload);
  const token = btoa(JSON.stringify({ c: channel, p: phone, e: email })).replace(/=+$/, "");
  return `https://beautycita.com/baja.html?t=${token}.${sig}`;
}

async function verifyUnsubToken(t: string): Promise<{ phone: string | null; email: string | null; channel: string } | null> {
  try {
    const [tokenB64, sig] = t.split(".");
    if (!tokenB64 || !sig) return null;
    const tokenJson = atob(tokenB64.padEnd(tokenB64.length + (4 - tokenB64.length % 4) % 4, "="));
    const { c, p, e } = JSON.parse(tokenJson);
    const id = p ?? e ?? "";
    const expected = await hmacToken(`${c}.${id}`);
    if (expected !== sig) return null;
    return { phone: p ?? null, email: e ?? null, channel: c };
  } catch {
    return null;
  }
}

// ── auth ────────────────────────────────────────────────────────────────────

async function verifyAdmin(token: string, db: ReturnType<typeof createClient>): Promise<{ id: string; role: string } | null> {
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return null;
  const { data: profile } = await db
    .from("profiles").select("role").eq("id", user.id).single();
  if (!profile || !["admin", "superadmin"].includes(profile.role)) return null;
  return { id: user.id, role: profile.role };
}

// ── variable substitution ──────────────────────────────────────────────────

function substituteVars(
  template: string,
  vars: Record<string, string | number | null | undefined>,
): string {
  let out = template;
  for (const [k, v] of Object.entries(vars)) {
    const re = new RegExp(`\\{${k}\\}`, "g");
    out = out.replace(re, String(v ?? ""));
  }
  return out;
}

function buildVars(
  recipientTable: "discovered_salons" | "businesses",
  row: Record<string, any>,
  manualVars: Record<string, string>,
): Record<string, string> {
  if (recipientTable === "discovered_salons") {
    return {
      salon_name: row.business_name ?? "tu salón",
      city: row.location_city ?? "tu ciudad",
      state: row.location_state ?? "",
      rating: String(row.rating_average ?? ""),
      review_count: String(row.rating_count ?? "0"),
      interest_count: String(row.interest_count ?? "0"),
      ...manualVars,
    };
  }
  // businesses
  return {
    salon_name: row.name ?? "tu salón",
    city: row.city ?? "tu ciudad",
    state: row.state ?? "",
    rating: String(row.average_rating ?? ""),
    review_count: String(row.total_reviews ?? "0"),
    salon_url: row.slug ? `https://beautycita.com/p/${row.slug}` : "https://beautycita.com",
    services_count: String(row.services_count ?? "0"),
    portfolio_count: String(row.portfolio_count ?? "0"),
    stylist_count: String(row.stylist_count ?? "0"),
    last_booking_days: String(row.last_booking_days ?? "30+"),
    owner_first_name: row.owner_first_name ?? "Hola",
    ...manualVars,
  };
}

// ── footer (anti-spam compliance) ──────────────────────────────────────────

function appendWaFooter(body: string, salonName: string, isInvite: boolean): string {
  // Invite (unsolicited cold outreach): full LFPDPPP footer with reason-for-
  // contact + BAJA opt-out. Registered (consented account holders): lighter
  // identity-only footer, no opt-out language.
  if (isInvite) {
    return `${body.trimEnd()}

—
BeautyCita S.A. de C.V. · Plaza Caracol L27, Puerto Vallarta, Jal., MX
Te contactamos porque ${salonName} aparece como negocio público.
Para no recibir más mensajes, responde: BAJA`;
  }
  return `${body.trimEnd()}

—
BeautyCita S.A. de C.V.`;
}

function buildEmailHtml(bodyText: string, salonName: string, unsubLink: string, isInvite: boolean): string {
  const bodyHtml = bodyText
    .split("\n")
    .map((line) => line ? `<p style="margin:0 0 12px;">${escapeHtml(line)}</p>` : "")
    .join("");
  return `<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8"><title>BeautyCita</title></head>
<body style="margin:0;padding:24px;background:#F5F0E8;font-family:Georgia,'Times New Roman',serif;color:#2a2a2a;line-height:1.55;">
  <div style="max-width:600px;margin:0 auto;background:#fff;padding:32px 28px;border-radius:6px;">
    ${bodyHtml}
    <hr style="border:0;border-top:1px solid #ddd;margin:24px 0 16px;">
    <div style="font-size:12px;color:#777;line-height:1.5;font-family:sans-serif;">
      <p style="margin:0 0 8px;">
        Recibes este mensaje porque <strong>${escapeHtml(salonName)}</strong> aparece como negocio público en nuestro directorio.<br>
        You are receiving this because <strong>${escapeHtml(salonName)}</strong> is listed as a public business in our directory.
      </p>
      <p style="margin:0 0 8px;">
        <strong>BeautyCita S.A. de C.V.</strong><br>
        Plaza Caracol Local 27, Puerto Vallarta, Jalisco, México · CP 48330<br>
        <a href="mailto:hello@beautycita.com" style="color:#777;">hello@beautycita.com</a>
      </p>
      <p style="margin:0;">
        <a href="${unsubLink}" style="color:#777;">Darme de baja / Unsubscribe</a>
        &nbsp;·&nbsp;
        <a href="https://beautycita.com/privacidad" style="color:#777;">Aviso de privacidad / Privacy notice</a>
      </p>
    </div>
  </div>
</body></html>`;
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

// ── send: WhatsApp (enqueue into global throttle queue) ────────────────────
// All bulk WA sends go through the platform's global 1msg/20s queue. The local
// drainer never invokes the WA proxy directly — it hands the rendered message
// off to enqueueWa() and the wa-global-drain cron paces actual delivery.

async function sendWa(
  db: ReturnType<typeof createClient>,
  phone: string,
  message: string,
  source: string,
  idempotencyKey?: string,
): Promise<{ ok: boolean; error?: string; queueId?: string }> {
  const id = await enqueueWa(db, phone, message, {
    priority: WA_PRIORITY.BULK,
    source,
    idempotencyKey,
  });
  return id ? { ok: true, queueId: id } : { ok: false, error: "enqueue failed" };
}

// ── send: Email (SMTP) ─────────────────────────────────────────────────────

let _smtpTransport: any = null;
function smtp(): any {
  if (_smtpTransport) return _smtpTransport;
  if (!SMTP_USER || !SMTP_PASS) throw new Error("SMTP not configured");
  _smtpTransport = nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_PORT === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
  return _smtpTransport;
}

async function sendEmail(
  to: string,
  subject: string,
  html: string,
  text: string,
): Promise<{ ok: boolean; error?: string }> {
  try {
    await smtp().sendMail({
      from: { name: SMTP_OUTREACH_FROM_NAME, address: SMTP_OUTREACH_FROM },
      to,
      subject,
      html,
      text,
      headers: {
        "List-Unsubscribe": `<mailto:hello@beautycita.com?subject=unsubscribe>`,
        "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
      },
    });
    return { ok: true };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

// ── core send for one recipient ────────────────────────────────────────────

async function sendOneRecipient(
  db: ReturnType<typeof createClient>,
  job: any,
  recipient: any,
  template: any,
): Promise<{ status: string; error?: string; logId?: string }> {
  // Load fresh row (denorm fields might have changed since enqueue)
  const tbl = recipient.recipient_table;
  const { data: row } = await db.from(tbl).select("*").eq("id", recipient.recipient_id).single();
  if (!row) return { status: "failed", error: "row not found" };

  // Re-check opt-out at send time (canonical). The salon's contact email
  // lives on businesses.email (profiles has no email column).
  const phone = normalizePhone(row.whatsapp || row.phone);
  const email = normalizeEmail(row.email ?? null);
  const { data: optedOut } = await db.rpc("is_marketing_opted_out", {
    p_phone: phone, p_email: email, p_channel: job.channel,
  });
  if (optedOut === true) return { status: "skipped_optout" };

  // Re-check 14d cooldown for invite templates on discovered_salons
  if (template.is_invite && tbl === "discovered_salons") {
    const { data: inCd } = await db.rpc("is_invite_in_cooldown", {
      p_discovered_salon_id: recipient.recipient_id, p_days: INVITE_COOLDOWN_DAYS,
    });
    if (inCd === true) return { status: "skipped_cooldown" };
  }

  // Pull computed vars for businesses (services_count, portfolio_count, etc.)
  let extraVars: Record<string, any> = {};
  if (tbl === "businesses") {
    const { data: extras } = await db.rpc("get_business_outreach_vars", { p_business_id: recipient.recipient_id });
    extraVars = (Array.isArray(extras) ? extras[0] : extras) ?? {};
  }
  const vars = buildVars(tbl as "discovered_salons" | "businesses", { ...row, ...extraVars }, job.manual_vars || {});
  const salonName = vars.salon_name || "tu salón";

  if (job.channel === "wa") {
    if (!phone) return { status: "skipped_no_channel", error: "no phone" };
    const body = substituteVars(template.body_template, vars);
    const fullMessage = appendWaFooter(body, salonName, !!template.is_invite);
    // Idempotency: same job + recipient must never enqueue twice.
    const idem = `bulk-${job.id}-${recipient.recipient_id}`;
    const send = await sendWa(db, phone, fullMessage, `outreach-bulk:${job.id}`, idem);

    const { data: log } = await db.from("salon_outreach_log").insert({
      discovered_salon_id: tbl === "discovered_salons" ? recipient.recipient_id : null,
      business_id: tbl === "businesses" ? recipient.recipient_id : null,
      channel: "wa_message",
      recipient_phone: phone,
      message_text: fullMessage,
      template_id: template.id,
      bulk_job_id: job.id,
      rp_user_id: job.admin_user_id,
      delivered: send.ok, // = "queued for delivery" — actual send happens later
      error_text: send.error ?? null,
    }).select("id").single();

    // Note: status='sent' here means "accepted into the global throttle queue".
    // Final delivery is paced at 1/20s by wa-global-drain. The bulk_outreach_jobs
    // sent_count therefore reflects queued, not delivered — UI labels "Encolados".
    return send.ok
      ? { status: "sent", logId: log?.id }
      : { status: "failed", error: send.error, logId: log?.id };
  }

  if (job.channel === "email") {
    if (!email) return { status: "skipped_no_channel", error: "no email" };
    const unsub = await buildUnsubLink({ phone, email }, "email");
    const allVars = { ...vars, unsubscribe_link: unsub };
    const subject = template.subject ? substituteVars(template.subject, allVars) : `BeautyCita — ${salonName}`;
    const body = substituteVars(template.body_template, allVars);
    const html = buildEmailHtml(body, salonName, unsub, !!template.is_invite);
    const text = `${body}\n\n—\nBeautyCita S.A. de C.V. · Plaza Caracol L27, Puerto Vallarta, Jal., MX · CP 48330\nDarme de baja: ${unsub}\nAviso de privacidad: https://beautycita.com/privacidad`;
    const send = await sendEmail(email, subject, html, text);

    const { data: log } = await db.from("salon_outreach_log").insert({
      discovered_salon_id: tbl === "discovered_salons" ? recipient.recipient_id : null,
      business_id: tbl === "businesses" ? recipient.recipient_id : null,
      channel: "email",
      recipient_phone: phone,
      recipient_email: email,
      message_text: body,
      subject,
      template_id: template.id,
      bulk_job_id: job.id,
      rp_user_id: job.admin_user_id,
      delivered: send.ok,
      error_text: send.error ?? null,
    }).select("id").single();

    return send.ok
      ? { status: "sent", logId: log?.id }
      : { status: "failed", error: send.error, logId: log?.id };
  }

  return { status: "failed", error: `unknown channel: ${job.channel}` };
}

// =============================================================================
// HANDLER
// =============================================================================

serve(async (req: Request) => {
  const pre = handleCorsPreflightIfOptions(req, "x-cron-secret");
  if (pre) return pre;

  try {
    const body = await req.json();
    const action = body.action as string;
    const db = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // ────── PUBLIC: unsubscribe (no auth, HMAC-validated token) ─────────────
    if (action === "unsubscribe") {
      const t = String(body.token ?? "");
      const verified = await verifyUnsubToken(t);
      if (!verified) return json({ error: "Invalid token" }, 400, req);
      const ip = req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? null;
      const ua = req.headers.get("user-agent") ?? null;
      const { error } = await db.from("marketing_opt_outs").upsert({
        phone: verified.phone,
        email: verified.email,
        source: "unsubscribe_link",
        unsubscribe_token: t,
        ip,
        user_agent: ua,
      }, { onConflict: verified.phone ? "phone" : "email", ignoreDuplicates: false });
      if (error) console.error("[outreach-bulk-send:unsubscribe]", error);
      return json({ ok: true }, 200, req);
    }

    // ────── CRON: drain (X-Cron-Secret auth) ─────────────────────────────────
    if (action === "drain") {
      const cronSecret = req.headers.get("x-cron-secret") ?? "";
      if (!CRON_SECRET || cronSecret !== CRON_SECRET) {
        return json({ error: "Unauthorized" }, 401, req);
      }

      // Channel param: each cron entry calls with one channel, in parallel.
      // Default 'all' is for manual debug only — running both serially can
      // exceed the 60s edge timeout and leave queued rows in flight.
      const requestedChannel = (body.channel as string) ?? "all";
      const channels = requestedChannel === "all"
        ? ["wa", "email"]
        : (["wa", "email"].includes(requestedChannel) ? [requestedChannel] : []);
      if (channels.length === 0) {
        return json({ error: "channel must be wa|email|all" }, 400, req);
      }

      // Pull queued recipients across all draining/queued jobs
      const channelLimits: Record<string, number> = { wa: DRAIN_PER_TICK_WA, email: DRAIN_PER_TICK_EMAIL };
      const totals = { sent: 0, skipped: 0, failed: 0 };

      for (const ch of channels) {
        const limit = channelLimits[ch];
        const { data: rows } = await db
          .from("bulk_outreach_recipients")
          .select(`
            id, recipient_table, recipient_id, recipient_phone, recipient_email,
            job:bulk_outreach_jobs!inner(id, admin_user_id, channel, template_id, manual_vars, status)
          `)
          .eq("status", "queued")
          .eq("job.channel", ch)
          .in("job.status", ["queued", "draining"])
          .order("queued_at", { ascending: true })
          .limit(limit);

        if (!rows || rows.length === 0) continue;

        // Promote jobs touched in this batch from queued → draining
        const jobIds = [...new Set(rows.map((r: any) => r.job.id))];
        await db
          .from("bulk_outreach_jobs")
          .update({ status: "draining", started_at: new Date().toISOString() })
          .in("id", jobIds)
          .eq("status", "queued");

        for (const r of rows) {
          // Load template
          const { data: template } = await db
            .from("outreach_templates").select("*").eq("id", (r as any).job.template_id).single();
          if (!template) {
            await db.from("bulk_outreach_recipients").update({
              status: "failed", error_text: "template missing", attempt_count: 1,
            }).eq("id", (r as any).id);
            totals.failed++;
            continue;
          }

          const result = await sendOneRecipient(db, (r as any).job, r, template);

          await db.from("bulk_outreach_recipients").update({
            status: result.status,
            error_text: result.error ?? null,
            log_id: result.logId ?? null,
            attempt_count: 1,
            sent_at: result.status === "sent" ? new Date().toISOString() : null,
          }).eq("id", (r as any).id);

          if (result.status === "sent") totals.sent++;
          else if (result.status === "failed") totals.failed++;
          else totals.skipped++;

          // Email sends happen synchronously via SMTP; pace 1s between rows.
          // WA sends are now enqueue-only (global throttle drains separately),
          // so no inner-loop sleep is needed for that channel.
          if (ch === "email") await new Promise((res) => setTimeout(res, 1000));
        }
      }

      return json({ ok: true, ...totals }, 200, req);
    }

    // ────── ADMIN-AUTHED ACTIONS (require admin/superadmin) ──────────────────
    const authHeader = req.headers.get("authorization") ?? "";
    const authToken = authHeader.replace(/^Bearer\s+/i, "");
    const admin = await verifyAdmin(authToken, db);
    if (!admin) return json({ error: "Unauthorized" }, 401, req);

    // ────── enqueue ──────────────────────────────────────────────────────────
    if (action === "enqueue") {
      const {
        channel,
        template_id,
        recipient_table,
        recipient_ids,
        manual_vars = {},
      } = body as {
        channel: "wa" | "email";
        template_id: string;
        recipient_table: "discovered_salons" | "businesses";
        recipient_ids: string[];
        manual_vars?: Record<string, string>;
      };

      if (!["wa", "email"].includes(channel)) return json({ error: "channel must be wa|email" }, 400, req);
      if (!template_id) return json({ error: "template_id required" }, 400, req);
      if (!["discovered_salons", "businesses"].includes(recipient_table)) {
        return json({ error: "recipient_table invalid" }, 400, req);
      }
      if (!Array.isArray(recipient_ids) || recipient_ids.length === 0) {
        return json({ error: "recipient_ids must be non-empty" }, 400, req);
      }
      // Dedup. UNIQUE (job_id, recipient_table, recipient_id) on the recipients
      // table would otherwise reject the entire batch on a single duplicate.
      const dedupedIds = [...new Set(recipient_ids.filter(Boolean))];
      if (dedupedIds.length === 0) {
        return json({ error: "recipient_ids must be non-empty" }, 400, req);
      }
      if (dedupedIds.length > MAX_RECIPIENTS_PER_JOB) {
        return json({ error: `max ${MAX_RECIPIENTS_PER_JOB} recipients per job` }, 400, req);
      }

      const { data: template } = await db
        .from("outreach_templates").select("*").eq("id", template_id).single();
      if (!template || !template.is_active) return json({ error: "template not found or inactive" }, 404, req);
      if (template.channel !== "whatsapp" && template.channel !== "email") {
        return json({ error: "template channel invalid" }, 400, req);
      }
      if ((channel === "wa") !== (template.channel === "whatsapp")) {
        return json({ error: "channel does not match template channel" }, 400, req);
      }
      if (template.recipient_table && template.recipient_table !== "both" && template.recipient_table !== recipient_table) {
        return json({ error: "template not allowed on this recipient_table" }, 400, req);
      }

      // Load recipient rows for preview + per-row pre-checks
      const { data: rows } = await db.from(recipient_table)
        .select("*").in("id", dedupedIds);
      if (!rows || rows.length === 0) return json({ error: "no recipients found" }, 404, req);

      // Build first-recipient preview (with computed business vars if applicable)
      let firstExtra: Record<string, any> = {};
      if (recipient_table === "businesses") {
        const { data: extras } = await db.rpc("get_business_outreach_vars", { p_business_id: rows[0].id });
        firstExtra = (Array.isArray(extras) ? extras[0] : extras) ?? {};
      }
      const firstVars = buildVars(recipient_table, { ...rows[0], ...firstExtra }, manual_vars);
      const previewBody = substituteVars(template.body_template, firstVars);
      const previewMessage = channel === "wa"
        ? appendWaFooter(previewBody, firstVars.salon_name, !!template.is_invite)
        : previewBody;

      // Create job
      const { data: job, error: jobErr } = await db.from("bulk_outreach_jobs").insert({
        admin_user_id: admin.id,
        channel,
        template_id,
        recipient_table,
        manual_vars,
        total_count: rows.length,
        preview_first_message: previewMessage,
      }).select("id").single();
      if (jobErr || !job) return json({ error: jobErr?.message ?? "job create failed" }, 500, req);

      // Insert recipient rows. Both businesses and discovered_salons carry
      // their contact email directly — no profiles lookup needed.
      const recipientRows = rows.map((r: any) => ({
        job_id: job.id,
        recipient_table,
        recipient_id: r.id,
        recipient_phone: normalizePhone(r.whatsapp || r.phone),
        recipient_email: normalizeEmail(r.email ?? null),
      }));
      const { error: recErr } = await db.from("bulk_outreach_recipients").insert(recipientRows);
      if (recErr) return json({ error: recErr.message }, 500, req);

      return json({ ok: true, job_id: job.id, total: rows.length, preview: previewMessage }, 200, req);
    }

    // ────── get_job ──────────────────────────────────────────────────────────
    if (action === "get_job") {
      const { job_id } = body;
      if (!job_id) return json({ error: "job_id required" }, 400, req);
      const { data: job } = await db.from("bulk_outreach_jobs").select("*").eq("id", job_id).single();
      if (!job) return json({ error: "job not found" }, 404, req);
      const { data: recipients } = await db.from("bulk_outreach_recipients")
        .select("id, recipient_table, recipient_id, status, error_text, sent_at")
        .eq("job_id", job_id)
        .order("queued_at", { ascending: true })
        .limit(200);
      return json({ job, recipients: recipients ?? [] }, 200, req);
    }

    // ────── cancel_job ──────────────────────────────────────────────────────
    if (action === "cancel_job") {
      const { job_id } = body;
      if (!job_id) return json({ error: "job_id required" }, 400, req);
      const { data: job } = await db.from("bulk_outreach_jobs").select("admin_user_id, status").eq("id", job_id).single();
      if (!job) return json({ error: "job not found" }, 404, req);
      if (job.admin_user_id !== admin.id && admin.role !== "superadmin") {
        return json({ error: "Not your job" }, 403, req);
      }
      if (!["queued", "draining"].includes(job.status)) {
        return json({ error: `cannot cancel job in status ${job.status}` }, 400, req);
      }
      await db.from("bulk_outreach_jobs").update({ status: "cancelled", cancelled_at: new Date().toISOString() }).eq("id", job_id);
      // Mark queued recipients as skipped (distinct status for audit clarity)
      await db.from("bulk_outreach_recipients").update({ status: "skipped_cancelled", error_text: "job cancelled" })
        .eq("job_id", job_id).eq("status", "queued");
      return json({ ok: true }, 200, req);
    }

    // ────── preview ─────────────────────────────────────────────────────────
    if (action === "preview") {
      const { template_id, recipient_table, recipient_id, channel, manual_vars = {} } = body;
      if (!template_id || !recipient_table || !recipient_id || !channel) {
        return json({ error: "template_id, recipient_table, recipient_id, channel required" }, 400, req);
      }
      const { data: template } = await db.from("outreach_templates").select("*").eq("id", template_id).single();
      if (!template) return json({ error: "template not found" }, 404, req);
      const { data: row } = await db.from(recipient_table).select("*").eq("id", recipient_id).single();
      if (!row) return json({ error: "recipient not found" }, 404, req);

      let extraVars: Record<string, any> = {};
      if (recipient_table === "businesses") {
        const { data: extras } = await db.rpc("get_business_outreach_vars", { p_business_id: recipient_id });
        extraVars = (Array.isArray(extras) ? extras[0] : extras) ?? {};
      }
      const vars = buildVars(recipient_table as any, { ...row, ...extraVars }, manual_vars);
      const phone = normalizePhone(row.whatsapp || row.phone);
      const email = normalizeEmail(row.email ?? null);
      const unsub = await buildUnsubLink({ phone, email }, channel);
      const allVars = { ...vars, unsubscribe_link: unsub };
      const bodyText = substituteVars(template.body_template, allVars);
      const subject = template.subject ? substituteVars(template.subject, allVars) : null;

      // Cooldown / opt-out flags for UI
      const { data: optedOut } = await db.rpc("is_marketing_opted_out", { p_phone: phone, p_email: email, p_channel: channel });
      let cooldown = false;
      if (template.is_invite && recipient_table === "discovered_salons") {
        const { data } = await db.rpc("is_invite_in_cooldown", { p_discovered_salon_id: recipient_id, p_days: INVITE_COOLDOWN_DAYS });
        cooldown = data === true;
      }

      const final = channel === "wa"
        ? appendWaFooter(bodyText, vars.salon_name, !!template.is_invite)
        : bodyText;
      return json({
        subject,
        body: final,
        salon_name: vars.salon_name,
        unsubscribe_link: unsub,
        opted_out: optedOut === true,
        cooldown_active: cooldown,
        has_phone: !!phone,
        has_email: !!email,
      }, 200, req);
    }

    return json({ error: `unknown action: ${action}` }, 400, req);
  } catch (e) {
    console.error("[outreach-bulk-send]", e);
    return json({ error: String(e) }, 500, req);
  }
});
