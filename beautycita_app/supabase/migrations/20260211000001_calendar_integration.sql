-- =============================================================================
-- Migration: 20260211000001_calendar_integration.sql
-- Description: Adds tables and functions for proper availability tracking from
--              multiple sources: external calendars, third-party booking platforms,
--              and one-off time blocks.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Staff Availability Overrides - One-off time blocks
-- ---------------------------------------------------------------------------
create table if not exists public.staff_availability_overrides (
  id           uuid        not null default gen_random_uuid(),
  staff_id     uuid        not null references public.staff(id) on delete cascade,
  override_date date       not null,
  start_time   time        null,     -- null = all day
  end_time     time        null,     -- null = all day
  is_available boolean     not null, -- false = blocked, true = extra availability
  reason       text        null,     -- e.g., "Personal appointment", "Training"
  created_at   timestamptz not null default now(),

  constraint staff_availability_overrides_pkey primary key (id)
);

comment on table public.staff_availability_overrides is
  'One-off availability changes for specific dates. Overrides the weekly staff_schedules template.';

create index idx_staff_avail_overrides_lookup
  on public.staff_availability_overrides (staff_id, override_date) where is_available = false;

alter table public.staff_availability_overrides enable row level security;

create policy "Staff can manage their own overrides"
  on public.staff_availability_overrides
  for all
  using (
    staff_id in (
      select id from public.staff where user_id = auth.uid()
    )
  )
  with check (
    staff_id in (
      select id from public.staff where user_id = auth.uid()
    )
  );

create policy "Owners can manage staff overrides"
  on public.staff_availability_overrides
  for all
  using (
    exists (
      select 1 from public.staff s
      join public.businesses b on s.business_id = b.id
      where s.id = staff_availability_overrides.staff_id
        and b.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.staff s
      join public.businesses b on s.business_id = b.id
      where s.id = staff_availability_overrides.staff_id
        and b.owner_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 2. Calendar Connections - Track external calendar sync
-- ---------------------------------------------------------------------------
create table if not exists public.calendar_connections (
  id              uuid        not null default gen_random_uuid(),
  staff_id        uuid        not null references public.staff(id) on delete cascade,
  provider        text        not null, -- 'google', 'apple', 'outlook', 'ical_url'
  external_id     text        null,     -- Provider-specific calendar ID
  access_token    text        null,     -- Encrypted OAuth token
  refresh_token   text        null,     -- Encrypted refresh token
  token_expires_at timestamptz null,
  ical_url        text        null,     -- For ICS feed subscriptions
  sync_enabled    boolean     not null default true,
  last_synced_at  timestamptz null,
  sync_error      text        null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint calendar_connections_pkey primary key (id),
  constraint calendar_connections_provider_check check (provider in ('google', 'apple', 'outlook', 'ical_url'))
);

comment on table public.calendar_connections is
  'External calendar connections for syncing staff availability. Supports OAuth-based (Google, Outlook) and ICS URL feeds.';

create unique index idx_calendar_connections_staff_provider
  on public.calendar_connections (staff_id, provider);

alter table public.calendar_connections enable row level security;

create policy "Staff can manage their own calendar connections"
  on public.calendar_connections
  for all
  using (
    staff_id in (
      select id from public.staff where user_id = auth.uid()
    )
  )
  with check (
    staff_id in (
      select id from public.staff where user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 3. External Appointments - Synced/scraped from other platforms
-- ---------------------------------------------------------------------------
create table if not exists public.external_appointments (
  id              uuid        not null default gen_random_uuid(),
  staff_id        uuid        not null references public.staff(id) on delete cascade,
  source          text        not null, -- 'google_calendar', 'fresha', 'vagaro', 'ical', 'manual'
  external_id     text        null,     -- ID from external system
  title           text        null,     -- Event title (may be private)
  starts_at       timestamptz not null,
  ends_at         timestamptz not null,
  is_blocking     boolean     not null default true, -- false = tentative/free
  raw_data        jsonb       null,     -- Full event data from source
  synced_at       timestamptz not null default now(),

  constraint external_appointments_pkey primary key (id),
  constraint external_appointments_source_check check (source in ('google_calendar', 'apple_calendar', 'outlook', 'fresha', 'vagaro', 'ical', 'manual'))
);

comment on table public.external_appointments is
  'Appointments from external sources (calendars, booking platforms, scrapers) that block availability.';

-- Composite index for availability lookups
create index idx_external_appointments_availability
  on public.external_appointments (staff_id, starts_at, ends_at) where is_blocking = true;

-- Unique constraint to prevent duplicate syncs
create unique index idx_external_appointments_source_unique
  on public.external_appointments (staff_id, source, external_id) where external_id is not null;

alter table public.external_appointments enable row level security;

create policy "Staff can view their own external appointments"
  on public.external_appointments
  for select
  using (
    staff_id in (
      select id from public.staff where user_id = auth.uid()
    )
  );

create policy "Owners can view staff external appointments"
  on public.external_appointments
  for select
  using (
    exists (
      select 1 from public.staff s
      join public.businesses b on s.business_id = b.id
      where s.id = external_appointments.staff_id
        and b.owner_id = auth.uid()
    )
  );

-- Service role can insert/update from sync functions
create policy "Service role can manage external appointments"
  on public.external_appointments
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- ---------------------------------------------------------------------------
-- 4. Update find_available_slots to check all sources
-- ---------------------------------------------------------------------------
create or replace function public.find_available_slots(
  p_staff_id uuid,
  p_duration_minutes integer,
  p_window_start timestamptz,
  p_window_end timestamptz
)
returns table (slot_start timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_date date;
  v_dow smallint;
  v_schedule record;
  v_slot_start timestamptz;
  v_slot_end timestamptz;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_override record;
begin
  -- Iterate over each date in the window
  v_date := p_window_start::date;
  while v_date <= p_window_end::date loop
    v_dow := extract(dow from v_date)::smallint;

    -- Check for full-day block override
    select * into v_override
    from public.staff_availability_overrides sao
    where sao.staff_id = p_staff_id
      and sao.override_date = v_date
      and sao.is_available = false
      and sao.start_time is null  -- Full day block
    limit 1;

    if found then
      -- Skip this entire day
      v_date := v_date + 1;
      continue;
    end if;

    -- Get the staff schedule for this day of week
    select ss.start_time, ss.end_time
    into v_schedule
    from public.staff_schedules ss
    where ss.staff_id = p_staff_id
      and ss.day_of_week = v_dow
      and ss.is_available = true;

    -- If staff works this day, generate slots
    if found then
      v_day_start := v_date + v_schedule.start_time;
      v_day_end   := v_date + v_schedule.end_time;

      -- Clamp to window boundaries
      if v_day_start < p_window_start then
        v_day_start := p_window_start;
      end if;
      if v_day_end > p_window_end then
        v_day_end := p_window_end;
      end if;

      -- Generate hourly slots within working hours
      v_slot_start := v_day_start;
      while v_slot_start + (p_duration_minutes || ' minutes')::interval <= v_day_end loop
        v_slot_end := v_slot_start + (p_duration_minutes || ' minutes')::interval;

        -- Check for overlapping BeautyCita appointments
        if not exists (
          select 1
          from public.appointments a
          where a.staff_id = p_staff_id
            and a.status not in ('cancelled_customer', 'cancelled_business', 'no_show')
            and a.starts_at < v_slot_end
            and a.ends_at > v_slot_start
        )
        -- Check for overlapping external appointments (calendars, Fresha, etc.)
        and not exists (
          select 1
          from public.external_appointments ea
          where ea.staff_id = p_staff_id
            and ea.is_blocking = true
            and ea.starts_at < v_slot_end
            and ea.ends_at > v_slot_start
        )
        -- Check for partial-day override blocks
        and not exists (
          select 1
          from public.staff_availability_overrides sao
          where sao.staff_id = p_staff_id
            and sao.override_date = v_date
            and sao.is_available = false
            and sao.start_time is not null
            and (v_date + sao.start_time) < v_slot_end
            and (v_date + sao.end_time) > v_slot_start
        )
        then
          slot_start := v_slot_start;
          return next;
        end if;

        -- Advance by 1 hour
        v_slot_start := v_slot_start + interval '1 hour';
      end loop;
    end if;

    v_date := v_date + 1;
  end loop;

  return;
end;
$$;

comment on function public.find_available_slots is
  'Generates available appointment slots for a staff member within a time window. '
  'Checks against BeautyCita appointments, external calendar appointments, and availability overrides.';

-- ---------------------------------------------------------------------------
-- 5. Add onboarding_complete flag to businesses for Stripe verification
-- ---------------------------------------------------------------------------
alter table public.businesses
  add column if not exists onboarding_complete boolean not null default false;

comment on column public.businesses.onboarding_complete is
  'True when business has completed all onboarding steps including Stripe Express verification.';

-- ---------------------------------------------------------------------------
-- 6. Update curate_candidates to only return fully onboarded businesses
-- ---------------------------------------------------------------------------
create or replace function public.curate_candidates(
  p_service_type text,
  p_lat double precision,
  p_lng double precision,
  p_radius_meters integer,
  p_window_start timestamptz,
  p_window_end timestamptz
)
returns table (
  business_id        uuid,
  business_name      text,
  business_photo     text,
  business_address   text,
  business_lat       double precision,
  business_lng       double precision,
  business_whatsapp  text,
  business_rating    numeric,
  business_reviews   integer,
  cancellation_hours integer,
  deposit_required   boolean,
  auto_confirm       boolean,
  accept_walkins     boolean,
  service_id         uuid,
  service_name       text,
  service_price      numeric,
  duration_minutes   integer,
  buffer_minutes     integer,
  staff_id           uuid,
  staff_name         text,
  staff_avatar       text,
  experience_years   integer,
  staff_rating       numeric,
  staff_reviews      integer,
  effective_price    numeric,
  effective_duration integer,
  distance_m         double precision,
  slot_start         timestamptz,
  slot_end           timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with service_match as (
    select
      b.id            as business_id,
      b.name          as business_name,
      b.photo_url     as business_photo,
      b.address       as business_address,
      b.lat           as business_lat,
      b.lng           as business_lng,
      b.whatsapp      as business_whatsapp,
      b.average_rating as business_rating,
      b.total_reviews  as business_reviews,
      b.cancellation_hours,
      b.deposit_required,
      b.auto_confirm,
      b.accept_walkins,
      s.id            as service_id,
      s.name          as service_name,
      s.price         as service_price,
      s.duration_minutes,
      s.buffer_minutes,
      st.id           as staff_id,
      st.first_name || ' ' || coalesce(left(st.last_name, 1) || '.', '') as staff_name,
      st.avatar_url   as staff_avatar,
      st.experience_years,
      st.average_rating as staff_rating,
      st.total_reviews  as staff_reviews,
      coalesce(ss.custom_price, s.price)       as effective_price,
      coalesce(ss.custom_duration, s.duration_minutes) as effective_duration,
      ST_Distance(
        b.location,
        ST_MakePoint(p_lng, p_lat)::geography
      ) as distance_m
    from businesses b
    join services s          on s.business_id = b.id
    join staff_services ss   on ss.service_id = s.id
    join staff st            on st.id = ss.staff_id
    where s.service_type = p_service_type
      and s.is_active   = true
      and st.is_active  = true
      and st.accept_online_booking = true
      and b.is_active   = true
      and b.onboarding_complete = true  -- Only fully onboarded businesses
      and ST_DWithin(
        b.location,
        ST_MakePoint(p_lng, p_lat)::geography,
        p_radius_meters
      )
  )
  select
    sm.business_id,
    sm.business_name,
    sm.business_photo,
    sm.business_address,
    sm.business_lat,
    sm.business_lng,
    sm.business_whatsapp,
    sm.business_rating,
    sm.business_reviews,
    sm.cancellation_hours,
    sm.deposit_required,
    sm.auto_confirm,
    sm.accept_walkins,
    sm.service_id,
    sm.service_name,
    sm.service_price,
    sm.duration_minutes,
    sm.buffer_minutes,
    sm.staff_id,
    sm.staff_name,
    sm.staff_avatar,
    sm.experience_years,
    sm.staff_rating,
    sm.staff_reviews,
    sm.effective_price,
    sm.effective_duration,
    sm.distance_m,
    slots.slot_start,
    slots.slot_start + (sm.effective_duration || ' minutes')::interval as slot_end
  from service_match sm
  cross join lateral find_available_slots(
    sm.staff_id,
    sm.effective_duration + sm.buffer_minutes,
    p_window_start,
    p_window_end
  ) slots
  limit 50;
$$;

comment on function public.curate_candidates is
  'Finds candidate businesses/staff/slots for the curate-results engine. '
  'Only returns fully onboarded businesses. Checks availability from all sources.';
