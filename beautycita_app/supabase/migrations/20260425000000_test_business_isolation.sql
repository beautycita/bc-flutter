-- =============================================================================
-- Test-business isolation from SAT-visible flows
-- =============================================================================
-- Until now, "test salons" were detected only by name-pattern at read time
-- (data_quality_test.dart). The financial pipeline made no distinction:
-- create_booking_with_financials inserted into tax_withholdings + commission_records
-- for fixture businesses just like real ones, and sat-access / sat-reporting
-- read those rows back without filtering. 7752 fictional tax_withholdings
-- rows currently exist on Afakename + Salón Test PV alone — none are SAT-
-- visible TODAY (no completed+paid+marketplace appointments) but a single
-- test-flow misuse would push them into the /transactions feed and
-- contaminate the next monthly summary.
--
-- This migration adds an explicit `is_test` flag on businesses and uses it as
-- the canonical "exclude from real-world side effects" signal. The financial
-- RPC silently skips ledger writes for is_test businesses (graceful path that
-- mirrors the off-network handling). A trigger on tax_withholdings AND
-- commission_records rejects direct PostgREST INSERTs for is_test businesses
-- (defense in depth — flow tests bypass the RPC). SAT endpoints read the
-- flag via JOIN and exclude. Fixture rows already in the ledger stay where
-- they are (ledger integrity); the JOIN-side filter hides them.
-- =============================================================================

-- 1. Column + backfill for the 3 known fixtures.
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS is_test boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_businesses_is_test
  ON public.businesses (is_test) WHERE is_test = true;

UPDATE public.businesses
SET is_test = true
WHERE name LIKE '[HUNTER-TEST]%'
   OR name LIKE '[bughunter-flow%'
   OR name = 'Afakename'
   OR name LIKE 'Salón Test%';

-- 2. Trigger function: reject ledger writes for is_test businesses. RPC path
--    skips silently before reaching this; this catches direct PostgREST INSERTs.
CREATE OR REPLACE FUNCTION public.reject_test_business_ledger_writes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_test boolean;
BEGIN
  SELECT is_test INTO v_is_test FROM public.businesses WHERE id = NEW.business_id;
  IF COALESCE(v_is_test, false) = true THEN
    RAISE EXCEPTION '% rejected: business % is marked is_test=true (no SAT-visible side effects allowed)',
      TG_TABLE_NAME, NEW.business_id
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tax_withholdings_reject_test_business ON public.tax_withholdings;
CREATE TRIGGER tax_withholdings_reject_test_business
  BEFORE INSERT ON public.tax_withholdings
  FOR EACH ROW EXECUTE FUNCTION public.reject_test_business_ledger_writes();

DROP TRIGGER IF EXISTS commission_records_reject_test_business ON public.commission_records;
CREATE TRIGGER commission_records_reject_test_business
  BEFORE INSERT ON public.commission_records
  FOR EACH ROW EXECUTE FUNCTION public.reject_test_business_ledger_writes();

-- 3. Patch create_booking_with_financials to skip ledger writes for is_test
--    (graceful skip mirrors off-network handling). Appointment row still gets
--    written so flow tests can exercise booking code paths; only the
--    SAT-visible / commission tables are bypassed.
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
BEGIN
  -- 0. Idempotency check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT jsonb_build_object(
      'booking_id', a.id::text,
      'tax_base', a.tax_base,
      'isr_withheld', a.isr_withheld,
      'iva_withheld', a.iva_withheld,
      'provider_net', a.provider_net,
      'commission', a.platform_fee,
      'deposit_amount', a.deposit_amount,
      'already_existed', true
    ) INTO v_existing
    FROM public.appointments a
    WHERE a.user_id = p_user_id
      AND a.business_id = p_business_id
      AND a.service_id = NULLIF(p_service_id, '')::uuid
      AND a.starts_at = p_starts_at
      AND a.status NOT IN ('cancelled_customer', 'cancelled_business')
    LIMIT 1;

    IF v_existing IS NOT NULL THEN
      RETURN v_existing;
    END IF;
  END IF;

  IF p_deposit_amount < 0 THEN
    RAISE EXCEPTION 'deposit_amount no puede ser negativo';
  END IF;
  IF p_deposit_amount > p_price THEN
    RAISE EXCEPTION 'deposit_amount (%) excede el precio (%)', p_deposit_amount, p_price;
  END IF;

  v_iva_inclusive := get_config_rate('iva_inclusive_rate', 1.16);
  SELECT rfc, COALESCE(is_test, false)
    INTO v_biz_rfc, v_biz_is_test
  FROM public.businesses WHERE id = p_business_id;

  IF v_biz_rfc IS NOT NULL AND v_biz_rfc != '' THEN
    v_isr_rate := get_config_rate('isr_rate', 0.025);
    v_iva_rate := get_config_rate('iva_rate', 0.08);
  ELSE
    v_isr_rate := get_config_rate('isr_rate_no_rfc', 0.20);
    v_iva_rate := get_config_rate('iva_rate_no_rfc', 0.16);
  END IF;

  IF p_booking_source IN ('bc_marketplace', 'invite_link') THEN
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
    IF v_saldo IS NULL THEN
      RAISE EXCEPTION 'Usuario no encontrado';
    END IF;
    IF v_saldo < v_charge_amount THEN
      RAISE EXCEPTION 'Saldo insuficiente (% < %)', v_saldo, v_charge_amount;
    END IF;
    UPDATE public.profiles
      SET saldo = saldo - v_charge_amount, updated_at = now()
      WHERE id = p_user_id;
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

  INSERT INTO public.appointments (
    user_id, business_id, service_id, service_name, service_type,
    starts_at, ends_at, price, status, payment_status, payment_method,
    transport_mode, staff_id, notes, paid_at, booking_source,
    tax_base, isr_withheld, iva_withheld, provider_net, platform_fee,
    deposit_amount
  ) VALUES (
    p_user_id, p_business_id, NULLIF(p_service_id, '')::uuid, p_service_name, p_service_type,
    p_starts_at, p_ends_at, p_price, v_status, v_payment_status, p_payment_method,
    p_transport_mode, p_staff_id, p_notes, v_paid_at, p_booking_source,
    v_tax_base, v_isr_withheld, v_iva_withheld, v_provider_net, v_platform_fee,
    p_deposit_amount
  )
  RETURNING id INTO v_booking_id;

  -- Tax withholdings ledger — on-network only, AND not for is_test fixtures.
  -- is_test bypasses real-world SAT side effects; the trigger would block
  -- this write anyway, but the explicit IF avoids relying on an exception.
  IF p_booking_source IN ('bc_marketplace', 'invite_link') AND NOT v_biz_is_test THEN
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
  END IF;

  -- Commission record — same gating: real positive commission AND not is_test.
  IF v_commission > 0 AND NOT v_biz_is_test THEN
    INSERT INTO public.commission_records (
      business_id, appointment_id, amount, rate, source,
      period_month, period_year, status
    ) VALUES (
      p_business_id, v_booking_id, v_commission, v_commission_rate, 'appointment',
      EXTRACT(MONTH FROM now())::int, EXTRACT(YEAR FROM now())::int, 'collected'
    );
  END IF;

  RETURN jsonb_build_object(
    'booking_id', v_booking_id::text,
    'tax_base', v_tax_base,
    'isr_withheld', v_isr_withheld,
    'iva_withheld', v_iva_withheld,
    'provider_net', v_provider_net,
    'commission', v_commission,
    'commission_rate', v_commission_rate,
    'deposit_amount', p_deposit_amount,
    'charged_amount', v_charge_amount,
    'cash_due_at_salon', GREATEST(p_price - p_deposit_amount, 0),
    'saldo_deducted', (p_payment_method = 'saldo'),
    'is_test_business', v_biz_is_test,
    'already_existed', false
  );
END;
$function$;

-- 4. Auto-mark trigger: any business inserted with a known fixture name
--    prefix (HUNTER-TEST, bughunter-flow) is flagged is_test=true. Removes
--    the dependency on flow code paths remembering to set the column.
CREATE OR REPLACE FUNCTION public.auto_mark_test_business()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.name ~* '^\[HUNTER-TEST\]' OR NEW.name ~* '^\[bughunter-flow' THEN
    NEW.is_test := true;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS businesses_auto_mark_test ON public.businesses;
CREATE TRIGGER businesses_auto_mark_test
  BEFORE INSERT OR UPDATE OF name ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.auto_mark_test_business();
