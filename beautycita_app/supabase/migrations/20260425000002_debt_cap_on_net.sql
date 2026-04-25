-- =============================================================================
-- Debt-collection cap: 50% of NET payout, not 50% of GROSS
-- =============================================================================
-- Policy (per BC, 2026-04-25):
--   "Take at most half of the stylist's payout from each client until debt
--   is resolved."
--
-- The "payout" is what the stylist would receive ABSENT debt — i.e., gross
-- minus commission, ISR, IVA. The pre-existing migration capped at
-- p_gross_amount * 0.50, which since gross > net (taxes + commission strip
-- 4–25%), routinely overshoots the policy:
--   • $1000 service, RFC: net=$876, cap=$500 = 57% of net.
--   • $1000 service, no-RFC: net=$748, cap=$500 = 67% of net.
--
-- Fix: cap at v_net * 0.50. Stylist always retains at least half their net
-- on every service. Multi-debt FIFO logic stays the same.
-- =============================================================================

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

  -- Max deduction: 50% of NET (stylist payout floor 50%), capped by net
  -- (in case rounding pushes it slightly over) and total outstanding debt.
  v_max_deduction := LEAST(v_net * 0.50, v_net);
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

COMMENT ON FUNCTION public.calculate_payout_with_debt(uuid, numeric, numeric, numeric, numeric) IS
  'Calculate salon payout after debt collection. FIFO deduction. Cap = 50% '
  'of NET (gross - commission - ISR - IVA), so stylist always retains at '
  'least half their take-home per service. Called by stripe-webhook on every '
  'payment. v_net guarded against negative.';
