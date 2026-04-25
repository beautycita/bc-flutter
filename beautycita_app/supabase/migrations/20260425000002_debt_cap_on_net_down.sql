-- Restore the old gross-based cap. Down only — preserves grants since the
-- function signature is unchanged.
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
  v_net := p_gross_amount - p_commission - p_iva_withheld - p_isr_withheld;
  IF v_net < 0 THEN v_net := 0; END IF;

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

  v_max_deduction := LEAST(p_gross_amount * 0.50, v_net);
  v_actual_deduction := LEAST(v_max_deduction, v_total_debt);

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
