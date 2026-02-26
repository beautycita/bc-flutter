-- ---------------------------------------------------------------------------
-- Disputes table — client-filed disputes against completed appointments
-- ---------------------------------------------------------------------------

create table if not exists public.disputes (
  id               uuid          not null default gen_random_uuid(),
  appointment_id   uuid          not null references public.appointments(id) on delete cascade,
  user_id          uuid          not null references auth.users(id) on delete cascade,
  business_id      uuid          references public.businesses(id) on delete set null,
  reason           text          not null,
  client_evidence  text,
  stylist_evidence text,
  status           text          not null default 'open',
  resolution       text,
  resolution_notes text,
  resolved_by      uuid          references auth.users(id) on delete set null,
  resolved_at      timestamptz,
  refund_amount    numeric(10,2),
  refund_status    text,
  created_at       timestamptz   not null default now(),
  updated_at       timestamptz   not null default now(),

  constraint disputes_pkey primary key (id),
  constraint disputes_status_check check (
    status in ('open', 'resolved', 'rejected')
  ),
  constraint disputes_resolution_check check (
    resolution is null or resolution in (
      'favor_client', 'favor_provider', 'favor_both', 'dismissed'
    )
  ),
  constraint disputes_refund_status_check check (
    refund_status is null or refund_status in (
      'pending', 'processed', 'failed'
    )
  )
);

comment on table public.disputes is 'Client-filed disputes against completed appointments.';

-- Updated-at trigger
create trigger disputes_updated_at
  before update on public.disputes
  for each row execute function public.handle_updated_at();

-- Indexes
create index idx_disputes_user on public.disputes (user_id);
create index idx_disputes_business on public.disputes (business_id);
create index idx_disputes_status on public.disputes (status);
create index idx_disputes_appointment on public.disputes (appointment_id);

-- RLS
alter table public.disputes enable row level security;

-- Clients can read their own disputes
create policy "Disputes: users can read their own"
  on public.disputes for select
  using (auth.uid() = user_id);

-- Clients can create disputes
create policy "Disputes: users can create their own"
  on public.disputes for insert
  with check (auth.uid() = user_id);

-- Admins can read all disputes
create policy "Disputes: admins can read all"
  on public.disputes for select
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('admin', 'superadmin')
    )
  );

-- Admins can update all disputes (resolve, add notes)
create policy "Disputes: admins can update all"
  on public.disputes for update
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role in ('admin', 'superadmin')
    )
  );

-- Business owners can read disputes on their appointments
create policy "Disputes: business owners can read their own"
  on public.disputes for select
  using (
    exists (
      select 1 from public.businesses
      where id = business_id and owner_id = auth.uid()
    )
  );

-- Business owners can update stylist_evidence on their disputes
create policy "Disputes: business owners can respond"
  on public.disputes for update
  using (
    exists (
      select 1 from public.businesses
      where id = business_id and owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.businesses
      where id = business_id and owner_id = auth.uid()
    )
  );
