-- =============================================================================
-- Sync calculate_payout_with_debt to match production state.
--
-- Production has BOTH a 2-arg and 5-arg overload. Only the 5-arg version
-- is called (by stripe-webhook). The 2-arg version is dead code.
--
-- This migration:
--   1. Creates the 5-arg overload (idempotent, already on prod)
--   2. Drops the 2-arg orphan
-- =============================================================================

-- 1. Create 5-arg version (matches prod, idempotent via CREATE OR REPLACE)
CREATE OR REPLACE FUNCTION public.calculate_payout_with_debt(
  p_business_id    uuid,
  p_gross_amount   numeric,
  p_commission     numeric,
  p_iva_withheld   numeric,
  p_isr_withheld   numeric
)
RETURNS TABLE(salon_payout numeric, debt_collected numeric, remaining_debt numeric)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_net numeric;
  v_total_debt numeric;
  v_max_deduction numeric;
  v_actual_deduction numeric;
  v_debt_record RECORD;
  v_remaining_to_collect numeric;
BEGIN
  -- Net payout before debt: gross - commission - IVA - ISR
  v_net := p_gross_amount - p_commission - p_iva_withheld - p_isr_withheld;

  -- Guard: never go negative
  IF v_net < 0 THEN v_net := 0; END IF;

  -- Get total outstanding debt
  SELECT COALESCE(SUM(remaining_amount), 0) INTO v_total_debt
  FROM salon_debts
  WHERE business_id = p_business_id AND remaining_amount > 0;

  IF v_total_debt <= 0 THEN
    salon_payout := v_net;
    debt_collected := 0;
    remaining_debt := 0;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Max deduction: 50% of gross, capped by net and total debt
  v_max_deduction := LEAST(p_gross_amount * 0.50, v_net);
  v_actual_deduction := LEAST(v_max_deduction, v_total_debt);

  -- Apply FIFO to oldest debts
  v_remaining_to_collect := v_actual_deduction;
  FOR v_debt_record IN
    SELECT id, remaining_amount FROM salon_debts
    WHERE business_id = p_business_id AND remaining_amount > 0
    ORDER BY created_at ASC
  LOOP
    IF v_remaining_to_collect <= 0 THEN EXIT; END IF;
    DECLARE
      v_apply numeric := LEAST(v_remaining_to_collect, v_debt_record.remaining_amount);
    BEGIN
      UPDATE salon_debts SET
        remaining_amount = remaining_amount - v_apply,
        cleared_at = CASE WHEN remaining_amount - v_apply = 0 THEN NOW() ELSE NULL END
      WHERE id = v_debt_record.id;
      v_remaining_to_collect := v_remaining_to_collect - v_apply;
    END;
  END LOOP;

  -- Update cached debt on business
  UPDATE businesses SET outstanding_debt = (
    SELECT COALESCE(SUM(remaining_amount), 0) FROM salon_debts
    WHERE business_id = p_business_id AND remaining_amount > 0
  ) WHERE id = p_business_id;

  salon_payout := v_net - v_actual_deduction;
  debt_collected := v_actual_deduction;
  remaining_debt := v_total_debt - v_actual_deduction;
  RETURN NEXT;
  RETURN;
END;
$$;

-- 2. Drop the unused 2-arg overload
DROP FUNCTION IF EXISTS public.calculate_payout_with_debt(uuid, numeric);

COMMENT ON FUNCTION public.calculate_payout_with_debt(uuid, numeric, numeric, numeric, numeric) IS
  'Calculate salon payout after debt collection. FIFO deduction, 50% cap. '
  'Called by stripe-webhook on every payment. v_net guarded against negative.';
