-- Payout-lock follow-ups: debt categorization, ToS acceptance tracking,
-- and the identity-check log table referenced by payout-identity-check.
--
-- Decision ref: Doc decision #13 (payout beneficiary lock).
-- Spec ref: docs/policies/2026-04-17-payout-beneficiary-lock.md §4.6, §4.2, §4.7.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. salon_debts.debt_type — drives SAT categorization on cancellation / write-off.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.salon_debts
  add column if not exists debt_type text not null default 'operational_commission'
  check (debt_type in (
    'operational_commission',       -- commission owed on booking / order refund
    'operational_refund_pos',       -- POS return shortfall
    'operational_saldo_overdraft',  -- saldo went negative
    'pursued_doubtful'              -- actively pursued but unlikely to collect (Art. 27 XV candidate)
  ));

create index if not exists salon_debts_business_type_idx
  on public.salon_debts (business_id, debt_type)
  where remaining_amount > 0;

-- Track extinguishment (ToS § 6b) separately from ordinary resolution.
alter table public.salon_debts
  add column if not exists extinguished_at timestamptz,
  add column if not exists extinguished_reason text;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. businesses.payout_lock_clause_accepted_at — per-salon acceptance of the
--    updated ToS § 1-7 payout-beneficiary clause. Required before payouts
--    are scheduled once enforcement flips on.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.businesses
  add column if not exists payout_lock_clause_accepted_at timestamptz;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. payout_identity_checks — audit log for payout-identity-check edge function.
--    CLABE-side holder lookup (STP/bank) is stubbed until BBVA onboarding; we
--    log what we can compare today so the table and interface exist.
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.payout_identity_checks (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  checked_at timestamptz not null default now(),
  rfc_match boolean,
  name_score numeric(4,3),
  destination_holder_name text,
  result text not null check (result in ('pass', 'review', 'fail', 'skipped_no_data')),
  notes text
);

create index if not exists payout_identity_checks_business_idx
  on public.payout_identity_checks (business_id, checked_at desc);

alter table public.payout_identity_checks enable row level security;

drop policy if exists "admin read payout_identity_checks" on public.payout_identity_checks;
create policy "admin read payout_identity_checks"
  on public.payout_identity_checks for select
  using (is_admin());

-- Only service role may insert (no direct user path).

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. extinguish_salon_debts_on_cancel(p_business_id, p_reason)
--    Applies ToS § 6b: on salon account cancellation, all outstanding debt
--    is extinguished. Marks rows via extinguished_at + extinguished_reason,
--    zeroes remaining_amount for downstream payout math, writes audit_log.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.extinguish_salon_debts_on_cancel(
  p_business_id uuid,
  p_reason text default 'account_cancelled_per_tos_6b'
)
returns integer
language plpgsql
security definer
as $$
declare
  v_count integer;
begin
  if not is_admin() then
    raise exception 'Admin privileges required to extinguish debts';
  end if;

  update public.salon_debts
  set remaining_amount = 0,
      extinguished_at = now(),
      extinguished_reason = p_reason
  where business_id = p_business_id
    and remaining_amount > 0
    and extinguished_at is null;

  get diagnostics v_count = row_count;

  update public.businesses
  set outstanding_debt = 0
  where id = p_business_id;

  insert into public.audit_log (admin_id, action, target_type, target_id, details)
  values (
    coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid),
    'salon_debts_extinguished',
    'business',
    p_business_id::text,
    jsonb_build_object('count', v_count, 'reason', p_reason)
  );

  return v_count;
end $$;

grant execute on function public.extinguish_salon_debts_on_cancel(uuid, text) to authenticated;

comment on function public.extinguish_salon_debts_on_cancel(uuid, text) is
  'Per ToS § 6b: on cancellation, extinguish all outstanding salon debts. Admin-only.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Backfill: enqueue a manual_admin payout_hold for any existing business
--    that is missing beneficiary_name or rfc. Ensures no payout fires for a
--    business without banking data even before the sidebar+UI prompts surface.
--    Idempotent: skipped when a hold already exists for that business.
-- ─────────────────────────────────────────────────────────────────────────────

insert into public.payout_holds (business_id, reason, old_value, new_value, started_at, release_note)
select b.id,
       'manual_admin',
       null,
       null,
       now(),
       'Backfill 2026-04-18: missing beneficiary_name or rfc; complete Pagos > Banco to release.'
from public.businesses b
where (b.beneficiary_name is null or b.beneficiary_name = '' or b.rfc is null or b.rfc = '')
  and not exists (
    select 1 from public.payout_holds h
    where h.business_id = b.id and h.released_at is null
  );
