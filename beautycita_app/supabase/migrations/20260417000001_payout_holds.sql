-- Payout freeze-on-identity-change infrastructure.
-- Closes exploit: previously, any edit to beneficiary_name / rfc / clabe / stripe_account_id
-- passed through without freezing payouts. An attacker with account access could redirect
-- funds to their own account. This migration:
--   1. Creates payout_holds table tracking active freezes.
--   2. Adds a trigger that opens a hold when identity fields change.
--   3. Provides has_active_payout_hold() helper for RPC guards.
--   4. Provides release_payout_hold(hold_id, note) admin RPC.
--
-- Known limitation (to resolve in follow-up): when admin releases a hold, bookings
-- that accumulated during the hold window do NOT auto-retry their payouts. Admin must
-- reconcile manually via Stripe. A proper deferred_payouts + retry mechanism is a
-- separate follow-up task.

create table if not exists public.payout_holds (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  reason text not null check (reason in (
    'beneficiary_name_changed',
    'rfc_changed',
    'clabe_changed',
    'stripe_account_changed',
    'identity_mismatch',
    'third_party_complaint',
    'manual_admin'
  )),
  old_value text,
  new_value text,
  started_at timestamptz not null default now(),
  released_at timestamptz,
  released_by uuid references public.profiles(id),
  release_note text,
  created_at timestamptz not null default now()
);

create index if not exists payout_holds_business_active_idx
  on public.payout_holds (business_id)
  where released_at is null;

create index if not exists payout_holds_started_at_idx
  on public.payout_holds (started_at desc);

alter table public.payout_holds enable row level security;

drop policy if exists "admin read payout_holds" on public.payout_holds;
create policy "admin read payout_holds"
  on public.payout_holds for select
  using (is_admin());

drop policy if exists "business read own payout_holds" on public.payout_holds;
create policy "business read own payout_holds"
  on public.payout_holds for select
  using (business_id in (select id from public.businesses where owner_id = auth.uid()));

-- Only service role / admin can insert or update.
-- Admins do it via the release_payout_hold RPC.
-- The freeze trigger runs as SECURITY DEFINER and bypasses RLS.

-- ─────────────────────────────────────────────────────────────────────────────
-- Freeze trigger: opens a hold when identity fields change.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.freeze_payouts_on_identity_change()
returns trigger language plpgsql security definer as $$
begin
  if new.beneficiary_name is distinct from old.beneficiary_name then
    insert into public.payout_holds (business_id, reason, old_value, new_value)
    values (new.id, 'beneficiary_name_changed', old.beneficiary_name, new.beneficiary_name);
  end if;

  if new.rfc is distinct from old.rfc then
    insert into public.payout_holds (business_id, reason, old_value, new_value)
    values (new.id, 'rfc_changed', old.rfc, new.rfc);
  end if;

  if new.clabe is distinct from old.clabe then
    insert into public.payout_holds (business_id, reason, old_value, new_value)
    values (new.id, 'clabe_changed', old.clabe, new.clabe);
  end if;

  if new.stripe_account_id is distinct from old.stripe_account_id then
    insert into public.payout_holds (business_id, reason, old_value, new_value)
    values (new.id, 'stripe_account_changed', old.stripe_account_id, new.stripe_account_id);
  end if;

  return new;
end $$;

drop trigger if exists businesses_freeze_payouts_on_identity_change on public.businesses;

create trigger businesses_freeze_payouts_on_identity_change
  after update of beneficiary_name, rfc, clabe, stripe_account_id on public.businesses
  for each row execute procedure public.freeze_payouts_on_identity_change();

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: has_active_payout_hold(business_id) → boolean
-- Used by payout-gating RPCs and by the business-portal banner.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.has_active_payout_hold(p_business_id uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.payout_holds
    where business_id = p_business_id and released_at is null
  )
$$;

grant execute on function public.has_active_payout_hold(uuid) to authenticated, service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- release_payout_hold(hold_id, note) — admin RPC
-- Writes released_at / released_by / release_note, and captures the release
-- event in audit_log.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.release_payout_hold(p_hold_id uuid, p_note text)
returns payout_holds language plpgsql security definer as $$
declare
  v_hold public.payout_holds;
begin
  if not is_admin() then
    raise exception 'Admin privileges required to release payout holds';
  end if;

  if p_note is null or length(trim(p_note)) < 10 then
    raise exception 'Release note must describe the reason (minimum 10 characters)';
  end if;

  update public.payout_holds
  set released_at = now(),
      released_by = auth.uid(),
      release_note = p_note
  where id = p_hold_id and released_at is null
  returning * into v_hold;

  if v_hold.id is null then
    raise exception 'Payout hold not found or already released';
  end if;

  insert into public.audit_log (admin_id, action, target_type, target_id, details)
  values (
    coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid),
    'payout_hold_released',
    'payout_hold',
    v_hold.id::text,
    jsonb_build_object(
      'business_id', v_hold.business_id,
      'reason', v_hold.reason,
      'held_duration_seconds', extract(epoch from (now() - v_hold.started_at)),
      'note', p_note
    )
  );

  return v_hold;
end $$;

grant execute on function public.release_payout_hold(uuid, text) to authenticated;
