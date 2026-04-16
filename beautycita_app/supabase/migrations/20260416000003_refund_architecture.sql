-- Saldo-only refund architecture: all refunds → buyer saldo + seller debt
-- Tax withholding reversal support for SAT compliance (LISR Art. 113-A)

-- 1. Tax withholdings: add reversal support
ALTER TABLE public.tax_withholdings
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'recorded'
    CHECK (status IN ('recorded', 'reversed', 'remitted'));

ALTER TABLE public.tax_withholdings
  ADD COLUMN IF NOT EXISTS reversal_related_id uuid REFERENCES public.tax_withholdings(id);

ALTER TABLE public.tax_withholdings
  ADD COLUMN IF NOT EXISTS reversal_reason text;

-- 2. Tax withholdings: add order_id for product order tax tracking
ALTER TABLE public.tax_withholdings
  ADD COLUMN IF NOT EXISTS order_id uuid REFERENCES public.orders(id);

-- 3. Salon debts: add appointment/order traceability
ALTER TABLE public.salon_debts
  ADD COLUMN IF NOT EXISTS appointment_id uuid REFERENCES public.appointments(id);

ALTER TABLE public.salon_debts
  ADD COLUMN IF NOT EXISTS order_id uuid REFERENCES public.orders(id);

-- 4. SQL helper: reverse tax withholding for a given appointment
CREATE OR REPLACE FUNCTION public.reverse_tax_withholding(
  p_appointment_id uuid,
  p_reason text DEFAULT 'refund'
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_original RECORD;
BEGIN
  -- Find the original withholding record
  SELECT * INTO v_original
  FROM public.tax_withholdings
  WHERE appointment_id = p_appointment_id
    AND status = 'recorded'
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN; -- No withholding to reverse (unpaid or no-tax booking)
  END IF;

  -- Insert negative reversal record
  INSERT INTO public.tax_withholdings (
    appointment_id, business_id, payment_intent_id, payment_type,
    gross_amount, tax_base, iva_portion, platform_fee,
    isr_rate, iva_rate, isr_withheld, iva_withheld,
    provider_net, provider_rfc, provider_tax_regime, provider_tax_residency,
    currency, period_year, period_month, jurisdiction,
    status, reversal_related_id, reversal_reason
  ) VALUES (
    v_original.appointment_id, v_original.business_id,
    v_original.payment_intent_id, v_original.payment_type,
    -v_original.gross_amount, -v_original.tax_base,
    -v_original.iva_portion, -v_original.platform_fee,
    v_original.isr_rate, v_original.iva_rate,
    -v_original.isr_withheld, -v_original.iva_withheld,
    -v_original.provider_net, v_original.provider_rfc,
    v_original.provider_tax_regime, v_original.provider_tax_residency,
    v_original.currency,
    EXTRACT(YEAR FROM now())::int, EXTRACT(MONTH FROM now())::int,
    v_original.jurisdiction,
    'reversed', v_original.id, p_reason
  );

  -- Mark original as reversed
  UPDATE public.tax_withholdings
  SET status = 'reversed'
  WHERE id = v_original.id;
END;
$$;
