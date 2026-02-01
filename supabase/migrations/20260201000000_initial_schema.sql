-- =============================================================================
-- BeautyCita Initial Schema
-- Migration: 20260201000000_initial_schema.sql
-- Description: Complete database schema for the BeautyCita beauty booking app
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

-- ---------------------------------------------------------------------------
-- 3. Table: profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id         uuid        not null references auth.users on delete cascade,
  username   text        not null,
  full_name  text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_pkey primary key (id),
  constraint profiles_username_unique unique (username),
  constraint profiles_username_length check (char_length(username) >= 3)
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
-- 4. Table: providers
-- ---------------------------------------------------------------------------
create table public.providers (
  id                 uuid             not null default uuid_generate_v4(),
  name               text             not null,
  phone              text,
  whatsapp           text,
  address            text,
  city               text             not null default 'Guadalajara',
  state              text             not null default 'Jalisco',
  country            text             not null default 'MX',
  lat                double precision,
  lng                double precision,
  location           geography(Point, 4326),
  photo_url          text,
  rating             numeric(2,1)     default 0.0,
  reviews_count      integer          not null default 0,
  business_category  text,
  service_categories text[],
  hours              jsonb,
  website            text,
  facebook_url       text,
  instagram_handle   text,
  is_verified        boolean          not null default false,
  is_active          boolean          not null default true,
  created_at         timestamptz      not null default now(),
  updated_at         timestamptz      not null default now(),

  constraint providers_pkey primary key (id),
  constraint providers_rating_range check (rating >= 0 and rating <= 5),
  constraint providers_country_check check (country in ('MX', 'US'))
);

comment on table public.providers is 'Beauty service providers (salons, spas, barber shops, etc.).';

create trigger providers_updated_at
  before update on public.providers
  for each row execute function public.handle_updated_at();

-- Auto-populate the PostGIS location column from lat/lng
create or replace function public.handle_provider_location()
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

create trigger providers_set_location
  before insert or update of lat, lng on public.providers
  for each row execute function public.handle_provider_location();

-- Indexes
create index providers_location_gist      on public.providers using gist (location);
create index providers_service_cats_gin   on public.providers using gin  (service_categories);
create index providers_city_idx           on public.providers (city);
create index providers_is_active_idx      on public.providers (is_active) where is_active = true;
create index providers_rating_idx         on public.providers (rating desc nulls last);

-- RLS
alter table public.providers enable row level security;

create policy "Providers: anyone can read active"
  on public.providers for select
  using (is_active = true);

-- Insert/update/delete restricted to service_role (backend/edge functions only).
-- No explicit policies for insert/update/delete means they are denied for
-- anon and authenticated roles, which is the desired behavior.

-- ---------------------------------------------------------------------------
-- 5. Table: provider_services
-- ---------------------------------------------------------------------------
create table public.provider_services (
  id               uuid          not null default uuid_generate_v4(),
  provider_id      uuid          not null references public.providers on delete cascade,
  category         text          not null,
  subcategory      text          not null,
  service_name     text          not null,
  price_min        numeric(10,2),
  price_max        numeric(10,2),
  duration_minutes integer       not null default 60,
  is_active        boolean       not null default true,
  created_at       timestamptz   not null default now(),

  constraint provider_services_pkey primary key (id),
  constraint provider_services_price_check check (
    price_min is null or price_max is null or price_min <= price_max
  ),
  constraint provider_services_duration_check check (duration_minutes > 0)
);

comment on table public.provider_services is 'Individual services offered by each provider with pricing.';

-- Indexes
create index provider_services_provider_idx  on public.provider_services (provider_id);
create index provider_services_category_idx  on public.provider_services (category);

-- RLS
alter table public.provider_services enable row level security;

create policy "Provider services: anyone can read active"
  on public.provider_services for select
  using (is_active = true);

-- ---------------------------------------------------------------------------
-- 6. Table: bookings
-- ---------------------------------------------------------------------------
create table public.bookings (
  id                  uuid          not null default uuid_generate_v4(),
  user_id             uuid          not null references auth.users on delete cascade,
  provider_id         uuid          not null references public.providers on delete cascade,
  provider_service_id uuid          references public.provider_services on delete set null,
  service_name        text          not null,
  category            text          not null,
  status              text          not null default 'pending',
  scheduled_at        timestamptz   not null,
  duration_minutes    integer       not null default 60,
  price               numeric(10,2),
  notes               text,
  created_at          timestamptz   not null default now(),
  updated_at          timestamptz   not null default now(),

  constraint bookings_pkey primary key (id),
  constraint bookings_status_check check (
    status in ('pending', 'confirmed', 'completed', 'cancelled', 'no_show')
  ),
  constraint bookings_duration_check check (duration_minutes > 0),
  constraint bookings_scheduled_future check (scheduled_at > created_at - interval '1 minute')
);

comment on table public.bookings is 'Appointment bookings between users and providers.';

create trigger bookings_updated_at
  before update on public.bookings
  for each row execute function public.handle_updated_at();

-- Indexes
create index bookings_user_scheduled_idx    on public.bookings (user_id, scheduled_at desc);
create index bookings_provider_scheduled_idx on public.bookings (provider_id, scheduled_at);
create index bookings_status_idx            on public.bookings (status) where status in ('pending', 'confirmed');

-- RLS
alter table public.bookings enable row level security;

create policy "Bookings: users can read their own"
  on public.bookings for select
  using (auth.uid() = user_id);

create policy "Bookings: users can create their own"
  on public.bookings for insert
  with check (auth.uid() = user_id);

create policy "Bookings: users can update their own"
  on public.bookings for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 7. Table: reviews
-- ---------------------------------------------------------------------------
create table public.reviews (
  id          uuid        not null default uuid_generate_v4(),
  user_id     uuid        not null references auth.users on delete cascade,
  provider_id uuid        not null references public.providers on delete cascade,
  booking_id  uuid        references public.bookings on delete set null,
  rating      integer     not null,
  comment     text,
  created_at  timestamptz not null default now(),

  constraint reviews_pkey primary key (id),
  constraint reviews_rating_range check (rating >= 1 and rating <= 5),
  constraint reviews_unique_per_booking unique (user_id, provider_id, booking_id)
);

comment on table public.reviews is 'User reviews of beauty providers.';

-- Indexes
create index reviews_provider_idx on public.reviews (provider_id);
create index reviews_user_idx     on public.reviews (user_id);

-- RLS
alter table public.reviews enable row level security;

create policy "Reviews: anyone can read"
  on public.reviews for select
  using (true);

create policy "Reviews: users can create their own"
  on public.reviews for insert
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 8. Trigger: update provider rating/review_count on review changes
-- ---------------------------------------------------------------------------
create or replace function public.handle_review_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_provider_id uuid;
begin
  -- Determine which provider to update
  if tg_op = 'DELETE' then
    target_provider_id := old.provider_id;
  else
    target_provider_id := new.provider_id;
  end if;

  -- Recalculate rating and count
  update public.providers
  set
    rating = coalesce((
      select round(avg(r.rating)::numeric, 1)
      from public.reviews r
      where r.provider_id = target_provider_id
    ), 0),
    reviews_count = (
      select count(*)
      from public.reviews r
      where r.provider_id = target_provider_id
    )
  where id = target_provider_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger reviews_update_provider_stats
  after insert or update or delete on public.reviews
  for each row execute function public.handle_review_change();

-- ---------------------------------------------------------------------------
-- 9. Function: nearby_providers (proximity search)
-- ---------------------------------------------------------------------------
create or replace function public.nearby_providers(
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
  address            text,
  city               text,
  lat                double precision,
  lng                double precision,
  photo_url          text,
  rating             numeric(2,1),
  reviews_count      integer,
  business_category  text,
  service_categories text[],
  hours              jsonb,
  is_verified        boolean,
  distance_km        double precision
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.name,
    p.phone,
    p.address,
    p.city,
    p.lat,
    p.lng,
    p.photo_url,
    p.rating,
    p.reviews_count,
    p.business_category,
    p.service_categories,
    p.hours,
    p.is_verified,
    round((st_distance(
      p.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    ) / 1000.0)::numeric, 2)::double precision as distance_km
  from public.providers p
  where
    p.is_active = true
    and p.location is not null
    and st_dwithin(
      p.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      p_radius_km * 1000  -- convert km to meters
    )
    and (p_category is null or p_category = any(p.service_categories))
  order by distance_km asc
  limit p_limit;
$$;

comment on function public.nearby_providers is 'Returns active providers within a radius (km) of a given point, optionally filtered by service category.';

-- ---------------------------------------------------------------------------
-- 10. Function: search_providers (text + category + location)
-- ---------------------------------------------------------------------------
create or replace function public.search_providers(
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
  address            text,
  city               text,
  lat                double precision,
  lng                double precision,
  photo_url          text,
  rating             numeric(2,1),
  reviews_count      integer,
  business_category  text,
  service_categories text[],
  hours              jsonb,
  is_verified        boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.name,
    p.phone,
    p.address,
    p.city,
    p.lat,
    p.lng,
    p.photo_url,
    p.rating,
    p.reviews_count,
    p.business_category,
    p.service_categories,
    p.hours,
    p.is_verified
  from public.providers p
  where
    p.is_active = true
    and (p_query is null or p.name ilike '%' || p_query || '%')
    and (p_category is null or p_category = any(p.service_categories))
    and (p_city is null or p.city ilike p_city)
  order by p.rating desc nulls last, p.reviews_count desc
  limit p_limit
  offset p_offset;
$$;

comment on function public.search_providers is 'Search providers by name, category, and city with pagination.';

-- ---------------------------------------------------------------------------
-- 11. Favorites table (nice-to-have for the app)
-- ---------------------------------------------------------------------------
create table public.favorites (
  id          uuid        not null default uuid_generate_v4(),
  user_id     uuid        not null references auth.users on delete cascade,
  provider_id uuid        not null references public.providers on delete cascade,
  created_at  timestamptz not null default now(),

  constraint favorites_pkey primary key (id),
  constraint favorites_unique unique (user_id, provider_id)
);

comment on table public.favorites is 'User favorite/saved providers.';

create index favorites_user_idx on public.favorites (user_id);

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
-- Done.
-- ---------------------------------------------------------------------------
