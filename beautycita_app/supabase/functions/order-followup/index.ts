// =============================================================================
// order-followup — RETIRED 2026-04-26
// =============================================================================
// Replaced by:
//   - ship-tracking-nudge      (gentle D3/D5/D7/D10/D13 reminders, no auto-refund)
//   - auto-cancel-uncollected-pickup (D14 sweeper for uncollected pickups)
//   - finalize-orders-past-claim-window (claim-window finalizer)
//
// This function is left as a no-op stub so the existing cron job's
// net.http_post doesn't 404 during rollout. After the new crons are stable,
// drop the cron job entirely and delete this directory.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

serve(() =>
  new Response(
    JSON.stringify({ retired: true, replaced_by: ["ship-tracking-nudge", "auto-cancel-uncollected-pickup", "finalize-orders-past-claim-window"] }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  )
);
