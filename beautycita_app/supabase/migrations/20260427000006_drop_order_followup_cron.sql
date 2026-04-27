-- =============================================================================
-- Drop the legacy order-followup cron job
-- =============================================================================
-- Replaced 2026-04-26 by:
--   - pos-pickup-uncollected-sweeper (D14 sweep for uncollected pickups)
--   - pos-claim-window-finalizer     (shipped/delivered → completed)
--   - pos-ship-tracking-nudge        (gentle D3/D5/D7/D10/D13 push, no auto-refund)
-- The neutered stub edge function stays for now and is deleted in a follow-up.
-- =============================================================================

DO $$
DECLARE v_jobid bigint;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname IN (
    'order-followup', 'order-followup-daily', 'pos-order-followup'
  ) LIMIT 1;
  IF v_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_jobid);
    RAISE NOTICE 'Dropped legacy cron jobid=%', v_jobid;
  ELSE
    RAISE NOTICE 'No legacy order-followup cron found';
  END IF;
END $$;
