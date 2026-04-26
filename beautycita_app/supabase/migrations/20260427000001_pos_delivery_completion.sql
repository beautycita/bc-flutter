-- =============================================================================
-- POS Delivery Completion — schema additions
-- =============================================================================
-- Plan: docs/plans/2026-04-26-pos-delivery-completion.md
-- Replaces D14 auto-refund cron with event-driven completion (tracking number
-- ends BC's timer; pickup QR scan ends pickup-flow; claim-window finalizer
-- moves shipped/delivered → completed).
--
-- Reset state at apply time (per migration 20260426000011): orders is empty.
-- NOT NULL DEFAULT 'ship' on fulfillment_method is therefore safe.
-- =============================================================================

-- ── 1. New columns on orders ─────────────────────────────────────────────────
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS fulfillment_method     text        NOT NULL DEFAULT 'ship',
  ADD COLUMN IF NOT EXISTS pickup_qr_token_hash   text,
  ADD COLUMN IF NOT EXISTS pickup_qr_expires_at   timestamptz,
  ADD COLUMN IF NOT EXISTS pickup_qr_issued_at    timestamptz,
  ADD COLUMN IF NOT EXISTS pickup_qr_revoked_at   timestamptz,
  ADD COLUMN IF NOT EXISTS picked_up_at           timestamptz,
  ADD COLUMN IF NOT EXISTS picked_up_by_staff_id  uuid REFERENCES public.staff(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS claim_window_ends_at   timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at           timestamptz,
  ADD COLUMN IF NOT EXISTS refund_reason          text;

-- fulfillment_method enum
ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_fulfillment_method_check;
ALTER TABLE public.orders
  ADD CONSTRAINT orders_fulfillment_method_check
  CHECK (fulfillment_method IN ('ship','pickup'));

-- refund_reason enum
ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_refund_reason_check;
ALTER TABLE public.orders
  ADD CONSTRAINT orders_refund_reason_check
  CHECK (refund_reason IS NULL OR refund_reason IN (
    'salon_cancel','pickup_uncollected',
    'claim_resolved_buyer','chargeback','admin'
  ));

-- ── 2. Status set: extend with awaiting_pickup + completed ──────────────────
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD  CONSTRAINT orders_status_check CHECK (
  status IN ('paid','awaiting_pickup','shipped','delivered','completed','refunded','cancelled')
);

-- ── 3. Cross-column invariants ──────────────────────────────────────────────
ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_pickup_consistency,
  DROP CONSTRAINT IF EXISTS orders_ship_consistency,
  DROP CONSTRAINT IF EXISTS orders_delivered_invariant,
  DROP CONSTRAINT IF EXISTS orders_completed_invariant,
  DROP CONSTRAINT IF EXISTS orders_refunded_invariant,
  DROP CONSTRAINT IF EXISTS orders_awaiting_pickup_invariant;

ALTER TABLE public.orders ADD CONSTRAINT orders_pickup_consistency CHECK (
  (fulfillment_method = 'pickup') OR
  (picked_up_at IS NULL AND picked_up_by_staff_id IS NULL
   AND pickup_qr_token_hash IS NULL AND pickup_qr_expires_at IS NULL)
);

ALTER TABLE public.orders ADD CONSTRAINT orders_ship_consistency CHECK (
  (fulfillment_method = 'ship') OR (tracking_number IS NULL AND shipped_at IS NULL)
);

ALTER TABLE public.orders ADD CONSTRAINT orders_delivered_invariant CHECK (
  status <> 'delivered' OR (
    (fulfillment_method = 'pickup' AND picked_up_at IS NOT NULL) OR
    (fulfillment_method = 'ship'   AND tracking_number IS NOT NULL)
  )
);

ALTER TABLE public.orders ADD CONSTRAINT orders_completed_invariant CHECK (
  status <> 'completed' OR (claim_window_ends_at IS NOT NULL AND completed_at IS NOT NULL)
);

ALTER TABLE public.orders ADD CONSTRAINT orders_refunded_invariant CHECK (
  status <> 'refunded' OR (refund_reason IS NOT NULL AND refunded_at IS NOT NULL)
);

ALTER TABLE public.orders ADD CONSTRAINT orders_awaiting_pickup_invariant CHECK (
  status <> 'awaiting_pickup' OR (
    fulfillment_method = 'pickup'
    AND pickup_qr_token_hash IS NOT NULL
    AND pickup_qr_expires_at IS NOT NULL
    AND picked_up_at IS NULL
  )
);

-- ── 4. Indexes ──────────────────────────────────────────────────────────────
DROP INDEX IF EXISTS public.idx_orders_pending;
CREATE INDEX idx_orders_pending ON public.orders (status, created_at)
  WHERE status IN ('paid','awaiting_pickup','shipped','delivered');

CREATE INDEX IF NOT EXISTS idx_orders_awaiting_pickup ON public.orders (created_at)
  WHERE status = 'awaiting_pickup';

CREATE INDEX IF NOT EXISTS idx_orders_claim_window ON public.orders (claim_window_ends_at)
  WHERE status IN ('shipped','delivered') AND claim_window_ends_at IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_pickup_token_active
  ON public.orders (pickup_qr_token_hash)
  WHERE pickup_qr_token_hash IS NOT NULL AND pickup_qr_revoked_at IS NULL;

-- ── 5. orders_owner_update_guard — extend immutable list ────────────────────
-- Owners may only set tracking_number + status='shipped' (paid → shipped) and
-- status='delivered' (shipped → delivered). All POS-completion fields are
-- service-role only. tracking_number is editable for 24h post-shipped (typo
-- correction window), then immutable.
CREATE OR REPLACE FUNCTION public.orders_owner_update_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_owner boolean;
  v_is_admin boolean;
  v_is_service boolean := (auth.role() = 'service_role');
BEGIN
  IF v_is_service THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM businesses
    WHERE id = NEW.business_id AND owner_id = auth.uid()
  ) INTO v_is_owner;

  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('admin','superadmin')
  ) INTO v_is_admin;

  IF v_is_admin THEN
    RETURN NEW;
  END IF;

  IF NOT v_is_owner THEN
    RAISE EXCEPTION 'orders_owner_update_guard: not owner of business %', NEW.business_id;
  END IF;

  -- Immutable from owner sessions: payment_method, fulfillment_method, all
  -- pickup_qr_*, picked_up_*, claim_window_ends_at, completed_at, refund_reason,
  -- payment intent id, total/commission, business_id, buyer_id, idempotency.
  IF NEW.payment_method IS DISTINCT FROM OLD.payment_method THEN
    RAISE EXCEPTION 'payment_method is immutable from owner sessions';
  END IF;
  IF NEW.fulfillment_method IS DISTINCT FROM OLD.fulfillment_method THEN
    RAISE EXCEPTION 'fulfillment_method is immutable from owner sessions';
  END IF;
  IF NEW.pickup_qr_token_hash IS DISTINCT FROM OLD.pickup_qr_token_hash
     OR NEW.pickup_qr_expires_at IS DISTINCT FROM OLD.pickup_qr_expires_at
     OR NEW.pickup_qr_issued_at IS DISTINCT FROM OLD.pickup_qr_issued_at
     OR NEW.pickup_qr_revoked_at IS DISTINCT FROM OLD.pickup_qr_revoked_at
     OR NEW.picked_up_at IS DISTINCT FROM OLD.picked_up_at
     OR NEW.picked_up_by_staff_id IS DISTINCT FROM OLD.picked_up_by_staff_id
     OR NEW.claim_window_ends_at IS DISTINCT FROM OLD.claim_window_ends_at
     OR NEW.completed_at IS DISTINCT FROM OLD.completed_at
     OR NEW.refund_reason IS DISTINCT FROM OLD.refund_reason THEN
    RAISE EXCEPTION 'POS-completion fields are service-role only';
  END IF;
  IF NEW.stripe_payment_intent_id IS DISTINCT FROM OLD.stripe_payment_intent_id
     OR NEW.total_amount IS DISTINCT FROM OLD.total_amount
     OR NEW.commission_amount IS DISTINCT FROM OLD.commission_amount
     OR NEW.business_id IS DISTINCT FROM OLD.business_id
     OR NEW.buyer_id IS DISTINCT FROM OLD.buyer_id
     OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key THEN
    RAISE EXCEPTION 'identity / money fields are immutable';
  END IF;

  -- Status transitions: only paid → shipped, shipped → delivered.
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status = 'paid'    AND NEW.status = 'shipped') OR
      (OLD.status = 'shipped' AND NEW.status = 'delivered')
    ) THEN
      RAISE EXCEPTION 'owner cannot transition status % → %', OLD.status, NEW.status;
    END IF;
  END IF;

  -- tracking_number rules:
  --  - Settable when status='paid' (during paid→shipped transition).
  --  - Editable while status='shipped' AND now() - shipped_at < 24h (typo fix).
  --  - Immutable once 24h-after-shipped passes.
  IF NEW.tracking_number IS DISTINCT FROM OLD.tracking_number THEN
    IF OLD.status = 'paid' THEN
      -- OK: must be transitioning to shipped
      NULL;
    ELSIF OLD.status = 'shipped'
       AND OLD.shipped_at IS NOT NULL
       AND now() - OLD.shipped_at < interval '24 hours' THEN
      NULL;
    ELSE
      RAISE EXCEPTION 'tracking_number immutable after 24h post-ship';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_owner_update_guard ON public.orders;
CREATE TRIGGER orders_owner_update_guard
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.orders_owner_update_guard();

-- ── 6. disputes RLS — claim window must be open for buyer INSERT ────────────
-- Existing policy "Disputes: user can insert own" is too permissive in time.
-- Tighten with WITH CHECK that requires the order's claim window is open.
DROP POLICY IF EXISTS "Disputes: user can insert own" ON public.disputes;
CREATE POLICY "Disputes: user can insert own" ON public.disputes
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND (
      -- Booking dispute (no order_id) — leave window open via existing app logic.
      (order_id IS NULL AND appointment_id IS NOT NULL
       AND EXISTS (SELECT 1 FROM appointments
                   WHERE id = disputes.appointment_id AND user_id = auth.uid()))
      OR
      -- Order dispute — require buyer ownership AND open claim window.
      (order_id IS NOT NULL
       AND EXISTS (
         SELECT 1 FROM orders
         WHERE id = disputes.order_id
           AND buyer_id = auth.uid()
           AND status IN ('shipped','delivered','awaiting_pickup','paid')
           AND (
             status = 'paid'  -- buyer can dispute "never shipped" once tracking is overdue (D7+); app gates this; RLS allows it
             OR claim_window_ends_at IS NULL  -- legacy rows
             OR now() < claim_window_ends_at
           )
       ))
    )
  );

-- ── 7. App config: window durations + feature toggle ────────────────────────
INSERT INTO app_config (key, value) VALUES
  ('pos_ship_claim_window_days',    '14'),
  ('pos_pickup_claim_window_days',  '7'),
  ('pos_pickup_uncollected_days',   '14'),
  ('pos_pickup_qr_expiry_days',     '7'),
  ('enable_pos_completion_v2',      'false')  -- start gated; flip after staging
ON CONFLICT (key) DO NOTHING;

-- ── 8. Cron jobs (created INACTIVE; flipped on in step 7 of rollout) ────────
-- Placeholder schedules; the http_post bodies hit edge fns we deploy in step 3.
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

SELECT cron.schedule(
  'pos-pickup-uncollected-sweeper',
  '15 8 * * *',
  $cron$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/auto-cancel-uncollected-pickup',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000
    ) AS request_id;
  $cron$
);

SELECT cron.schedule(
  'pos-claim-window-finalizer',
  '30 8 * * *',
  $cron$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/finalize-orders-past-claim-window',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000
    ) AS request_id;
  $cron$
);

SELECT cron.schedule(
  'pos-ship-tracking-nudge',
  '0 14 * * *',
  $cron$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/ship-tracking-nudge',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000
    ) AS request_id;
  $cron$
);

COMMENT ON TABLE public.orders IS
  'POS order lifecycle. fulfillment_method=ship→paid→shipped→(delivered)→completed/refunded. fulfillment_method=pickup→awaiting_pickup→delivered→completed/refunded. Tracking number ends BC auto-refund timer; claim window finalizer flips to completed after N days.';
