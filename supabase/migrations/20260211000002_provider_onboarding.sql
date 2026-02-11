-- =============================================================================
-- Migration: 20260211000002_provider_onboarding.sql
-- Description: Complete service provider onboarding schema including:
--              - Service-level deposit configuration
--              - Payment tracking for appointments
--              - No-show refund handling
--              - Onboarding state tracking
--              - Stylist role for profiles
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Add stylist role to profiles
-- ---------------------------------------------------------------------------
alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check check (role in ('customer', 'stylist', 'admin', 'superadmin'));

comment on column public.profiles.role is 'User role: customer (default), stylist (business owner), admin, superadmin';

-- ---------------------------------------------------------------------------
-- 2. Add user_id to staff table for login association
-- ---------------------------------------------------------------------------
alter table public.staff
  add column if not exists user_id uuid references auth.users(id) on delete set null;

create index if not exists idx_staff_user_id on public.staff (user_id) where user_id is not null;

comment on column public.staff.user_id is 'Links staff member to their Supabase auth account for portal access';

-- ---------------------------------------------------------------------------
-- 3. Add service-level deposit configuration
-- ---------------------------------------------------------------------------
alter table public.services
  add column if not exists deposit_required boolean not null default false,
  add column if not exists deposit_percentage numeric(5,2) not null default 50.00,
  add column if not exists description text,
  add column if not exists image_url text;

comment on column public.services.deposit_required is 'Whether this service requires a non-refundable deposit';
comment on column public.services.deposit_percentage is 'Deposit percentage (0-100). Default 50% of service price';

-- ---------------------------------------------------------------------------
-- 4. Add payment tracking to appointments
-- ---------------------------------------------------------------------------
alter table public.appointments
  add column if not exists payment_status text not null default 'unpaid',
  add column if not exists payment_intent_id text,
  add column if not exists stripe_checkout_session_id text,
  add column if not exists paid_at timestamptz,
  add column if not exists refunded_at timestamptz,
  add column if not exists refund_amount numeric(10,2),
  add column if not exists platform_fee numeric(10,2),
  add column if not exists provider_payout numeric(10,2);

alter table public.appointments
  drop constraint if exists appointments_payment_status_check;

alter table public.appointments
  add constraint appointments_payment_status_check check (
    payment_status in ('unpaid', 'pending', 'paid', 'refunded', 'partial_refund', 'failed')
  );

comment on column public.appointments.payment_status is 'Payment state: unpaid, pending, paid, refunded, partial_refund, failed';
comment on column public.appointments.platform_fee is 'BeautyCita 3% platform fee';
comment on column public.appointments.provider_payout is 'Amount to pay out to the provider after fees';

-- ---------------------------------------------------------------------------
-- 5. Create payments table for transaction history
-- ---------------------------------------------------------------------------
create table if not exists public.payments (
  id                       uuid        not null default gen_random_uuid(),
  appointment_id           uuid        not null references public.appointments(id) on delete cascade,
  stripe_payment_intent_id text,
  stripe_charge_id         text,
  stripe_transfer_id       text,
  amount                   integer     not null, -- in centavos
  currency                 text        not null default 'mxn',
  status                   text        not null,
  type                     text        not null default 'payment', -- payment, refund, payout
  metadata                 jsonb,
  created_at               timestamptz not null default now(),

  constraint payments_pkey primary key (id),
  constraint payments_status_check check (status in ('pending', 'succeeded', 'failed', 'refunded')),
  constraint payments_type_check check (type in ('payment', 'refund', 'payout', 'platform_fee'))
);

comment on table public.payments is 'Payment transaction history for auditing and reconciliation';

create index idx_payments_appointment on public.payments (appointment_id);
create index idx_payments_stripe_pi on public.payments (stripe_payment_intent_id) where stripe_payment_intent_id is not null;

alter table public.payments enable row level security;

create policy "Payments: users can view their appointment payments"
  on public.payments for select
  using (
    appointment_id in (
      select id from public.appointments where user_id = auth.uid()
    )
  );

create policy "Payments: business owners can view their payments"
  on public.payments for select
  using (
    appointment_id in (
      select a.id from public.appointments a
      join public.businesses b on a.business_id = b.id
      where b.owner_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 6. Add business onboarding tracking
-- ---------------------------------------------------------------------------
alter table public.businesses
  add column if not exists onboarding_step text not null default 'profile',
  add column if not exists has_services boolean not null default false,
  add column if not exists has_schedule boolean not null default false;

alter table public.businesses
  drop constraint if exists businesses_onboarding_step_check;

alter table public.businesses
  add constraint businesses_onboarding_step_check check (
    onboarding_step in ('profile', 'services', 'schedule', 'stripe', 'complete')
  );

comment on column public.businesses.onboarding_step is 'Current onboarding step: profile, services, schedule, stripe, complete';
comment on column public.businesses.has_services is 'True when at least one service is fully configured';
comment on column public.businesses.has_schedule is 'True when staff schedule is configured';

-- ---------------------------------------------------------------------------
-- 7. Trigger to auto-update has_services flag
-- ---------------------------------------------------------------------------
create or replace function public.check_business_services()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
  v_has_services boolean;
begin
  if tg_op = 'DELETE' then
    v_business_id := old.business_id;
  else
    v_business_id := new.business_id;
  end if;

  -- Check if business has at least one active service with price
  select exists(
    select 1 from public.services
    where business_id = v_business_id
      and is_active = true
      and price is not null
      and price > 0
  ) into v_has_services;

  update public.businesses
  set has_services = v_has_services
  where id = v_business_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists services_check_business on public.services;
create trigger services_check_business
  after insert or update or delete on public.services
  for each row execute function public.check_business_services();

-- ---------------------------------------------------------------------------
-- 8. Trigger to auto-update has_schedule flag
-- ---------------------------------------------------------------------------
create or replace function public.check_business_schedule()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staff_id uuid;
  v_business_id uuid;
  v_has_schedule boolean;
begin
  if tg_op = 'DELETE' then
    v_staff_id := old.staff_id;
  else
    v_staff_id := new.staff_id;
  end if;

  -- Get the business_id for this staff
  select business_id into v_business_id
  from public.staff
  where id = v_staff_id;

  if v_business_id is null then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  -- Check if business has at least one staff with schedule
  select exists(
    select 1 from public.staff_schedules ss
    join public.staff s on ss.staff_id = s.id
    where s.business_id = v_business_id
      and ss.is_available = true
  ) into v_has_schedule;

  update public.businesses
  set has_schedule = v_has_schedule
  where id = v_business_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists schedules_check_business on public.staff_schedules;
create trigger schedules_check_business
  after insert or update or delete on public.staff_schedules
  for each row execute function public.check_business_schedule();

-- ---------------------------------------------------------------------------
-- 9. Function to check and update onboarding_complete status
-- ---------------------------------------------------------------------------
create or replace function public.update_onboarding_complete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Check all conditions for onboarding_complete
  if new.has_services = true
    and new.has_schedule = true
    and new.stripe_account_id is not null
    and new.stripe_charges_enabled = true
    and new.stripe_payouts_enabled = true
  then
    new.onboarding_complete := true;
    new.onboarding_step := 'complete';
  else
    new.onboarding_complete := false;
    -- Update step based on what's missing
    if not new.has_services then
      new.onboarding_step := 'services';
    elsif not new.has_schedule then
      new.onboarding_step := 'schedule';
    elsif new.stripe_account_id is null or not new.stripe_charges_enabled then
      new.onboarding_step := 'stripe';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists businesses_onboarding_check on public.businesses;
create trigger businesses_onboarding_check
  before update on public.businesses
  for each row execute function public.update_onboarding_complete();

-- ---------------------------------------------------------------------------
-- 10. RLS policies for business owners to manage their data
-- ---------------------------------------------------------------------------

-- Businesses: owners can update their own
create policy "Businesses: owners can update their own"
  on public.businesses for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Businesses: owners can insert
create policy "Businesses: authenticated users can insert"
  on public.businesses for insert
  with check (owner_id = auth.uid());

-- Services: owners can manage
create policy "Services: owners can insert"
  on public.services for insert
  with check (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  );

create policy "Services: owners can update"
  on public.services for update
  using (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  )
  with check (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  );

create policy "Services: owners can delete"
  on public.services for delete
  using (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  );

-- Staff: owners can manage
create policy "Staff: owners can insert"
  on public.staff for insert
  with check (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  );

create policy "Staff: owners can update"
  on public.staff for update
  using (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  )
  with check (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  );

-- Staff schedules: owners can manage
create policy "Staff schedules: owners can insert"
  on public.staff_schedules for insert
  with check (
    staff_id in (
      select s.id from public.staff s
      join public.businesses b on s.business_id = b.id
      where b.owner_id = auth.uid()
    )
  );

create policy "Staff schedules: owners can update"
  on public.staff_schedules for update
  using (
    staff_id in (
      select s.id from public.staff s
      join public.businesses b on s.business_id = b.id
      where b.owner_id = auth.uid()
    )
  )
  with check (
    staff_id in (
      select s.id from public.staff s
      join public.businesses b on s.business_id = b.id
      where b.owner_id = auth.uid()
    )
  );

create policy "Staff schedules: owners can delete"
  on public.staff_schedules for delete
  using (
    staff_id in (
      select s.id from public.staff s
      join public.businesses b on s.business_id = b.id
      where b.owner_id = auth.uid()
    )
  );

-- Staff services: owners can manage
create policy "Staff services: owners can insert"
  on public.staff_services for insert
  with check (
    staff_id in (
      select s.id from public.staff s
      join public.businesses b on s.business_id = b.id
      where b.owner_id = auth.uid()
    )
  );

create policy "Staff services: owners can update"
  on public.staff_services for update
  using (
    staff_id in (
      select s.id from public.staff s
      join public.businesses b on s.business_id = b.id
      where b.owner_id = auth.uid()
    )
  )
  with check (
    staff_id in (
      select s.id from public.staff s
      join public.businesses b on s.business_id = b.id
      where b.owner_id = auth.uid()
    )
  );

create policy "Staff services: owners can delete"
  on public.staff_services for delete
  using (
    staff_id in (
      select s.id from public.staff s
      join public.businesses b on s.business_id = b.id
      where b.owner_id = auth.uid()
    )
  );

-- Appointments: business owners can read their business appointments
create policy "Appointments: business owners can read"
  on public.appointments for select
  using (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  );

-- Appointments: business owners can update status
create policy "Appointments: business owners can update"
  on public.appointments for update
  using (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  )
  with check (
    business_id in (
      select id from public.businesses where owner_id = auth.uid()
    )
  );
