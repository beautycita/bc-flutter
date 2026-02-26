-- =============================================================================
-- BeautyCita — Intelligent Booking Engine: Complete Schema
-- Migration: 20260201000000_initial_schema.sql
-- Description: Full database schema for the BeautyCita intelligent booking
--              engine. Replaces the original provider-based schema with the
--              new businesses/staff/appointments model plus the complete
--              intelligence layer (service profiles, time inference, review
--              intelligence, engine settings, analytics, Uber integration,
--              salon discovery pipeline).
-- Design doc:  docs/plan/2026-01-31-beautycita-intelligent-booking-engine-design.md
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "postgis";

-- ---------------------------------------------------------------------------
-- 2. Helper function: auto-update updated_at timestamp
-- ---------------------------------------------------------------------------
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================================================================
--  CORE TABLES (Foundation)
-- =========================================================================

-- ---------------------------------------------------------------------------
-- 3. Table: profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id           uuid        not null references auth.users on delete cascade,
  username     text        not null,
  full_name    text,
  avatar_url   text,
  role         text        not null default 'customer',
  home_lat     double precision,
  home_lng     double precision,
  home_address text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint profiles_pkey primary key (id),
  constraint profiles_username_unique unique (username),
  constraint profiles_username_length check (char_length(username) >= 3),
  constraint profiles_role_check check (role in ('customer', 'admin'))
);

comment on table public.profiles is 'User profiles linked to Supabase auth.users.';

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

-- RLS
alter table public.profiles enable row level security;

create policy "Profiles: anyone can read"
  on public.profiles for select
  using (true);

create policy "Profiles: users can insert their own"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Profiles: users can update their own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Auto-create profile on signup via auth trigger
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'username',
      'user_' || left(new.id::text, 8)
    )
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 4. Table: businesses (replaces old "providers")
-- ---------------------------------------------------------------------------
create table public.businesses (
  id                   uuid             not null default gen_random_uuid(),
  owner_id             uuid             references auth.users on delete set null,
  name                 text             not null,
  phone                text,
  whatsapp             text,
  address              text,
  city                 text             not null default 'Guadalajara',
  state                text             not null default 'Jalisco',
  country              text             not null default 'MX',
  lat                  double precision,
  lng                  double precision,
  location             geography(Point, 4326),
  photo_url            text,
  average_rating       numeric(3,2)     not null default 0.00,
  total_reviews        integer          not null default 0,
  business_category    text,
  service_categories   text[],
  hours                jsonb,
  website              text,
  facebook_url         text,
  instagram_handle     text,
  is_verified          boolean          not null default false,
  is_active            boolean          not null default true,
  tier                 integer          not null default 1,
  cancellation_hours   integer          not null default 24,
  deposit_required     boolean          not null default false,
  deposit_percentage   numeric(5,2)     not null default 0,
  auto_confirm         boolean          not null default true,
  accept_walkins       boolean          not null default false,
  created_at           timestamptz      not null default now(),
  updated_at           timestamptz      not null default now(),

  constraint businesses_pkey primary key (id),
  constraint businesses_tier_check check (tier between 1 and 3)
);

comment on table public.businesses is 'Beauty service businesses (salons, spas, barber shops, etc.).';

create trigger businesses_updated_at
  before update on public.businesses
  for each row execute function public.handle_updated_at();

-- Auto-populate the PostGIS location column from lat/lng
create or replace function public.handle_business_location()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.lat is not null and new.lng is not null then
    new.location = st_setsrid(st_makepoint(new.lng, new.lat), 4326)::geography;
  else
    new.location = null;
  end if;
  return new;
end;
$$;

create trigger businesses_set_location
  before insert or update of lat, lng on public.businesses
  for each row execute function public.handle_business_location();

-- Indexes
create index idx_businesses_location       on public.businesses using gist (location);
create index idx_businesses_service_cats   on public.businesses using gin  (service_categories);
create index idx_businesses_city           on public.businesses (city);
create index idx_businesses_is_active      on public.businesses (is_active) where is_active = true;
create index idx_businesses_rating         on public.businesses (average_rating desc nulls last);

-- RLS
alter table public.businesses enable row level security;

create policy "Businesses: anyone can read active"
  on public.businesses for select
  using (is_active = true);

-- ---------------------------------------------------------------------------
-- 5. Table: staff
-- ---------------------------------------------------------------------------
create table public.staff (
  id                    uuid        not null default gen_random_uuid(),
  business_id           uuid        not null references public.businesses(id) on delete cascade,
  first_name            text        not null,
  last_name             text,
  avatar_url            text,
  phone                 text,
  experience_years      integer,
  average_rating        numeric(3,2) not null default 0.00,
  total_reviews         integer      not null default 0,
  is_active             boolean      not null default true,
  accept_online_booking boolean      not null default true,
  sort_order            integer      not null default 0,
  created_at            timestamptz  not null default now(),
  updated_at            timestamptz  not null default now(),

  constraint staff_pkey primary key (id)
);

comment on table public.staff is 'Individual staff members at a business.';

create trigger staff_updated_at
  before update on public.staff
  for each row execute function public.handle_updated_at();

-- Indexes
create index idx_staff_business on public.staff (business_id);

-- RLS
alter table public.staff enable row level security;

create policy "Staff: anyone can read active"
  on public.staff for select
  using (is_active = true);

-- ---------------------------------------------------------------------------
-- 6. Table: service_profiles (MUST come before services due to FK)
--    Intelligence engine configuration per service type — Section 4
-- ---------------------------------------------------------------------------
create table public.service_profiles (
  id                     uuid        not null default gen_random_uuid(),
  service_type           text        not null,
  category               text        not null,
  subcategory            text,
  display_name_es        text        not null,
  display_name_en        text        not null,
  icon                   text,

  -- Service characteristics
  availability_level     numeric(3,2) not null default 0.80,
  typical_duration_min   integer      not null default 60,
  skill_criticality      numeric(3,2) not null default 0.30,
  price_variance         numeric(3,2) not null default 0.20,
  portfolio_importance   numeric(3,2) not null default 0.00,

  -- Time inference
  typical_lead_time      text         not null default 'same_day',
  is_event_driven        boolean      not null default false,

  -- Search behavior
  search_radius_km       numeric(5,1) not null default 8.0,
  radius_auto_expand     boolean      not null default true,
  radius_max_multiplier  numeric(3,1) not null default 3.0,
  max_follow_up_questions integer     not null default 0,

  -- Ranking weights (MUST sum to 1.0)
  weight_proximity       numeric(3,2) not null default 0.40,
  weight_availability    numeric(3,2) not null default 0.25,
  weight_rating          numeric(3,2) not null default 0.20,
  weight_price           numeric(3,2) not null default 0.15,
  weight_portfolio       numeric(3,2) not null default 0.00,

  -- Card display rules
  show_price_comparison    boolean not null default false,
  show_portfolio_carousel  boolean not null default false,
  show_experience_years    boolean not null default false,
  show_certification_badge boolean not null default false,
  show_walkin_indicator    boolean not null default true,

  -- Meta
  is_active  boolean      not null default true,
  created_at timestamptz  not null default now(),
  updated_at timestamptz  not null default now(),
  updated_by uuid         references auth.users(id),

  constraint service_profiles_pkey primary key (id),
  constraint service_profiles_service_type_unique unique (service_type),
  constraint service_profiles_lead_time_check check (
    typical_lead_time in ('same_day', 'next_day', 'this_week', 'next_week', 'months')
  ),
  constraint weights_sum_one check (
    abs((weight_proximity + weight_availability + weight_rating +
         weight_price + weight_portfolio) - 1.0) < 0.01
  )
);

comment on table public.service_profiles is 'Intelligence engine configuration per service type. Each leaf node in the category tree maps to one row.';

create trigger service_profiles_updated_at
  before update on public.service_profiles
  for each row execute function public.handle_updated_at();

-- Indexes
create index idx_service_profiles_type
  on public.service_profiles (service_type) where is_active = true;

-- RLS
alter table public.service_profiles enable row level security;

create policy "Service profiles: anyone can read active"
  on public.service_profiles for select
  using (is_active = true);

-- ---------------------------------------------------------------------------
-- 7. Table: services
-- ---------------------------------------------------------------------------
create table public.services (
  id               uuid          not null default gen_random_uuid(),
  business_id      uuid          not null references public.businesses(id) on delete cascade,
  service_type     text          references public.service_profiles(service_type),
  name             text          not null,
  category         text,
  subcategory      text,
  price            numeric(10,2),
  duration_minutes integer       not null default 60,
  buffer_minutes   integer       not null default 0,
  is_active        boolean       not null default true,
  created_at       timestamptz   not null default now(),

  constraint services_pkey primary key (id)
);

comment on table public.services is 'Individual services offered by each business with pricing.';

-- Indexes
create index idx_services_business     on public.services (business_id);
create index idx_services_type_active  on public.services (service_type) where is_active = true;
create index idx_services_category     on public.services (category);

-- RLS
alter table public.services enable row level security;

create policy "Services: anyone can read active"
  on public.services for select
  using (is_active = true);

-- ---------------------------------------------------------------------------
-- 8. Table: staff_services (junction table)
-- ---------------------------------------------------------------------------
create table public.staff_services (
  id              uuid          not null default gen_random_uuid(),
  staff_id        uuid          not null references public.staff(id) on delete cascade,
  service_id      uuid          not null references public.services(id) on delete cascade,
  custom_price    numeric(10,2),
  custom_duration integer,

  constraint staff_services_pkey primary key (id),
  constraint staff_services_unique unique (staff_id, service_id)
);

comment on table public.staff_services is 'Which staff members can perform which services, with optional price/duration overrides.';

-- Indexes
create index idx_staff_services_service on public.staff_services (service_id);

-- RLS
alter table public.staff_services enable row level security;

create policy "Staff services: anyone can read"
  on public.staff_services for select
  using (true);

-- ---------------------------------------------------------------------------
-- 9. Table: staff_schedules
-- ---------------------------------------------------------------------------
create table public.staff_schedules (
  id           uuid     not null default gen_random_uuid(),
  staff_id     uuid     not null references public.staff(id) on delete cascade,
  day_of_week  smallint not null,
  start_time   time     not null,
  end_time     time     not null,
  is_available boolean  not null default true,

  constraint staff_schedules_pkey primary key (id),
  constraint staff_schedules_dow_check check (day_of_week between 0 and 6),
  constraint staff_schedules_unique unique (staff_id, day_of_week)
);

comment on table public.staff_schedules is 'Weekly schedule template per staff member. 0=Sun, 6=Sat.';

-- Indexes
create index idx_staff_schedules_lookup
  on public.staff_schedules (staff_id, day_of_week) where is_available = true;

-- RLS
alter table public.staff_schedules enable row level security;

create policy "Staff schedules: anyone can read"
  on public.staff_schedules for select
  using (true);

-- ---------------------------------------------------------------------------
-- 10. Table: appointments (replaces old "bookings")
-- ---------------------------------------------------------------------------
create table public.appointments (
  id              uuid          not null default gen_random_uuid(),
  user_id         uuid          not null references auth.users on delete cascade,
  business_id     uuid          not null references public.businesses(id) on delete cascade,
  staff_id        uuid          references public.staff(id) on delete set null,
  service_id      uuid          references public.services(id) on delete set null,
  service_name    text          not null,
  service_type    text,
  status          text          not null default 'pending',
  starts_at       timestamptz   not null,
  ends_at         timestamptz   not null,
  price           numeric(10,2),
  deposit_amount  numeric(10,2),
  transport_mode  text,
  notes           text,
  created_at      timestamptz   not null default now(),
  updated_at      timestamptz   not null default now(),

  constraint appointments_pkey primary key (id),
  constraint appointments_status_check check (
    status in ('pending', 'confirmed', 'completed',
               'cancelled_customer', 'cancelled_business', 'no_show')
  ),
  constraint appointments_transport_check check (
    transport_mode is null or transport_mode in ('car', 'uber', 'transit')
  )
);

comment on table public.appointments is 'Appointment bookings between users and businesses.';

create trigger appointments_updated_at
  before update on public.appointments
  for each row execute function public.handle_updated_at();

-- Indexes
create index idx_appointments_user_time
  on public.appointments (user_id, starts_at desc);

create index idx_appointments_staff_time
  on public.appointments (staff_id, starts_at)
  where status not in ('cancelled_customer', 'cancelled_business', 'no_show');

create index idx_appointments_status
  on public.appointments (status);

-- RLS
alter table public.appointments enable row level security;

create policy "Appointments: users can read their own"
  on public.appointments for select
  using (auth.uid() = user_id);

create policy "Appointments: users can create their own"
  on public.appointments for insert
  with check (auth.uid() = user_id);

create policy "Appointments: users can update their own"
  on public.appointments for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Appointments: users can delete their own"
  on public.appointments for delete
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 11. Table: reviews
-- ---------------------------------------------------------------------------
create table public.reviews (
  id             uuid        not null default gen_random_uuid(),
  user_id        uuid        not null references auth.users on delete cascade,
  business_id    uuid        not null references public.businesses(id) on delete cascade,
  staff_id       uuid        references public.staff(id) on delete set null,
  appointment_id uuid        references public.appointments(id) on delete set null,
  service_type   text,
  rating         integer     not null,
  comment        text,
  is_visible     boolean     not null default true,
  created_at     timestamptz not null default now(),

  constraint reviews_pkey primary key (id),
  constraint reviews_rating_range check (rating >= 1 and rating <= 5),
  constraint reviews_unique_per_appointment unique (user_id, appointment_id)
);

comment on table public.reviews is 'User reviews of beauty businesses and staff.';

-- Indexes
create index idx_reviews_business  on public.reviews (business_id);
create index idx_reviews_staff     on public.reviews (staff_id);
create index idx_reviews_service_type_recent
  on public.reviews (service_type, created_at desc) where is_visible = true;

-- RLS
alter table public.reviews enable row level security;

create policy "Reviews: anyone can read visible"
  on public.reviews for select
  using (is_visible = true);

create policy "Reviews: users can create their own"
  on public.reviews for insert
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 12. Trigger: update business rating/review_count on review changes
-- ---------------------------------------------------------------------------
create or replace function public.handle_review_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_business_id uuid;
begin
  if tg_op = 'DELETE' then
    target_business_id := old.business_id;
  else
    target_business_id := new.business_id;
  end if;

  update public.businesses
  set
    average_rating = coalesce((
      select round(avg(r.rating)::numeric, 2)
      from public.reviews r
      where r.business_id = target_business_id
        and r.is_visible = true
    ), 0),
    total_reviews = (
      select count(*)
      from public.reviews r
      where r.business_id = target_business_id
        and r.is_visible = true
    )
  where id = target_business_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger reviews_update_business_stats
  after insert or update or delete on public.reviews
  for each row execute function public.handle_review_change();

-- ---------------------------------------------------------------------------
-- 13. Table: favorites
-- ---------------------------------------------------------------------------
create table public.favorites (
  id          uuid        not null default gen_random_uuid(),
  user_id     uuid        not null references auth.users on delete cascade,
  business_id uuid        not null references public.businesses(id) on delete cascade,
  created_at  timestamptz not null default now(),

  constraint favorites_pkey primary key (id),
  constraint favorites_unique unique (user_id, business_id)
);

comment on table public.favorites is 'User favorite/saved businesses.';

-- RLS
alter table public.favorites enable row level security;

create policy "Favorites: users can read their own"
  on public.favorites for select
  using (auth.uid() = user_id);

create policy "Favorites: users can add their own"
  on public.favorites for insert
  with check (auth.uid() = user_id);

create policy "Favorites: users can remove their own"
  on public.favorites for delete
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 14. Table: payments
-- ---------------------------------------------------------------------------
create table public.payments (
  id                uuid          not null default gen_random_uuid(),
  appointment_id    uuid          not null references public.appointments(id) on delete cascade,
  user_id           uuid          not null references auth.users on delete cascade,
  amount            numeric(10,2) not null,
  currency          text          not null default 'MXN',
  payment_method    text          not null,
  stripe_payment_id text,
  status            text          not null default 'pending',
  created_at        timestamptz   not null default now(),
  updated_at        timestamptz   not null default now(),

  constraint payments_pkey primary key (id),
  constraint payments_method_check check (
    payment_method in ('card', 'oxxo', 'cash')
  ),
  constraint payments_status_check check (
    status in ('pending', 'completed', 'refunded', 'failed')
  )
);

comment on table public.payments is 'Payment records tied to appointments.';

create trigger payments_updated_at
  before update on public.payments
  for each row execute function public.handle_updated_at();

-- RLS
alter table public.payments enable row level security;

create policy "Payments: users can read their own"
  on public.payments for select
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 15. Table: notifications
-- ---------------------------------------------------------------------------
create table public.notifications (
  id         uuid        not null default gen_random_uuid(),
  user_id    uuid        not null references auth.users on delete cascade,
  title      text        not null,
  body       text        not null,
  channel    text        not null,
  is_read    boolean     not null default false,
  metadata   jsonb       not null default '{}',
  created_at timestamptz not null default now(),

  constraint notifications_pkey primary key (id),
  constraint notifications_channel_check check (
    channel in ('push', 'sms', 'whatsapp', 'email', 'in_app')
  )
);

comment on table public.notifications is 'User notification log across all channels.';

-- Indexes
create index idx_notifications_user_read on public.notifications (user_id, is_read);

-- RLS
alter table public.notifications enable row level security;

create policy "Notifications: users can read their own"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "Notifications: users can update their own"
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- =========================================================================
--  INTELLIGENCE LAYER TABLES
-- =========================================================================

-- ---------------------------------------------------------------------------
-- 16. Table: service_categories_tree — Section 3 / 13
-- ---------------------------------------------------------------------------
create table public.service_categories_tree (
  id              uuid    not null default gen_random_uuid(),
  parent_id       uuid    references public.service_categories_tree(id),
  slug            text    not null,
  display_name_es text    not null,
  display_name_en text    not null,
  icon            text,
  sort_order      integer not null default 0,
  depth           integer not null,
  is_leaf         boolean not null default false,
  service_type    text    references public.service_profiles(service_type),
  is_active       boolean not null default true,

  constraint service_categories_tree_pkey primary key (id),
  constraint service_categories_tree_slug_unique unique (slug),
  constraint service_categories_tree_depth_check check (depth between 0 and 2)
);

comment on table public.service_categories_tree is 'Hierarchical service category tree (max 3 levels). Leaf nodes link to service_profiles.';

-- RLS
alter table public.service_categories_tree enable row level security;

create policy "Category tree: anyone can read active"
  on public.service_categories_tree for select
  using (is_active = true);

-- ---------------------------------------------------------------------------
-- 17. Table: service_follow_up_questions — Section 13
-- ---------------------------------------------------------------------------
create table public.service_follow_up_questions (
  id                uuid    not null default gen_random_uuid(),
  service_type      text    not null references public.service_profiles(service_type),
  question_order    integer not null,
  question_key      text    not null,
  question_text_es  text    not null,
  question_text_en  text    not null,
  answer_type       text    not null,
  options           jsonb,
  is_required       boolean not null default true,

  constraint service_follow_up_questions_pkey primary key (id),
  constraint service_follow_up_questions_answer_type_check check (
    answer_type in ('visual_cards', 'date_picker', 'yes_no')
  )
);

comment on table public.service_follow_up_questions is 'Follow-up questions asked between service selection and results.';

-- RLS
alter table public.service_follow_up_questions enable row level security;

create policy "Follow-up questions: anyone can read"
  on public.service_follow_up_questions for select
  using (true);

-- ---------------------------------------------------------------------------
-- 18. Table: time_inference_rules — Section 5
-- ---------------------------------------------------------------------------
create table public.time_inference_rules (
  id                     uuid     not null default gen_random_uuid(),
  hour_start             smallint not null,
  hour_end               smallint not null,
  day_of_week_start      smallint not null,
  day_of_week_end        smallint not null,
  window_description     text     not null,
  window_offset_days_min integer  not null default 0,
  window_offset_days_max integer  not null default 1,
  preferred_hour_start   smallint not null default 10,
  preferred_hour_end     smallint not null default 16,
  preference_peak_hour   smallint not null default 11,
  is_active              boolean  not null default true,
  updated_at             timestamptz not null default now(),

  constraint time_inference_rules_pkey primary key (id),
  constraint time_inference_rules_hour_check check (
    hour_start between 0 and 23 and hour_end between 0 and 23
  ),
  constraint time_inference_rules_dow_check check (
    day_of_week_start between 0 and 6 and day_of_week_end between 0 and 6
  )
);

comment on table public.time_inference_rules is 'Time inference matrix: maps current time + day to booking window assumptions.';

create trigger time_inference_rules_updated_at
  before update on public.time_inference_rules
  for each row execute function public.handle_updated_at();

-- RLS
alter table public.time_inference_rules enable row level security;

create policy "Time inference rules: anyone can read active"
  on public.time_inference_rules for select
  using (is_active = true);

-- ---------------------------------------------------------------------------
-- 19. Table: time_inference_corrections — Section 5
-- ---------------------------------------------------------------------------
create table public.time_inference_corrections (
  id                 uuid          not null default gen_random_uuid(),
  service_type       text          not null,
  original_hour_range text         not null,
  original_day_range  text         not null,
  correction_to      text          not null,
  correction_count   integer       not null default 1,
  total_bookings     integer       not null default 1,
  correction_rate    numeric(3,2),
  created_at         timestamptz   not null default now(),
  updated_at         timestamptz   not null default now(),

  constraint time_inference_corrections_pkey primary key (id)
);

comment on table public.time_inference_corrections is 'Tracks user corrections to time inference for learning and admin alerts.';

create trigger time_inference_corrections_updated_at
  before update on public.time_inference_corrections
  for each row execute function public.handle_updated_at();

-- RLS
alter table public.time_inference_corrections enable row level security;

create policy "Time corrections: anyone can read"
  on public.time_inference_corrections for select
  using (true);

-- ---------------------------------------------------------------------------
-- 20. Table: user_booking_patterns — Section 5
-- ---------------------------------------------------------------------------
create table public.user_booking_patterns (
  id                   uuid        not null default gen_random_uuid(),
  user_id              uuid        not null references auth.users(id),
  service_category     text        not null,
  preferred_day_of_week smallint,
  preferred_hour       smallint,
  booking_count        integer     not null default 0,
  confidence           numeric(3,2) not null default 0.0,
  last_updated         timestamptz not null default now(),

  constraint user_booking_patterns_pkey primary key (id)
);

comment on table public.user_booking_patterns is 'Learned booking patterns per user + service category for time inference personalization.';

-- RLS
alter table public.user_booking_patterns enable row level security;

create policy "User patterns: users can read their own"
  on public.user_booking_patterns for select
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 21. Table: review_tags — Section 9
-- ---------------------------------------------------------------------------
create table public.review_tags (
  id                   uuid        not null default gen_random_uuid(),
  review_id            uuid        not null references public.reviews(id) on delete cascade,
  service_type         text,
  keywords             text[],
  sentiment_score      numeric(3,2),
  snippet_quality_score numeric(3,2),
  mentions_staff       boolean     not null default false,
  mentions_outcome     boolean     not null default false,
  word_count           integer,
  created_at           timestamptz not null default now(),

  constraint review_tags_pkey primary key (id)
);

comment on table public.review_tags is 'Pre-computed review snippet scoring for the intelligence engine.';

-- RLS
alter table public.review_tags enable row level security;

create policy "Review tags: anyone can read"
  on public.review_tags for select
  using (true);

-- ---------------------------------------------------------------------------
-- 22. Table: engine_settings — Section 10
-- ---------------------------------------------------------------------------
create table public.engine_settings (
  key            text        not null,
  value          text        not null,
  data_type      text        not null default 'number',
  min_value      numeric,
  max_value      numeric,
  description_es text,
  description_en text,
  group_name     text        not null,
  sort_order     integer     not null default 0,
  updated_at     timestamptz not null default now(),
  updated_by     uuid        references auth.users(id),

  constraint engine_settings_pkey primary key (key),
  constraint engine_settings_data_type_check check (
    data_type in ('number', 'integer', 'boolean')
  )
);

comment on table public.engine_settings is 'Global engine configuration (key-value store). Admin-editable.';

create trigger engine_settings_updated_at
  before update on public.engine_settings
  for each row execute function public.handle_updated_at();

-- RLS
alter table public.engine_settings enable row level security;

create policy "Engine settings: anyone can read"
  on public.engine_settings for select
  using (true);

-- ---------------------------------------------------------------------------
-- 23. Table: notification_templates — Section 13
-- ---------------------------------------------------------------------------
create table public.notification_templates (
  id                 uuid        not null default gen_random_uuid(),
  event_type         text        not null,
  channel            text        not null,
  recipient_type     text        not null,
  template_es        text        not null,
  template_en        text        not null,
  required_variables text[]      not null default '{}',
  is_active          boolean     not null default true,
  updated_at         timestamptz not null default now(),
  updated_by         uuid        references auth.users(id),

  constraint notification_templates_pkey primary key (id),
  constraint notification_templates_channel_check check (
    channel in ('whatsapp', 'sms', 'push', 'email', 'in_app')
  ),
  constraint notification_templates_recipient_check check (
    recipient_type in ('customer', 'salon')
  ),
  constraint notification_templates_unique unique (event_type, channel, recipient_type)
);

comment on table public.notification_templates is 'Editable notification templates per event type, channel, and recipient.';

create trigger notification_templates_updated_at
  before update on public.notification_templates
  for each row execute function public.handle_updated_at();

-- RLS
alter table public.notification_templates enable row level security;

create policy "Notification templates: anyone can read active"
  on public.notification_templates for select
  using (is_active = true);

-- ---------------------------------------------------------------------------
-- 24. Table: engine_analytics_events — Section 13
-- ---------------------------------------------------------------------------
create table public.engine_analytics_events (
  id               uuid        not null default gen_random_uuid(),
  event_type       text        not null,
  service_type     text,
  transport_mode   text,
  card_position    integer,
  response_time_ms integer,
  radius_expanded  boolean     not null default false,
  user_id          uuid,
  metadata         jsonb       not null default '{}',
  created_at       timestamptz not null default now(),

  constraint engine_analytics_events_pkey primary key (id),
  constraint engine_analytics_events_type_check check (
    event_type in ('search', 'booking', 'time_override', 'more_options',
                   'card_selected', 'radius_expanded', 'no_results')
  )
);

comment on table public.engine_analytics_events is 'Event log for the engine analytics dashboard.';

-- Indexes
create index idx_analytics_events_type_date
  on public.engine_analytics_events (event_type, created_at desc);

create index idx_analytics_events_service
  on public.engine_analytics_events (service_type, created_at desc)
  where service_type is not null;

-- RLS
alter table public.engine_analytics_events enable row level security;

create policy "Analytics events: anyone can read"
  on public.engine_analytics_events for select
  using (true);

-- ---------------------------------------------------------------------------
-- 25. Table: admin_notes — Section 13
-- ---------------------------------------------------------------------------
create table public.admin_notes (
  id          uuid        not null default gen_random_uuid(),
  target_type text        not null,
  target_id   uuid        not null,
  note        text        not null,
  created_by  uuid        not null references auth.users(id),
  created_at  timestamptz not null default now(),

  constraint admin_notes_pkey primary key (id),
  constraint admin_notes_target_type_check check (
    target_type in ('business', 'user')
  )
);

comment on table public.admin_notes is 'Admin notes on businesses and users.';

-- Indexes
create index idx_admin_notes_target on public.admin_notes (target_type, target_id);

-- RLS
alter table public.admin_notes enable row level security;

create policy "Admin notes: admins can read"
  on public.admin_notes for select
  using (
    exists (
      select 1 from public.profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    )
  );

create policy "Admin notes: admins can insert"
  on public.admin_notes for insert
  with check (
    exists (
      select 1 from public.profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    )
  );

-- ---------------------------------------------------------------------------
-- 26. Table: user_transport_preferences — Section 13
-- ---------------------------------------------------------------------------
create table public.user_transport_preferences (
  user_id              uuid             not null references auth.users(id),
  last_transport_mode  text             not null default 'car',
  uber_linked          boolean          not null default false,
  home_address_lat     double precision,
  home_address_lng     double precision,
  home_address_text    text,
  updated_at           timestamptz      not null default now(),

  constraint user_transport_preferences_pkey primary key (user_id),
  constraint user_transport_preferences_mode_check check (
    last_transport_mode in ('car', 'uber', 'transit')
  )
);

comment on table public.user_transport_preferences is 'Last used transport mode and home address for Uber pre-selection.';

create trigger user_transport_preferences_updated_at
  before update on public.user_transport_preferences
  for each row execute function public.handle_updated_at();

-- RLS
alter table public.user_transport_preferences enable row level security;

create policy "Transport prefs: users can read their own"
  on public.user_transport_preferences for select
  using (auth.uid() = user_id);

create policy "Transport prefs: users can insert their own"
  on public.user_transport_preferences for insert
  with check (auth.uid() = user_id);

create policy "Transport prefs: users can update their own"
  on public.user_transport_preferences for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 27. Table: uber_scheduled_rides — Section 13
-- ---------------------------------------------------------------------------
create table public.uber_scheduled_rides (
  id                   uuid             not null default gen_random_uuid(),
  appointment_id       uuid             not null references public.appointments(id) on delete cascade,
  user_id              uuid             not null references auth.users(id),
  leg                  text             not null,
  uber_request_id      text,
  pickup_lat           double precision not null,
  pickup_lng           double precision not null,
  pickup_address       text,
  dropoff_lat          double precision not null,
  dropoff_lng          double precision not null,
  dropoff_address      text,
  scheduled_pickup_at  timestamptz      not null,
  estimated_fare_min   numeric(10,2),
  estimated_fare_max   numeric(10,2),
  currency             text             not null default 'MXN',
  status               text             not null default 'scheduled',
  created_at           timestamptz      not null default now(),
  updated_at           timestamptz      not null default now(),

  constraint uber_scheduled_rides_pkey primary key (id),
  constraint uber_scheduled_rides_leg_check check (
    leg in ('outbound', 'return')
  ),
  constraint uber_scheduled_rides_status_check check (
    status in ('scheduled', 'requested', 'accepted', 'arriving',
               'in_progress', 'completed', 'cancelled')
  )
);

comment on table public.uber_scheduled_rides is 'Uber ride bookings (outbound and return) tied to appointments.';

create trigger uber_scheduled_rides_updated_at
  before update on public.uber_scheduled_rides
  for each row execute function public.handle_updated_at();

-- RLS
alter table public.uber_scheduled_rides enable row level security;

create policy "Uber rides: users can read their own"
  on public.uber_scheduled_rides for select
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 28. Table: discovered_salons — Section 12
-- ---------------------------------------------------------------------------
create table public.discovered_salons (
  id                    uuid             not null default gen_random_uuid(),

  -- Source identification
  source                text             not null,
  source_id             text,

  -- Business data
  name                  text             not null,
  phone                 text,
  whatsapp              text,
  address               text,
  city                  text             not null,
  state                 text             not null,
  country               text             not null default 'MX',
  lat                   double precision,
  lng                   double precision,
  location              geography(Point, 4326),
  photo_url             text,
  rating                numeric(2,1),
  reviews_count         integer,
  business_category     text,
  service_categories    text[],
  hours                 text,
  website               text,
  facebook_url          text,
  instagram_handle      text,

  -- Deduplication
  dedup_key             text generated always as (
    coalesce(phone, '') || ':' ||
    round(coalesce(lat, 0)::numeric, 3)::text || ',' ||
    round(coalesce(lng, 0)::numeric, 3)::text
  ) stored,

  -- Outreach tracking
  interest_count        integer          not null default 0,
  first_selected_at     timestamptz,
  last_selected_at      timestamptz,
  last_outreach_at      timestamptz,
  outreach_count        integer          not null default 0,
  outreach_channel      text,

  -- Status
  status                text             not null default 'discovered',
  registered_business_id uuid           references public.businesses(id),
  registered_at         timestamptz,

  scraped_at            timestamptz      not null,
  created_at            timestamptz      not null default now(),
  updated_at            timestamptz      not null default now(),

  constraint discovered_salons_pkey primary key (id),
  constraint discovered_salons_source_check check (
    source in ('google_maps', 'facebook', 'bing', 'foursquare',
               'seccion_amarilla', 'manual')
  ),
  constraint discovered_salons_source_unique unique (source, source_id),
  constraint discovered_salons_status_check check (
    status in ('discovered', 'selected', 'outreach_sent',
               'registered', 'declined', 'unreachable')
  )
);

comment on table public.discovered_salons is 'Scraped business listings from Google Maps, Facebook, Bing, etc. for the salon acquisition pipeline.';

create trigger discovered_salons_updated_at
  before update on public.discovered_salons
  for each row execute function public.handle_updated_at();

-- Auto-populate location from lat/lng (reuse same logic as businesses)
create trigger discovered_salons_set_location
  before insert or update of lat, lng on public.discovered_salons
  for each row
  execute function public.handle_business_location();

-- Indexes
create index idx_discovered_salons_location
  on public.discovered_salons using gist (location);

create index idx_discovered_salons_dedup
  on public.discovered_salons (dedup_key);

create index idx_discovered_salons_city_status
  on public.discovered_salons (city, status);

create index idx_discovered_salons_interest
  on public.discovered_salons (interest_count desc)
  where status = 'selected' or status = 'outreach_sent';

-- RLS
alter table public.discovered_salons enable row level security;

create policy "Discovered salons: anyone can read"
  on public.discovered_salons for select
  using (true);

-- ---------------------------------------------------------------------------
-- 29. Table: salon_interest_signals — Section 12
-- ---------------------------------------------------------------------------
create table public.salon_interest_signals (
  id                  uuid        not null default gen_random_uuid(),
  discovered_salon_id uuid        not null references public.discovered_salons(id),
  user_id             uuid        not null references auth.users(id),
  created_at          timestamptz not null default now(),

  constraint salon_interest_signals_pkey primary key (id),
  constraint salon_interest_signals_unique unique (discovered_salon_id, user_id)
);

comment on table public.salon_interest_signals is 'Tracks which users selected which discovered salons for invitation (unique per user+salon).';

-- RLS
alter table public.salon_interest_signals enable row level security;

create policy "Salon signals: users can read their own"
  on public.salon_interest_signals for select
  using (auth.uid() = user_id);

create policy "Salon signals: users can insert their own"
  on public.salon_interest_signals for insert
  with check (auth.uid() = user_id);

-- =========================================================================
--  RPC FUNCTIONS
-- =========================================================================

-- ---------------------------------------------------------------------------
-- 30. Function: nearby_businesses (proximity search)
-- ---------------------------------------------------------------------------
create or replace function public.nearby_businesses(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision default 10.0,
  p_category text default null,
  p_limit integer default 50
)
returns table (
  id                 uuid,
  name               text,
  phone              text,
  whatsapp           text,
  address            text,
  city               text,
  lat                double precision,
  lng                double precision,
  photo_url          text,
  average_rating     numeric(3,2),
  total_reviews      integer,
  business_category  text,
  service_categories text[],
  hours              jsonb,
  is_verified        boolean,
  tier               integer,
  accept_walkins     boolean,
  distance_km        double precision
)
language sql
stable
security definer
set search_path = public
as $$
  select
    b.id,
    b.name,
    b.phone,
    b.whatsapp,
    b.address,
    b.city,
    b.lat,
    b.lng,
    b.photo_url,
    b.average_rating,
    b.total_reviews,
    b.business_category,
    b.service_categories,
    b.hours,
    b.is_verified,
    b.tier,
    b.accept_walkins,
    round((st_distance(
      b.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    ) / 1000.0)::numeric, 2)::double precision as distance_km
  from public.businesses b
  where
    b.is_active = true
    and b.location is not null
    and st_dwithin(
      b.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      p_radius_km * 1000
    )
    and (p_category is null or p_category = any(b.service_categories))
  order by distance_km asc
  limit p_limit;
$$;

comment on function public.nearby_businesses is 'Returns active businesses within a radius (km) of a given point, optionally filtered by service category.';

-- ---------------------------------------------------------------------------
-- 31. Function: search_businesses (text + category + city)
-- ---------------------------------------------------------------------------
create or replace function public.search_businesses(
  p_query text default null,
  p_category text default null,
  p_city text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id                 uuid,
  name               text,
  phone              text,
  whatsapp           text,
  address            text,
  city               text,
  lat                double precision,
  lng                double precision,
  photo_url          text,
  average_rating     numeric(3,2),
  total_reviews      integer,
  business_category  text,
  service_categories text[],
  hours              jsonb,
  is_verified        boolean,
  tier               integer,
  accept_walkins     boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    b.id,
    b.name,
    b.phone,
    b.whatsapp,
    b.address,
    b.city,
    b.lat,
    b.lng,
    b.photo_url,
    b.average_rating,
    b.total_reviews,
    b.business_category,
    b.service_categories,
    b.hours,
    b.is_verified,
    b.tier,
    b.accept_walkins
  from public.businesses b
  where
    b.is_active = true
    and (p_query is null or b.name ilike '%' || p_query || '%')
    and (p_category is null or p_category = any(b.service_categories))
    and (p_city is null or b.city ilike p_city)
  order by b.average_rating desc nulls last, b.total_reviews desc
  limit p_limit
  offset p_offset;
$$;

comment on function public.search_businesses is 'Search businesses by name, category, and city with pagination.';

-- ---------------------------------------------------------------------------
-- 32. Function: find_available_slots — Section 6
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
begin
  -- Iterate over each date in the window
  v_date := p_window_start::date;
  while v_date <= p_window_end::date loop
    v_dow := extract(dow from v_date)::smallint;

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

        -- Check for overlapping appointments
        if not exists (
          select 1
          from public.appointments a
          where a.staff_id = p_staff_id
            and a.status not in ('cancelled_customer', 'cancelled_business', 'no_show')
            and a.starts_at < v_slot_end
            and a.ends_at > v_slot_start
        ) then
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

comment on function public.find_available_slots is 'Generates available appointment slots for a staff member within a time window, subtracting existing appointments.';

-- =========================================================================
--  Done.
-- =========================================================================
