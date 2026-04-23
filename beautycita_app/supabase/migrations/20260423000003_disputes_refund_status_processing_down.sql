-- Rollback: revert disputes_refund_status_check to the pre-'processing' set.
-- Only safe if every 'processing' row has been resolved to processed/failed first.
ALTER TABLE public.disputes
  DROP CONSTRAINT IF EXISTS disputes_refund_status_check;

ALTER TABLE public.disputes
  ADD CONSTRAINT disputes_refund_status_check
  CHECK (
    refund_status IS NULL
    OR refund_status = ANY (ARRAY['pending','processed','failed'])
  );
