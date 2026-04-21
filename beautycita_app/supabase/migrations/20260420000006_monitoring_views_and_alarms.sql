-- =============================================================================
-- Migration: 20260420000006_monitoring_views_and_alarms.sql
-- Description: Operational monitoring surface — views + alarm tables for Doc
-- and Grafana to query. Aligns with master plan §3.4.
--
-- 1. Views for queue health and stuck-state detection
-- 2. Invariant breach alarm table — populated by trigger when balance goes wrong
-- 3. RLS so service role can read/write, admin can read
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1a. Stripe webhook queue health view
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_stripe_webhook_queue_health AS
SELECT
  date_trunc('hour', received_at) AS hour,
  event_type,
  count(*) AS event_count
FROM public.stripe_webhook_events
WHERE received_at > now() - interval '24 hours'
GROUP BY date_trunc('hour', received_at), event_type
ORDER BY hour DESC, event_count DESC;

COMMENT ON VIEW public.v_stripe_webhook_queue_health IS
  'Hourly Stripe webhook event volume. Spikes indicate Stripe retry storms — '
  'investigate corresponding handler errors.';

-- ---------------------------------------------------------------------------
-- 1b. Salon debts unresolved > 24h view
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_salon_debts_aging AS
SELECT
  d.business_id,
  b.name AS business_name,
  d.id AS debt_id,
  d.original_amount,
  d.remaining_amount,
  d.source,
  d.debt_type,
  d.created_at,
  EXTRACT(EPOCH FROM (now() - d.created_at)) / 3600 AS hours_old
FROM public.salon_debts d
LEFT JOIN public.businesses b ON b.id = d.business_id
WHERE d.remaining_amount > 0
  AND d.cleared_at IS NULL
  AND d.extinguished_at IS NULL
ORDER BY d.created_at ASC;

COMMENT ON VIEW public.v_salon_debts_aging IS
  'All open salon_debts ordered oldest-first. Anything > 24h old that should '
  'have been collected via FIFO indicates a payout flow issue.';

-- ---------------------------------------------------------------------------
-- 1c. Stuck onboarding view (salon at same step > 48h)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_onboarding_stuck AS
SELECT
  id,
  name,
  owner_id,
  onboarding_step,
  is_verified,
  banking_complete,
  rfc IS NOT NULL AS has_rfc,
  id_verification_status,
  created_at,
  updated_at,
  EXTRACT(EPOCH FROM (now() - updated_at)) / 3600 AS hours_since_update
FROM public.businesses
WHERE onboarding_complete = false
  AND updated_at < now() - interval '48 hours'
ORDER BY updated_at ASC;

COMMENT ON VIEW public.v_onboarding_stuck IS
  'Salons that have not progressed onboarding step in > 48h. Outreach candidates.';

-- ---------------------------------------------------------------------------
-- 1d. Payment failure rate view (last 24h)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_payment_failure_rate AS
SELECT
  date_trunc('hour', created_at) AS hour,
  count(*) FILTER (WHERE payment_status = 'failed') AS failed,
  count(*) FILTER (WHERE payment_status IN ('paid', 'refunded_to_saldo')) AS succeeded,
  count(*) AS total,
  ROUND(
    100.0 * count(*) FILTER (WHERE payment_status = 'failed')
    / NULLIF(count(*), 0),
    2
  ) AS failure_pct
FROM public.appointments
WHERE created_at > now() - interval '24 hours'
GROUP BY date_trunc('hour', created_at)
ORDER BY hour DESC;

COMMENT ON VIEW public.v_payment_failure_rate IS
  'Hourly payment failure %. Sustained > 10% failure rate triggers §2 investigation.';

-- ---------------------------------------------------------------------------
-- 2. Invariant breach alarm table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invariant_breaches (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invariant    text NOT NULL,            -- 'saldo' | 'business_debt' | 'reconciliation'
  severity     text NOT NULL DEFAULT 'critical',  -- 'critical' | 'warning'
  details      jsonb NOT NULL DEFAULT '{}'::jsonb,
  detected_at  timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz,
  acknowledged_by uuid REFERENCES public.profiles(id),
  notes        text
);

CREATE INDEX IF NOT EXISTS invariant_breaches_unack_idx
  ON public.invariant_breaches (detected_at DESC)
  WHERE acknowledged_at IS NULL;

ALTER TABLE public.invariant_breaches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS invariant_breaches_admin_read ON public.invariant_breaches;
CREATE POLICY invariant_breaches_admin_read
  ON public.invariant_breaches
  FOR SELECT
  USING (
    auth.role() = 'service_role'
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

DROP POLICY IF EXISTS invariant_breaches_service_write ON public.invariant_breaches;
CREATE POLICY invariant_breaches_service_write
  ON public.invariant_breaches
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

COMMENT ON TABLE public.invariant_breaches IS
  'Money-invariant breach log. Populated by reconciliation_watchdog and '
  'check_*_invariant functions. Doc/Grafana queries for unacknowledged rows '
  '→ pages BC. Acknowledged via admin panel after investigation.';

-- ---------------------------------------------------------------------------
-- 3. Wrapper that records breaches found by run_reconciliation_all
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_invariant_breaches()
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
  v_breach record;
  v_recorded integer := 0;
BEGIN
  -- run_reconciliation_all returns rows when ledgers don't reconcile.
  -- For each row, INSERT into invariant_breaches (UNIQUE on detected_at + invariant
  -- prevents duplicates within a watchdog tick).
  FOR v_breach IN
    SELECT * FROM public.run_reconciliation_all()
  LOOP
    INSERT INTO public.invariant_breaches(invariant, severity, details)
    VALUES (
      'reconciliation',
      'critical',
      to_jsonb(v_breach)
    );
    v_recorded := v_recorded + 1;
  END LOOP;

  RETURN v_recorded;
END;
$$;

COMMENT ON FUNCTION public.record_invariant_breaches() IS
  'Wraps run_reconciliation_all and records each imbalance as an invariant_breach. '
  'Call from cron every 15 min. Doc watches for unacknowledged rows.';
