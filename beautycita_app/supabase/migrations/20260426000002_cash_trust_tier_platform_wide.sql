-- =============================================================================
-- Cash Payments Trust Tier — platform-wide
-- =============================================================================
-- Policy (Kriket 2026-04-26):
--
-- Cash on ANY booking (regular + ExpressCita) is gated on salon trust:
--   1. Salon must have ≥ cash_trust_min_tx BC-processed transactions (paid +
--      completed; refunds/cancellations excluded). Eligibility activates ONCE.
--   2. Once activated, refund churn does NOT auto-deactivate. Only tax-debt
--      threshold deactivates: open `tax_obligation` debt ≥
--      cash_block_tax_debt_threshold (default ₱1000).
--   3. Reactivation is binary: ALL `tax_obligation` debt = 0. No partial-
--      payment / 30-day reset complexity.
--   4. is_test businesses are never eligible (always cash-blocked).
--
-- Customer side: if salon not eligible → cash tile silently absent. No copy.
-- Salon side: panel banner with debt amount + "Pagar ahora" CTA → payment form
-- (debit card via Stripe / OXXO voucher). Saldo deduction stays automatic from
-- next payout.
--
-- Supersedes 20260426000001_cita_express_no_cash (the hard block) — cash on
-- ExpressCita comes back, gated by trust tier.
-- =============================================================================

-- ── 1. Schema: businesses columns + state log + app_config thresholds ───────
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS cash_eligible_at     timestamptz,
  ADD COLUMN IF NOT EXISTS cash_blocked_at      timestamptz,
  ADD COLUMN IF NOT EXISTS cash_block_reason    text,
  ADD COLUMN IF NOT EXISTS cash_tx_count_cached integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN businesses.cash_eligible_at IS
  'When the salon first crossed the trust threshold (>=N BC-processed completed bookings). Once set, never cleared. NULL = never reached trust.';
COMMENT ON COLUMN businesses.cash_blocked_at IS
  'When cash was suspended due to tax debt threshold. NULL = not currently blocked.';
COMMENT ON COLUMN businesses.cash_block_reason IS
  'Free-text reason set when cash_blocked_at is set (e.g. tax_debt_threshold).';

CREATE INDEX IF NOT EXISTS idx_businesses_cash_eligible
  ON businesses (id) WHERE cash_eligible_at IS NOT NULL AND cash_blocked_at IS NULL;

CREATE TABLE IF NOT EXISTS businesses_cash_state_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  transition      text NOT NULL,        -- 'activated' | 'suspended' | 'reactivated'
  reason          text,
  tax_debt_at     numeric(10,2),
  tx_count_at     integer,
  state_fingerprint text NOT NULL,      -- dedup key for emails
  email_sent_at   timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cash_state_transition_check
    CHECK (transition IN ('activated', 'suspended', 'reactivated'))
);

CREATE INDEX IF NOT EXISTS idx_cash_state_log_biz
  ON businesses_cash_state_log (business_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_cash_state_log_fingerprint
  ON businesses_cash_state_log (state_fingerprint);

ALTER TABLE businesses_cash_state_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS cash_state_log_admin ON businesses_cash_state_log;
CREATE POLICY cash_state_log_admin ON businesses_cash_state_log
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid()
              AND profiles.role IN ('admin','superadmin'))
    OR auth.role() = 'service_role'
  );
DROP POLICY IF EXISTS cash_state_log_owner ON businesses_cash_state_log;
CREATE POLICY cash_state_log_owner ON businesses_cash_state_log
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM businesses
              WHERE businesses.id = businesses_cash_state_log.business_id
              AND businesses.owner_id = auth.uid())
  );
DROP POLICY IF EXISTS cash_state_log_service ON businesses_cash_state_log;
CREATE POLICY cash_state_log_service ON businesses_cash_state_log
  FOR ALL USING (auth.role() = 'service_role')
            WITH CHECK (auth.role() = 'service_role');

INSERT INTO app_config (key, value) VALUES
  ('cash_trust_min_tx', '50'),
  ('cash_block_tax_debt_threshold', '1000')
ON CONFLICT (key) DO NOTHING;

-- ── 2. Helper: tx counter (paid + past + not cancelled, on-network) ────────
-- We don't have an auto-completion cron, so 'completed' status never fires.
-- Proxy: confirmed + paid + appointment time in the past + not cancelled.
-- This is what "BC-processed transaction that actually happened" means in
-- terms the database can answer right now.
CREATE OR REPLACE FUNCTION public.count_cash_eligible_tx(p_business_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
  SELECT COUNT(*)::int FROM appointments
   WHERE business_id = p_business_id
     AND status NOT IN ('cancelled_customer', 'cancelled_business')
     AND payment_status IN ('paid', 'deposit_paid')
     AND ends_at < now()
     AND booking_source IN ('bc_marketplace', 'invite_link', 'cita_express');
$$;

COMMENT ON FUNCTION public.count_cash_eligible_tx(uuid) IS
  'BC-processed transactions for trust eligibility. Proxy: paid + past + not cancelled (no auto-completion cron exists yet). When auto-completion lands, swap to status=completed.';

-- ── 3. compute_cash_eligibility: single source of truth ─────────────────────
-- One-way activation, debt-threshold suspension, debt=0 reactivation.
-- Returns the resulting state and whether a transition fired.
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.compute_cash_eligibility(p_business_id uuid)
RETURNS TABLE(
  out_is_eligible      boolean,
  out_is_blocked       boolean,
  out_tx_count         integer,
  out_tax_debt         numeric,
  out_transition       text,
  out_state_fingerprint text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_biz             record;
  v_min_tx          integer;
  v_debt_threshold  numeric;
  v_tx_count        integer;
  v_tax_debt        numeric;
  v_was_eligible    boolean;
  v_was_blocked     boolean;
  v_now_eligible    boolean;
  v_now_blocked     boolean;
  v_transition      text := NULL;
  v_fingerprint     text := NULL;
BEGIN
  SELECT id, is_test, cash_eligible_at, cash_blocked_at
    INTO v_biz
    FROM businesses
   WHERE id = p_business_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'business not found: %', p_business_id;
  END IF;

  v_min_tx := COALESCE((SELECT value::int FROM app_config WHERE key = 'cash_trust_min_tx'), 50);
  v_debt_threshold := COALESCE((SELECT value::numeric FROM app_config WHERE key = 'cash_block_tax_debt_threshold'), 1000);

  v_was_eligible := v_biz.cash_eligible_at IS NOT NULL;
  v_was_blocked  := v_biz.cash_blocked_at  IS NOT NULL;

  -- Test fixtures never eligible
  IF v_biz.is_test THEN
    out_is_eligible := false;
    out_is_blocked  := true;
    out_tx_count    := 0;
    out_tax_debt    := 0;
    out_transition  := NULL;
    out_state_fingerprint := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Tx counter (cache + read)
  v_tx_count := count_cash_eligible_tx(p_business_id);

  -- Open tax debt
  SELECT COALESCE(SUM(remaining_amount), 0) INTO v_tax_debt
    FROM salon_debts
   WHERE business_id = p_business_id
     AND remaining_amount > 0
     AND debt_type = 'tax_obligation';

  -- Activation: one-way (cash_eligible_at, once set, never cleared)
  IF NOT v_was_eligible AND v_tx_count >= v_min_tx THEN
    UPDATE businesses
       SET cash_eligible_at = now(),
           cash_tx_count_cached = v_tx_count
     WHERE id = p_business_id;
    v_was_eligible := true;
    v_transition := 'activated';
    v_fingerprint := 'activated:' || p_business_id::text;
  ELSE
    UPDATE businesses
       SET cash_tx_count_cached = v_tx_count
     WHERE id = p_business_id
       AND cash_tx_count_cached IS DISTINCT FROM v_tx_count;
  END IF;

  -- Suspension: only after activation
  IF v_was_eligible AND NOT v_was_blocked AND v_tax_debt >= v_debt_threshold THEN
    UPDATE businesses
       SET cash_blocked_at = now(),
           cash_block_reason = 'tax_debt_threshold'
     WHERE id = p_business_id;
    v_was_blocked := true;
    v_transition := 'suspended';
    v_fingerprint := 'suspended:' || p_business_id::text || ':' ||
                     to_char(date_trunc('hour', now()), 'YYYYMMDDHH24');
  -- Reactivation: was blocked, debt now 0
  ELSIF v_was_blocked AND v_tax_debt = 0 THEN
    UPDATE businesses
       SET cash_blocked_at = NULL,
           cash_block_reason = NULL
     WHERE id = p_business_id;
    v_was_blocked := false;
    v_transition := 'reactivated';
    v_fingerprint := 'reactivated:' || p_business_id::text || ':' ||
                     to_char(date_trunc('hour', now()), 'YYYYMMDDHH24');
  END IF;

  v_now_eligible := v_was_eligible;
  v_now_blocked  := v_was_blocked;

  -- Log transition if any (dedup'd by fingerprint unique index)
  IF v_transition IS NOT NULL THEN
    INSERT INTO businesses_cash_state_log (
      business_id, transition, reason, tax_debt_at, tx_count_at, state_fingerprint
    ) VALUES (
      p_business_id, v_transition,
      CASE WHEN v_transition = 'suspended' THEN 'tax_debt_threshold' ELSE NULL END,
      v_tax_debt, v_tx_count, v_fingerprint
    )
    ON CONFLICT (state_fingerprint) DO NOTHING;
  END IF;

  out_is_eligible       := v_now_eligible AND NOT v_now_blocked;
  out_is_blocked        := v_now_blocked;
  out_tx_count          := v_tx_count;
  out_tax_debt          := v_tax_debt;
  out_transition        := v_transition;
  out_state_fingerprint := v_fingerprint;
  RETURN NEXT;
  RETURN;
END;
$$;

COMMENT ON FUNCTION public.compute_cash_eligibility(uuid) IS
  'Single source of truth for cash eligibility. FOR UPDATE locks the business row to prevent split-brain. Idempotent transition logging via state_fingerprint unique index.';

-- ── 4. Read-only helper for clients/edge fns (no state mutation) ────────────
CREATE OR REPLACE FUNCTION public.is_cash_eligible(p_business_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT (cash_eligible_at IS NOT NULL AND cash_blocked_at IS NULL AND COALESCE(is_test, false) = false)
    FROM businesses WHERE id = p_business_id;
$$;

COMMENT ON FUNCTION public.is_cash_eligible(uuid) IS
  'Cheap read of denormalized eligibility flags. For booking-flow gating only — does not refresh state. Cron sweeper keeps the denorm in sync.';

-- ── 5. Booking RPC: replace 20260426000001 hard-block with trust-tier check ─
-- Cash on any on-network source (incl. cita_express) is now allowed IFF the
-- salon is_cash_eligible(). For non-eligible salons cash_direct is rejected.
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.create_booking_with_financials(
  p_user_id uuid, p_business_id uuid, p_service_id text, p_service_name text, p_service_type text,
  p_starts_at timestamp with time zone, p_ends_at timestamp with time zone, p_price numeric,
  p_payment_method text, p_booking_source text,
  p_transport_mode text DEFAULT NULL::text, p_staff_id uuid DEFAULT NULL::uuid,
  p_notes text DEFAULT NULL::text, p_idempotency_key text DEFAULT NULL::text,
  p_deposit_amount numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_booking_id       uuid;
  v_saldo            numeric;
  v_iva_inclusive     numeric;
  v_isr_rate         numeric;
  v_iva_rate         numeric;
  v_commission_rate  numeric;
  v_tax_base         numeric;
  v_iva_portion      numeric;
  v_isr_withheld     numeric;
  v_iva_withheld     numeric;
  v_provider_net     numeric;
  v_commission       numeric;
  v_platform_fee     numeric;
  v_status           text;
  v_payment_status   text;
  v_paid_at          timestamptz;
  v_biz_rfc          text;
  v_biz_tax_regime   text;
  v_biz_tax_residency text;
  v_biz_is_test      boolean;
  v_existing         jsonb;
  v_charge_amount    numeric;
  v_is_on_network    boolean;
  v_is_cash_on_net   boolean;
  v_tax_total        numeric;
  v_cash_eligible    boolean;
BEGIN
  IF p_idempotency_key IS NOT NULL THEN
    SELECT jsonb_build_object(
      'booking_id', a.id::text, 'tax_base', a.tax_base, 'isr_withheld', a.isr_withheld,
      'iva_withheld', a.iva_withheld, 'provider_net', a.provider_net,
      'commission', a.platform_fee, 'deposit_amount', a.deposit_amount, 'already_existed', true
    ) INTO v_existing
    FROM public.appointments a
    WHERE a.user_id = p_user_id AND a.business_id = p_business_id
      AND a.service_id = NULLIF(p_service_id, '')::uuid
      AND a.starts_at = p_starts_at
      AND a.status NOT IN ('cancelled_customer', 'cancelled_business')
    LIMIT 1;
    IF v_existing IS NOT NULL THEN RETURN v_existing; END IF;
  END IF;

  IF p_deposit_amount < 0 THEN RAISE EXCEPTION 'deposit_amount no puede ser negativo'; END IF;
  IF p_deposit_amount > p_price THEN RAISE EXCEPTION 'deposit_amount (%) excede el precio (%)', p_deposit_amount, p_price; END IF;

  -- TRUST GATE: cash_direct only allowed for salons that have earned eligibility.
  -- Applies to ALL booking sources, not just cita_express.
  IF p_payment_method = 'cash_direct' THEN
    SELECT public.is_cash_eligible(p_business_id) INTO v_cash_eligible;
    IF NOT v_cash_eligible THEN
      RAISE EXCEPTION 'Pago en efectivo no disponible en este salon. Usa saldo, tarjeta u OXXO.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  v_iva_inclusive := get_config_rate('iva_inclusive_rate', 1.16);
  SELECT rfc, COALESCE(is_test, false) INTO v_biz_rfc, v_biz_is_test
    FROM public.businesses WHERE id = p_business_id;

  IF v_biz_rfc IS NOT NULL AND v_biz_rfc != '' THEN
    v_isr_rate := get_config_rate('isr_rate', 0.025);
    v_iva_rate := get_config_rate('iva_rate', 0.08);
  ELSE
    v_isr_rate := get_config_rate('isr_rate_no_rfc', 0.20);
    v_iva_rate := get_config_rate('iva_rate_no_rfc', 0.16);
  END IF;

  v_is_on_network := p_booking_source IN ('bc_marketplace', 'invite_link', 'cita_express');

  IF v_is_on_network THEN
    v_commission_rate := get_config_rate('commission_rate_marketplace', 0.03);
  ELSE
    v_commission_rate := get_config_rate('commission_rate_salon_direct', 0.00);
  END IF;

  v_tax_base    := ROUND(p_price / v_iva_inclusive, 2);
  v_iva_portion := ROUND(p_price - v_tax_base, 2);
  v_isr_withheld := ROUND(p_price * v_isr_rate, 2);
  v_iva_withheld := ROUND(v_iva_portion * v_iva_rate, 2);
  v_commission   := ROUND(p_price * v_commission_rate, 2);
  v_platform_fee := v_commission;
  v_provider_net := GREATEST(ROUND(p_price - v_isr_withheld - v_iva_withheld, 2), 0);

  SELECT tax_regime, tax_residency
    INTO v_biz_tax_regime, v_biz_tax_residency
    FROM public.businesses WHERE id = p_business_id;

  v_charge_amount := CASE WHEN p_deposit_amount > 0 THEN p_deposit_amount ELSE p_price END;

  IF p_payment_method = 'saldo' THEN
    SELECT saldo INTO v_saldo FROM public.profiles WHERE id = p_user_id FOR UPDATE;
    IF v_saldo IS NULL THEN RAISE EXCEPTION 'Usuario no encontrado'; END IF;
    IF v_saldo < v_charge_amount THEN RAISE EXCEPTION 'Saldo insuficiente (% < %)', v_saldo, v_charge_amount; END IF;
    UPDATE public.profiles SET saldo = saldo - v_charge_amount, updated_at = now() WHERE id = p_user_id;
    v_status := 'confirmed';
    v_payment_status := CASE WHEN p_deposit_amount > 0 THEN 'deposit_paid' ELSE 'paid' END;
    v_paid_at := now();

  ELSIF p_payment_method = 'cash_direct' THEN
    IF p_deposit_amount > 0 THEN
      RAISE EXCEPTION 'cash_direct no puede tener deposito; use saldo o card para el deposito';
    END IF;
    v_status := 'confirmed';
    v_payment_status := 'paid';
    v_paid_at := now();

  ELSIF p_payment_method IN ('card', 'oxxo') THEN
    v_status := 'pending';
    v_payment_status := 'pending';
    v_paid_at := NULL;

  ELSE
    RAISE EXCEPTION 'Metodo de pago no soportado: %', p_payment_method;
  END IF;

  v_is_cash_on_net := v_is_on_network AND p_payment_method = 'cash_direct';

  INSERT INTO public.appointments (
    user_id, business_id, service_id, service_name, service_type,
    starts_at, ends_at, price, status, payment_status, payment_method,
    transport_mode, staff_id, notes, paid_at, booking_source,
    tax_base, isr_withheld, iva_withheld, provider_net, platform_fee, deposit_amount
  ) VALUES (
    p_user_id, p_business_id, NULLIF(p_service_id, '')::uuid, p_service_name, p_service_type,
    p_starts_at, p_ends_at, p_price, v_status, v_payment_status, p_payment_method,
    p_transport_mode, p_staff_id, p_notes, v_paid_at, p_booking_source,
    v_tax_base, v_isr_withheld, v_iva_withheld, v_provider_net, v_platform_fee, p_deposit_amount
  )
  RETURNING id INTO v_booking_id;

  IF v_is_on_network AND NOT v_biz_is_test THEN
    INSERT INTO public.tax_withholdings (
      appointment_id, business_id, payment_type,
      gross_amount, tax_base, iva_portion, platform_fee,
      isr_rate, iva_rate, isr_withheld, iva_withheld, provider_net,
      provider_rfc, provider_tax_regime, provider_tax_residency,
      period_year, period_month
    ) VALUES (
      v_booking_id, p_business_id, p_payment_method,
      p_price, v_tax_base, v_iva_portion, v_platform_fee,
      v_isr_rate, v_iva_rate, v_isr_withheld, v_iva_withheld, v_provider_net,
      v_biz_rfc, v_biz_tax_regime, COALESCE(v_biz_tax_residency, 'MX'),
      EXTRACT(YEAR FROM now())::int, EXTRACT(MONTH FROM now())::int
    );

    IF v_commission > 0 THEN
      INSERT INTO public.commission_records (
        business_id, appointment_id, amount, rate, source,
        period_month, period_year, status
      ) VALUES (
        p_business_id, v_booking_id, v_commission, v_commission_rate, 'appointment',
        EXTRACT(MONTH FROM now())::int, EXTRACT(YEAR FROM now())::int, 'collected'
      );
    END IF;

    -- Cash-on-network: salon owes BC tax pass-through + commission BC couldn't withhold.
    -- This applies to cash_direct on bc_marketplace + invite_link + cita_express now
    -- that the trust tier allows cash on any on-network source.
    IF v_is_cash_on_net THEN
      v_tax_total := v_isr_withheld + v_iva_withheld;
      IF v_tax_total > 0 THEN
        INSERT INTO salon_debts (
          business_id, appointment_id, original_amount, remaining_amount,
          debt_type, reason, source, created_at
        ) VALUES (
          p_business_id, v_booking_id, v_tax_total, v_tax_total,
          'tax_obligation', 'cash_on_network_tax_pass_through',
          p_booking_source || '_cash', now()
        );
      END IF;
      IF v_commission > 0 THEN
        INSERT INTO salon_debts (
          business_id, appointment_id, original_amount, remaining_amount,
          debt_type, reason, source, created_at
        ) VALUES (
          p_business_id, v_booking_id, v_commission, v_commission,
          'operational_commission', 'cash_on_network_commission',
          p_booking_source || '_cash', now()
        );
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'booking_id', v_booking_id::text,
    'tax_base', v_tax_base, 'isr_withheld', v_isr_withheld,
    'iva_withheld', v_iva_withheld, 'provider_net', v_provider_net,
    'commission', v_commission, 'commission_rate', v_commission_rate,
    'deposit_amount', p_deposit_amount, 'charged_amount', v_charge_amount,
    'cash_due_at_salon', GREATEST(p_price - p_deposit_amount, 0),
    'saldo_deducted', (p_payment_method = 'saldo'),
    'is_test_business', v_biz_is_test,
    'cash_on_network_debt_created', v_is_cash_on_net,
    'already_existed', false
  );
END;
$function$;

-- ── 6. Sweeper: nightly recompute eligibility for active businesses ────────
CREATE OR REPLACE FUNCTION public.sweep_cash_eligibility()
RETURNS TABLE(processed integer, transitions integer)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_processed   integer := 0;
  v_transitions integer := 0;
  v_biz_id      uuid;
  v_result      record;
BEGIN
  FOR v_biz_id IN
    SELECT id FROM businesses
     WHERE COALESCE(is_test, false) = false
       AND is_active = true
  LOOP
    SELECT * INTO v_result FROM public.compute_cash_eligibility(v_biz_id);
    v_processed := v_processed + 1;
    IF v_result.out_transition IS NOT NULL THEN
      v_transitions := v_transitions + 1;
    END IF;
  END LOOP;
  processed := v_processed;
  transitions := v_transitions;
  RETURN NEXT;
  RETURN;
END;
$$;

COMMENT ON FUNCTION public.sweep_cash_eligibility() IS
  'Cron-driven: recomputes cash eligibility for every active non-test business. Catches activation milestones + debt-threshold suspensions + reactivations. Email send is driven off businesses_cash_state_log entries with email_sent_at IS NULL.';

-- ── 7. Trigger: instant reactivation on tax_obligation debt = 0 ────────────
-- When the calculate_payout_with_debt collector or the new "Pagar ahora" path
-- zeros out the last tax_obligation row, recompute eligibility immediately
-- so the salon's cash tile reappears without waiting for the hourly sweep.
CREATE OR REPLACE FUNCTION public._trg_cash_recompute_on_debt_clear()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.debt_type = 'tax_obligation'
     AND OLD.remaining_amount > 0
     AND NEW.remaining_amount = 0 THEN
    PERFORM public.compute_cash_eligibility(NEW.business_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cash_recompute_on_debt_clear ON salon_debts;
CREATE TRIGGER trg_cash_recompute_on_debt_clear
  AFTER UPDATE OF remaining_amount ON salon_debts
  FOR EACH ROW
  EXECUTE FUNCTION public._trg_cash_recompute_on_debt_clear();

-- ── 8. Cron schedule: hourly sweep + every-2-min email drainer ─────────────
-- Auth pattern matches HVT/wa-global-drain crons: private.cron_config + X-Cron-Secret.
CREATE SCHEMA IF NOT EXISTS private;
CREATE TABLE IF NOT EXISTS private.cron_config (
  id smallint PRIMARY KEY DEFAULT 1,
  cron_secret text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (id = 1)
);
CREATE OR REPLACE FUNCTION private.get_cron_secret()
RETURNS text LANGUAGE sql SECURITY DEFINER
SET search_path = private, pg_temp
AS $$
  SELECT cron_secret FROM private.cron_config WHERE id = 1;
$$;

DO $$
DECLARE v_jobid bigint;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'cash-eligibility-sweep';
  IF v_jobid IS NOT NULL THEN PERFORM cron.unschedule(v_jobid); END IF;

  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'cash-trust-notify-drain';
  IF v_jobid IS NOT NULL THEN PERFORM cron.unschedule(v_jobid); END IF;
END $$;

SELECT cron.schedule(
  'cash-eligibility-sweep',
  '0 * * * *',
  $cron$SELECT public.sweep_cash_eligibility();$cron$
);

SELECT cron.schedule(
  'cash-trust-notify-drain',
  '*/2 * * * *',
  $cron$
    SELECT net.http_post(
      url := 'http://kong:8000/functions/v1/cash-trust-notify',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret', private.get_cron_secret()
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    ) AS request_id;
  $cron$
);

-- ── 8. Notification templates: 3 cash-trust emails ──────────────────────────
INSERT INTO notification_templates (event_type, channel, recipient_type, template_es, template_en, required_variables, is_active)
VALUES
  ('cash_activated', 'email', 'salon',
   '{"subject":"BeautyCita: Pagos en efectivo activados","body":"Hola {{salon_name}},\n\nFelicidades. Tu salon ha procesado mas de {{min_tx}} citas a traves de BeautyCita y ahora califica para aceptar pagos en efectivo en citas hechas a traves de la app.\n\nLos clientes podran seleccionar pagar en efectivo al reservar. BeautyCita seguira reteniendo ISR e IVA segun la ley; al pagar en efectivo, el salon nos reembolsa la retencion mas la comision automaticamente del siguiente payout.\n\nSi acumulas adeudos fiscales por encima del umbral, los pagos en efectivo se desactivaran hasta liquidar.\n\nGracias por tu confianza.\n\n— BeautyCita"}',
   '{"subject":"BeautyCita: Cash payments enabled","body":"Hi {{salon_name}},\n\nCongratulations. Your salon has processed more than {{min_tx}} appointments through BeautyCita and now qualifies to accept cash payments on app bookings.\n\nClients will see cash as a payment option when booking. BeautyCita continues to withhold ISR and IVA per Mexican law; on cash payments, the salon reimburses the withholding plus commission automatically from the next payout.\n\nIf tax debt exceeds threshold, cash payments will be disabled until cleared.\n\nThanks for your trust.\n\n— BeautyCita"}',
   ARRAY['salon_name','min_tx'],
   true),
  ('cash_suspended', 'email', 'salon',
   '{"subject":"BeautyCita: Pagos en efectivo suspendidos","body":"Hola {{salon_name}},\n\nLos pagos en efectivo en tu salon han sido suspendidos temporalmente porque tu adeudo fiscal pendiente con BeautyCita es de ${{tax_debt}} MXN, por encima del umbral de ${{threshold}} MXN.\n\nQue significa: los clientes ya no pueden seleccionar efectivo al reservar en tu salon. Las demas formas de pago siguen disponibles (tarjeta, OXXO, saldo).\n\nComo reactivar: liquida el total del adeudo fiscal. Una vez en cero, los pagos en efectivo se reactivan automaticamente.\n\nPaga ahora: {{payment_url}}\n\n— BeautyCita"}',
   '{"subject":"BeautyCita: Cash payments suspended","body":"Hi {{salon_name}},\n\nCash payments at your salon have been temporarily suspended because your outstanding tax debt with BeautyCita is ${{tax_debt}} MXN, above the threshold of ${{threshold}} MXN.\n\nWhat it means: clients can no longer select cash when booking your salon. Other payment methods remain available (card, OXXO, saldo).\n\nHow to reactivate: pay the full tax debt. Once at zero, cash payments are reactivated automatically.\n\nPay now: {{payment_url}}\n\n— BeautyCita"}',
   ARRAY['salon_name','tax_debt','threshold','payment_url'],
   true),
  ('cash_reactivated', 'email', 'salon',
   '{"subject":"BeautyCita: Pagos en efectivo reactivados","body":"Hola {{salon_name}},\n\nGracias por liquidar tu adeudo fiscal. Los pagos en efectivo en tu salon estan nuevamente activos. Los clientes ya pueden seleccionar efectivo al reservar.\n\n— BeautyCita"}',
   '{"subject":"BeautyCita: Cash payments reactivated","body":"Hi {{salon_name}},\n\nThanks for clearing your tax debt. Cash payments at your salon are active again. Clients can now select cash when booking.\n\n— BeautyCita"}',
   ARRAY['salon_name'],
   true)
ON CONFLICT (event_type, channel, recipient_type) DO UPDATE
  SET template_es = EXCLUDED.template_es,
      template_en = EXCLUDED.template_en,
      required_variables = EXCLUDED.required_variables,
      is_active = EXCLUDED.is_active,
      updated_at = now();

-- ── 9. Drop the hard-block from 20260426000001 ─────────────────────────────
-- (function body was overridden by step 5 above; this is documentation.)
COMMENT ON FUNCTION public.create_booking_with_financials(uuid, uuid, text, text, text, timestamptz, timestamptz, numeric, text, text, text, uuid, text, text, numeric) IS
  'Trust-tier cash gate: cash_direct allowed iff is_cash_eligible(business_id). Cash on any on-network source creates tax_obligation + operational_commission salon_debts. is_test businesses skip ledger writes.';
