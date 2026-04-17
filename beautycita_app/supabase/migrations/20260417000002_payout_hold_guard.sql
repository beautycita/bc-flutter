-- Guard calculate_payout_with_debt against active payout holds.
-- When a business has any active payout_hold, this RPC raises an exception
-- (SQLSTATE P0001, message 'PAYOUT_HOLD_ACTIVE: <business_id>') instead of
-- computing a payout. Callers (stripe-webhook etc.) must catch this and
-- log the event without transferring funds.

create or replace function public.calculate_payout_with_debt(
  p_business_id    uuid,
  p_gross_amount   numeric,
  p_commission     numeric,
  p_iva_withheld   numeric,
  p_isr_withheld   numeric
)
returns table(salon_payout numeric, debt_collected numeric, remaining_debt numeric)
language plpgsql
security definer
as $$
declare
  v_net numeric;
  v_total_debt numeric;
  v_max_deduction numeric;
  v_actual_deduction numeric;
  v_debt_record record;
  v_remaining_to_collect numeric;
begin
  -- GUARD: refuse to compute payout if business is under a payout hold.
  -- Caller must catch SQLSTATE P0001 with message prefix 'PAYOUT_HOLD_ACTIVE:'.
  if public.has_active_payout_hold(p_business_id) then
    raise exception 'PAYOUT_HOLD_ACTIVE: %', p_business_id;
  end if;

  -- Net payout before debt: gross - commission - IVA - ISR
  v_net := p_gross_amount - p_commission - p_iva_withheld - p_isr_withheld;

  -- Guard: never go negative
  if v_net < 0 then v_net := 0; end if;

  -- Get total outstanding debt
  select coalesce(sum(remaining_amount), 0) into v_total_debt
  from salon_debts
  where business_id = p_business_id and remaining_amount > 0;

  if v_total_debt <= 0 then
    salon_payout := v_net;
    debt_collected := 0;
    remaining_debt := 0;
    return next;
    return;
  end if;

  -- Max deduction: 50% of gross, capped by net and total debt
  v_max_deduction := least(p_gross_amount * 0.50, v_net);
  v_actual_deduction := least(v_max_deduction, v_total_debt);

  -- Apply FIFO to oldest debts
  v_remaining_to_collect := v_actual_deduction;
  for v_debt_record in
    select id, remaining_amount from salon_debts
    where business_id = p_business_id and remaining_amount > 0
    order by created_at asc
  loop
    if v_remaining_to_collect <= 0 then exit; end if;
    declare
      v_apply numeric := least(v_remaining_to_collect, v_debt_record.remaining_amount);
    begin
      update salon_debts set
        remaining_amount = remaining_amount - v_apply,
        cleared_at = case when remaining_amount - v_apply = 0 then now() else null end
      where id = v_debt_record.id;
      v_remaining_to_collect := v_remaining_to_collect - v_apply;
    end;
  end loop;

  -- Update cached debt on business
  update businesses set outstanding_debt = (
    select coalesce(sum(remaining_amount), 0) from salon_debts
    where business_id = p_business_id and remaining_amount > 0
  ) where id = p_business_id;

  salon_payout := v_net - v_actual_deduction;
  debt_collected := v_actual_deduction;
  remaining_debt := v_total_debt - v_actual_deduction;
  return next;
  return;
end;
$$;

comment on function public.calculate_payout_with_debt(uuid, numeric, numeric, numeric, numeric) is
  'Calculate salon payout after debt collection. FIFO deduction, 50% cap. '
  'Guarded by has_active_payout_hold() — raises PAYOUT_HOLD_ACTIVE on hold. '
  'Called by stripe-webhook on every payment.';
