-- Down: rollback POS delivery completion schema.
-- Destructive once new-status rows exist. Down only on reset/empty state.

DO $$
DECLARE v_jobid bigint;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'pos-pickup-uncollected-sweeper';
  IF v_jobid IS NOT NULL THEN PERFORM cron.unschedule(v_jobid); END IF;
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'pos-claim-window-finalizer';
  IF v_jobid IS NOT NULL THEN PERFORM cron.unschedule(v_jobid); END IF;
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'pos-ship-tracking-nudge';
  IF v_jobid IS NOT NULL THEN PERFORM cron.unschedule(v_jobid); END IF;
END $$;

DROP TRIGGER IF EXISTS orders_owner_update_guard ON public.orders;
DROP FUNCTION IF EXISTS public.orders_owner_update_guard();

DELETE FROM app_config WHERE key IN (
  'pos_ship_claim_window_days',
  'pos_pickup_claim_window_days',
  'pos_pickup_uncollected_days',
  'pos_pickup_qr_expiry_days',
  'enable_pos_completion_v2'
);

DROP POLICY IF EXISTS "Disputes: user can insert own" ON public.disputes;
-- Caller must restore the prior INSERT policy if needed.

DROP INDEX IF EXISTS public.idx_orders_pickup_token_active;
DROP INDEX IF EXISTS public.idx_orders_claim_window;
DROP INDEX IF EXISTS public.idx_orders_awaiting_pickup;
DROP INDEX IF EXISTS public.idx_orders_pending;

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_pickup_consistency,
  DROP CONSTRAINT IF EXISTS orders_ship_consistency,
  DROP CONSTRAINT IF EXISTS orders_delivered_invariant,
  DROP CONSTRAINT IF EXISTS orders_completed_invariant,
  DROP CONSTRAINT IF EXISTS orders_refunded_invariant,
  DROP CONSTRAINT IF EXISTS orders_awaiting_pickup_invariant,
  DROP CONSTRAINT IF EXISTS orders_fulfillment_method_check,
  DROP CONSTRAINT IF EXISTS orders_refund_reason_check;

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check CHECK (
  status IN ('paid','shipped','delivered','refunded','cancelled')
);

CREATE INDEX idx_orders_pending ON public.orders (status, created_at)
  WHERE status IN ('paid','shipped');

ALTER TABLE public.orders
  DROP COLUMN IF EXISTS fulfillment_method,
  DROP COLUMN IF EXISTS pickup_qr_token_hash,
  DROP COLUMN IF EXISTS pickup_qr_expires_at,
  DROP COLUMN IF EXISTS pickup_qr_issued_at,
  DROP COLUMN IF EXISTS pickup_qr_revoked_at,
  DROP COLUMN IF EXISTS picked_up_at,
  DROP COLUMN IF EXISTS picked_up_by_staff_id,
  DROP COLUMN IF EXISTS claim_window_ends_at,
  DROP COLUMN IF EXISTS completed_at,
  DROP COLUMN IF EXISTS refund_reason;
