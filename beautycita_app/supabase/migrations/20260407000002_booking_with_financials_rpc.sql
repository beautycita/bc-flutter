-- =============================================================================
-- create_booking_with_financials: Single atomic RPC for all booking paths.
-- Replaces client-side tax/commission math in booking_flow_provider,
-- cita_express_provider, and the Stripe webhook financial logic.
--
-- Handles: saldo deduction, appointment creation, tax withholdings,
-- commission records, and payout calculation — all in one transaction.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_booking_with_financials(
  -- Booking fields
  p_user_id          uuid,
  p_business_id      uuid,
  p_service_id       text,
  p_service_name     text,
  p_service_type     text,
  p_starts_at        timestamptz,
  p_ends_at          timestamptz,
  p_price            numeric,
  p_payment_method   text,          -- 'saldo', 'cash_direct', 'card', 'oxxo'
  p_booking_source   text,          -- 'bc_marketplace', 'salon_direct', 'cita_express', 'walk_in', 'invite_link'
  -- Optional
  p_transport_mode   text    DEFAULT NULL,
  p_staff_id         uuid    DEFAULT NULL,
  p_notes            text    DEFAULT NULL,
  p_idempotency_key  text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
  v_existing         jsonb;
BEGIN
  -- =========================================================================
  -- 0. Idempotency check: if this exact booking was already created, return it
  -- =========================================================================
  IF p_idempotency_key IS NOT NULL THEN
    SELECT jsonb_build_object(
      'booking_id', a.id::text,
      'tax_base', a.tax_base,
      'isr_withheld', a.isr_withheld,
      'iva_withheld', a.iva_withheld,
      'provider_net', a.provider_net,
      'commission', a.platform_fee,
      'already_existed', true
    ) INTO v_existing
    FROM public.appointments a
    WHERE a.user_id = p_user_id
      AND a.business_id = p_business_id
      AND a.service_id = p_service_id
      AND a.starts_at = p_starts_at
      AND a.status NOT IN ('cancelled_customer', 'cancelled_business')
    LIMIT 1;

    IF v_existing IS NOT NULL THEN
      RETURN v_existing;
    END IF;
  END IF;

  -- =========================================================================
  -- 1. Read rates from app_config (single source of truth)
  -- =========================================================================
  v_iva_inclusive := get_config_rate('iva_inclusive_rate', 1.16);

  -- Tax rates depend on whether salon has RFC registered
  SELECT rfc INTO v_biz_rfc FROM public.businesses WHERE id = p_business_id;

  IF v_biz_rfc IS NOT NULL AND v_biz_rfc != '' THEN
    -- Salon has RFC: reduced rates (LISR 113-A)
    v_isr_rate := get_config_rate('isr_rate', 0.025);
    v_iva_rate := get_config_rate('iva_rate', 0.08);
  ELSE
    -- Salon has NO RFC: maximum rates
    v_isr_rate := get_config_rate('isr_rate_no_rfc', 0.20);
    v_iva_rate := get_config_rate('iva_rate_no_rfc', 0.16);
  END IF;

  -- Commission rate depends on booking source
  IF p_booking_source IN ('bc_marketplace', 'invite_link') THEN
    v_commission_rate := get_config_rate('commission_rate_marketplace', 0.03);
  ELSE
    -- salon_direct, walk_in, cita_express = salon's own client
    v_commission_rate := get_config_rate('commission_rate_salon_direct', 0.00);
  END IF;

  -- =========================================================================
  -- 2. Calculate tax withholdings (per LISR Art. 113-A, LIVA Art. 18-J)
  -- =========================================================================
  -- ISR: withheld on gross amount
  -- IVA: withheld on the IVA portion (gross - taxBase)
  v_tax_base    := ROUND(p_price / v_iva_inclusive, 2);
  v_iva_portion := ROUND(p_price - v_tax_base, 2);
  v_isr_withheld := ROUND(p_price * v_isr_rate, 2);
  v_iva_withheld := ROUND(v_iva_portion * v_iva_rate, 2);
  v_commission   := ROUND(p_price * v_commission_rate, 2);
  v_platform_fee := v_commission;
  v_provider_net := GREATEST(ROUND(p_price - v_isr_withheld - v_iva_withheld, 2), 0);

  -- =========================================================================
  -- 3. Read remaining business tax info for withholding snapshot
  -- (RFC already read above for rate selection)
  -- =========================================================================
  SELECT tax_regime, tax_residency
  INTO v_biz_tax_regime, v_biz_tax_residency
  FROM public.businesses
  WHERE id = p_business_id;

  -- =========================================================================
  -- 4. Payment-method-specific logic
  -- =========================================================================
  IF p_payment_method = 'saldo' THEN
    -- Lock user's profile row and check balance
    SELECT saldo INTO v_saldo
    FROM public.profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF v_saldo IS NULL THEN
      RAISE EXCEPTION 'Usuario no encontrado';
    END IF;

    IF v_saldo < p_price THEN
      RAISE EXCEPTION 'Saldo insuficiente (% < %)', v_saldo, p_price;
    END IF;

    -- Deduct saldo atomically
    UPDATE public.profiles
    SET saldo = saldo - p_price, updated_at = now()
    WHERE id = p_user_id;

    v_status := 'confirmed';
    v_payment_status := 'paid';
    v_paid_at := now();

  ELSIF p_payment_method = 'cash_direct' THEN
    -- Cash at salon: immediately confirmed
    v_status := 'confirmed';
    v_payment_status := 'paid';
    v_paid_at := now();

  ELSIF p_payment_method IN ('card', 'oxxo') THEN
    -- Stripe: pending until webhook confirms
    v_status := 'pending';
    v_payment_status := 'pending';
    v_paid_at := NULL;

  ELSE
    RAISE EXCEPTION 'Metodo de pago no soportado: %', p_payment_method;
  END IF;

  -- =========================================================================
  -- 5. Create appointment with all financial fields populated
  -- =========================================================================
  INSERT INTO public.appointments (
    user_id, business_id, service_id, service_name, service_type,
    starts_at, ends_at, price, status, payment_status, payment_method,
    transport_mode, staff_id, notes, paid_at, booking_source,
    tax_base, isr_withheld, iva_withheld, provider_net, platform_fee
  ) VALUES (
    p_user_id, p_business_id, NULLIF(p_service_id, '')::uuid, p_service_name, p_service_type,
    p_starts_at, p_ends_at, p_price, v_status, v_payment_status, p_payment_method,
    p_transport_mode, p_staff_id, p_notes, v_paid_at, p_booking_source,
    v_tax_base, v_isr_withheld, v_iva_withheld, v_provider_net, v_platform_fee
  )
  RETURNING id INTO v_booking_id;

  -- =========================================================================
  -- 6. Tax withholdings ledger (immutable snapshot)
  -- =========================================================================
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

  -- =========================================================================
  -- 7. Commission record (only if commission > 0)
  -- =========================================================================
  IF v_commission > 0 THEN
    INSERT INTO public.commission_records (
      business_id, appointment_id, amount, rate, source,
      period_month, period_year, status
    ) VALUES (
      p_business_id, v_booking_id, v_commission, v_commission_rate, 'appointment',
      EXTRACT(MONTH FROM now())::int, EXTRACT(YEAR FROM now())::int, 'collected'
    );
  END IF;

  -- =========================================================================
  -- 8. Return result
  -- =========================================================================
  RETURN jsonb_build_object(
    'booking_id', v_booking_id::text,
    'tax_base', v_tax_base,
    'isr_withheld', v_isr_withheld,
    'iva_withheld', v_iva_withheld,
    'provider_net', v_provider_net,
    'commission', v_commission,
    'commission_rate', v_commission_rate,
    'saldo_deducted', (p_payment_method = 'saldo'),
    'already_existed', false
  );
END;
$$;

COMMENT ON FUNCTION public.create_booking_with_financials IS
  'Atomic booking creation with tax withholdings, commission, and saldo deduction. '
  'Replaces all client-side financial math. All rates read from app_config.';
