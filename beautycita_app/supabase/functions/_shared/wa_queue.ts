// =============================================================================
// wa_queue.ts — Shared WhatsApp send-with-retry helper
// =============================================================================
// Used by any edge function that sends WhatsApp messages.
// On failure, queues the message for retry instead of silently dropping it.
// =============================================================================

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";

/** Backoff schedule: 5min, 15min, 60min */
const RETRY_DELAYS_MS = [5 * 60_000, 15 * 60_000, 60 * 60_000];

/**
 * Try to send a WhatsApp message. If it fails, queue it for retry.
 * Returns true if sent immediately, false if queued or failed.
 */
export async function sendWhatsAppWithRetry(
  supabase: SupabaseClient,
  phone: string,
  message: string,
  metadata: Record<string, unknown> = {}
): Promise<{ sent: boolean; queued: boolean }> {
  if (!phone || !message) {
    return { sent: false, queued: false };
  }

  const sent = await trySendWhatsApp(phone, message);

  if (sent) {
    return { sent: true, queued: false };
  }

  // Send failed — queue for retry
  const nextRetry = new Date(Date.now() + RETRY_DELAYS_MS[0]);

  const { error } = await supabase.from("wa_message_queue").insert({
    phone,
    message,
    status: "pending",
    attempts: 1,
    next_retry_at: nextRetry.toISOString(),
    last_error: "Initial send failed",
    metadata,
  });

  if (error) {
    console.error("[WA-QUEUE] Failed to queue message:", error.message);
    return { sent: false, queued: false };
  }

  console.log(`[WA-QUEUE] Queued message for ${phone}, retry at ${nextRetry.toISOString()}`);
  return { sent: false, queued: true };
}

/**
 * Raw WA send — no retry logic. Used internally and by queue processor.
 */
export async function trySendWhatsApp(
  phone: string,
  message: string
): Promise<boolean> {
  if (!BEAUTYPI_WA_URL || !phone) return false;

  try {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 8000);
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

    if (!res.ok) {
      console.error(`[WA] Send failed for ${phone}: ${res.status}`);
      return false;
    }

    const data = await res.json();
    return data.sent === true;
  } catch (err) {
    console.error(`[WA] Error sending to ${phone}:`, err);
    return false;
  }
}

/**
 * Process the WA retry queue. Called by marketing-automation cron.
 * Returns counts of sent/failed/remaining.
 */
export async function processWaRetryQueue(
  supabase: SupabaseClient
): Promise<{ sent: number; failed: number; remaining: number }> {
  const now = new Date();
  let sent = 0;
  let failed = 0;

  // Fetch pending messages whose next_retry_at has passed
  const { data: pending, error } = await supabase
    .from("wa_message_queue")
    .select("id, phone, message, attempts, max_attempts")
    .eq("status", "pending")
    .lte("next_retry_at", now.toISOString())
    .order("next_retry_at", { ascending: true })
    .limit(50);

  if (error) {
    console.error("[WA-QUEUE] Query error:", error.message);
    return { sent: 0, failed: 0, remaining: 0 };
  }

  if (!pending || pending.length === 0) {
    return { sent: 0, failed: 0, remaining: 0 };
  }

  console.log(`[WA-QUEUE] Processing ${pending.length} queued messages`);

  for (const msg of pending) {
    const ok = await trySendWhatsApp(msg.phone, msg.message);
    const newAttempts = msg.attempts + 1;

    if (ok) {
      await supabase
        .from("wa_message_queue")
        .update({ status: "sent", attempts: newAttempts })
        .eq("id", msg.id);
      sent++;
      console.log(`[WA-QUEUE] Sent queued message ${msg.id} to ${msg.phone}`);
    } else if (newAttempts >= msg.max_attempts) {
      // Max retries exhausted
      await supabase
        .from("wa_message_queue")
        .update({
          status: "failed",
          attempts: newAttempts,
          last_error: `Failed after ${newAttempts} attempts`,
        })
        .eq("id", msg.id);
      failed++;
      console.error(`[WA-QUEUE] Permanently failed ${msg.id} after ${newAttempts} attempts`);
    } else {
      // Schedule next retry with exponential backoff
      const delayIndex = Math.min(newAttempts - 1, RETRY_DELAYS_MS.length - 1);
      const nextRetry = new Date(now.getTime() + RETRY_DELAYS_MS[delayIndex]);

      await supabase
        .from("wa_message_queue")
        .update({
          attempts: newAttempts,
          next_retry_at: nextRetry.toISOString(),
          last_error: `Attempt ${newAttempts} failed`,
        })
        .eq("id", msg.id);
      console.log(`[WA-QUEUE] Retry ${newAttempts} for ${msg.id}, next at ${nextRetry.toISOString()}`);
    }
  }

  // Count remaining pending
  const { count } = await supabase
    .from("wa_message_queue")
    .select("id", { count: "exact", head: true })
    .eq("status", "pending");

  return { sent, failed, remaining: count ?? 0 };
}
