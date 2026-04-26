// =============================================================================
// wa-global-drain — drain wa_message_queue at 1 message / 20 seconds
// =============================================================================
// Single chokepoint for ALL outbound WhatsApp on the platform. Invoked every
// minute by pg_cron (X-Cron-Secret) and processes up to 3 messages, with the
// 20s pace gate enforced by claim_next_wa_message() in postgres.
//
// Watchdog runs first to requeue rows stuck in 'sending' for > 2 min (drainer
// crash / edge-fn timeout).
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { drainWaQueue, runWaWatchdog } from "../_shared/wa_queue.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("authorization") ?? "";
  const cronHeader = req.headers.get("x-cron-secret") ?? "";
  const isCron = CRON_SECRET && (cronHeader === CRON_SECRET || authHeader === `Bearer ${CRON_SECRET}`);
  const isService = authHeader === `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`;
  if (!isCron && !isService) return json({ error: "Unauthorized" }, 401);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const requeued = await runWaWatchdog(supabase);
  // 2 iterations × 20s sleep + 12s send timeout ≈ 44s — under the 60s edge
  // timeout with headroom for slow WA-proxy responses.
  const result = await drainWaQueue(supabase, 2);
  console.log(`[wa-global-drain] sent=${result.sent} failed=${result.failed} watchdog_requeued=${requeued}`);
  return json({ ok: true, requeued, ...result });
});
