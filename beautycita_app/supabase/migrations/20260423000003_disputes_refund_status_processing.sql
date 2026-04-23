-- =============================================================================
-- Fix: disputes.refund_status CHECK constraint rejects 'processing' lock marker
-- =============================================================================
-- process-dispute-refund performs an atomic compare-and-swap by writing
-- refund_status='processing' before calling processRefund(). The CHECK
-- constraint only allowed ('pending','processed','failed'), so every admin
-- refund has been returning 500 "Failed to acquire lock on dispute".
-- Caught by bughunter flow disputes-file-and-resolve.
-- =============================================================================

ALTER TABLE public.disputes
  DROP CONSTRAINT IF EXISTS disputes_refund_status_check;

ALTER TABLE public.disputes
  ADD CONSTRAINT disputes_refund_status_check
  CHECK (
    refund_status IS NULL
    OR refund_status = ANY (ARRAY['pending','processing','processed','failed'])
  );
