// =============================================================================
// wa_queue.ts — Global WhatsApp send chokepoint (1 msg / 20s)
// =============================================================================
// EVERY WA send MUST go through enqueueWa(). Direct fetch() to /api/wa/send is
// forbidden — the BeautyPI account block risk requires platform-wide spacing.
//
// - enqueueWa()         → public; INSERTs into wa_message_queue, returns id
// - sendWhatsAppWithRetry() / trySendWhatsApp() → BACKWARD-COMPAT shims that
//                       now also enqueue (so callers that haven't migrated yet
//                       still hit the chokepoint)
// - drainWaQueue()      → called by the wa-queue-drain cron tick; respects 20s
//                       pace via the SQL claim_next_wa_message() function
// =============================================================================

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";

// Priority levels (lower = higher priority).
export const WA_PRIORITY = {
  CRITICAL: 0,        // OTP, security
  TRANSACTIONAL: 3,   // booking confirmation, walk-in, chat reply
  NORMAL: 5,          // default
  INFORMATIONAL: 7,   // reminders, follow-ups
  BULK: 9,            // outreach, demo funnel
} as const;

export interface EnqueueWaOpts {
  priority?: number;
  source?: string;
  idempotencyKey?: string;
  metadata?: Record<string, unknown>;
  scheduledFor?: Date;
}

/**
 * Enqueue a WA message for the global throttle queue.
 * Returns the queue row id (or existing id if idempotency_key matched).
 */
export async function enqueueWa(
  supabase: SupabaseClient,
  phone: string,
  message: string,
  opts: EnqueueWaOpts = {},
): Promise<string | null> {
  if (!phone || !message) return null;
  const { data, error } = await supabase.rpc("enqueue_wa_message", {
    p_phone: phone,
    p_message: message,
    p_priority: opts.priority ?? WA_PRIORITY.NORMAL,
    p_source: opts.source ?? null,
    p_idempotency_key: opts.idempotencyKey ?? null,
    p_metadata: opts.metadata ?? {},
    p_scheduled_for: opts.scheduledFor?.toISOString() ?? new Date().toISOString(),
  });
  if (error) {
    console.error("[WA-QUEUE] enqueueWa failed:", error.message);
    return null;
  }
  return data as string;
}

/**
 * Backward-compat: sendWhatsAppWithRetry now enqueues into the global queue
 * instead of attempting an immediate send. Keeps existing callers working.
 */
export async function sendWhatsAppWithRetry(
  supabase: SupabaseClient,
  phone: string,
  message: string,
  metadata: Record<string, unknown> = {},
): Promise<{ sent: boolean; queued: boolean }> {
  const id = await enqueueWa(supabase, phone, message, {
    priority: WA_PRIORITY.NORMAL,
    metadata,
    source: "legacy:sendWhatsAppWithRetry",
  });
  return { sent: false, queued: id !== null };
}

/**
 * Backward-compat: trySendWhatsApp now enqueues. Returns true if accepted into
 * the queue (will be sent within 20s × queue depth), false on validation failure.
 */
export async function trySendWhatsApp(phone: string, message: string): Promise<boolean> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) return false;
  const supabase = createClient(supabaseUrl, serviceKey);
  const id = await enqueueWa(supabase, phone, message, { source: "legacy:trySendWhatsApp" });
  return id !== null;
}

/**
 * INTERNAL — direct WA send. Only the drainer should call this.
 * Returns {sent, error} so the drainer can mark the queue row appropriately.
 */
async function rawSendWa(phone: string, message: string): Promise<{ sent: boolean; error?: string }> {
  if (!BEAUTYPI_WA_URL) return { sent: false, error: "WA URL not configured" };
  try {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 12000);
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
    if (!res.ok) return { sent: false, error: `wa proxy ${res.status}` };
    const data = await res.json();
    return data.sent === true
      ? { sent: true }
      : { sent: false, error: data.error ?? "wa proxy returned sent=false" };
  } catch (e) {
    return { sent: false, error: String(e) };
  }
}

/**
 * Drain the WA queue. Pulls up to N messages, respects the 20s pace gate via
 * claim_next_wa_message() (which atomically advances the pace row).
 *
 * Safe to invoke concurrently — the pace row + SKIP LOCKED guarantees only one
 * worker can claim any given message and that successive claims are ≥20s apart.
 *
 * Per-call budget is bounded by maxIterations (default 3) and edge-fn timeout.
 * If the pace gate blocks the first claim, we exit quickly (the next cron tick
 * will retry).
 */
export async function drainWaQueue(
  supabase: SupabaseClient,
  maxIterations = 3,
): Promise<{ sent: number; failed: number; skipped: number }> {
  let sent = 0;
  let failed = 0;
  let skipped = 0;

  for (let i = 0; i < maxIterations; i++) {
    const { data, error } = await supabase.rpc("claim_next_wa_message");
    if (error) {
      console.error("[WA-QUEUE] claim_next failed:", error.message);
      break;
    }
    const row = Array.isArray(data) ? data[0] : data;
    if (!row || !row.id) {
      // Either pace gate blocking us, or queue empty. Either way, stop.
      break;
    }

    const result = await rawSendWa(row.phone, row.message);

    if (result.sent) {
      await supabase.rpc("mark_wa_message_sent", { p_id: row.id });
      sent++;
      console.log(`[WA-QUEUE] sent ${row.id} → ${row.phone} (source: ${row.source ?? "n/a"})`);
    } else {
      // Backoff: 1m, 5m, 15m by attempt number.
      const backoffByAttempt = [60, 300, 900];
      const delay = backoffByAttempt[Math.min(row.attempts - 1, backoffByAttempt.length - 1)];
      await supabase.rpc("mark_wa_message_failed", {
        p_id: row.id,
        p_error: result.error ?? "unknown",
        p_retry_in_seconds: delay,
      });
      failed++;
      console.error(`[WA-QUEUE] send failed ${row.id} (attempt ${row.attempts}): ${result.error}`);
    }

    // Wait the inter-send gap. claim_next already reserved the pace, so we
    // sleep here to let the previous send actually deliver before the next
    // claim. 20s default; tunable via wa_send_pace.min_spacing_seconds.
    if (i < maxIterations - 1) {
      await new Promise((res) => setTimeout(res, 20_000));
    }
  }

  return { sent, failed, skipped };
}

/**
 * Watchdog: requeue 'sending' rows that have been stuck > 2 minutes.
 * Called from cron tick before drain.
 */
export async function runWaWatchdog(supabase: SupabaseClient): Promise<number> {
  const { data, error } = await supabase.rpc("wa_queue_watchdog");
  if (error) {
    console.error("[WA-QUEUE] watchdog failed:", error.message);
    return 0;
  }
  return Number(data ?? 0);
}

// ── DEPRECATED LEGACY EXPORT ────────────────────────────────────────────────
// processWaRetryQueue used backoff-based retry. Replaced by drainWaQueue +
// the global pace gate. Left as an alias for any out-of-tree callers.
export async function processWaRetryQueue(
  supabase: SupabaseClient,
): Promise<{ sent: number; failed: number; remaining: number }> {
  const r = await drainWaQueue(supabase);
  const { count } = await supabase
    .from("wa_message_queue")
    .select("id", { count: "exact", head: true })
    .eq("status", "pending");
  return { sent: r.sent, failed: r.failed, remaining: count ?? 0 };
}
