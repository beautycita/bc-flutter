-- =============================================================================
-- Migration: 20260307000000_portfolio_system.sql
-- Description: Portfolio system for businesses and staff — public photo
--              galleries, before/after uploads, slug-based public URLs,
--              and agreement tracking.
-- Tables affected: businesses (columns), staff (columns)
-- New tables: portfolio_photos, portfolio_agreements
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Add portfolio columns to businesses
-- ---------------------------------------------------------------------------
alter table public.businesses
  add column if not exists portfolio_slug     text unique,
  add column if not exists portfolio_public   boolean not null default false,
  add column if not exists portfolio_theme    text    not null default 'portfolio',
  add column if not exists portfolio_bio      text,
  add column if not exists portfolio_tagline  text;

comment on column public.businesses.portfolio_slug    is 'URL-friendly unique identifier for public portfolio page (auto-generated from name)';
comment on column public.businesses.portfolio_public  is 'When true, portfolio is publicly visible without authentication';
comment on column public.businesses.portfolio_theme   is 'Visual theme key for the portfolio page renderer';
comment on column public.businesses.portfolio_bio     is 'Extended business biography shown on portfolio page';
comment on column public.businesses.portfolio_tagline is 'Short tagline shown under business name on portfolio';

-- ---------------------------------------------------------------------------
-- 2. Slug generation function
--    Rules:
--      - Lowercase entire string
--      - Replace any run of whitespace with a single hyphen
--      - Strip any character that is not alphanumeric or hyphen
--      - Collapse multiple consecutive hyphens into one
--      - Trim leading/trailing hyphens
--      - If the resulting slug already exists, append a random 4-char hex suffix
--      - Only runs when portfolio_slug IS NULL or empty string on the row
-- ---------------------------------------------------------------------------
create or replace function public.generate_portfolio_slug()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_base    text;
  v_slug    text;
  v_suffix  text;
  v_exists  boolean;
begin
  -- Only generate when slug is absent (INSERT with no slug, or UPDATE that
  -- clears the slug). Skip entirely if a non-empty slug is already set.
  if new.portfolio_slug is not null and new.portfolio_slug <> '' then
    return new;
  end if;

  -- Build base slug from business name
  v_base := lower(new.name);
  -- Collapse whitespace to hyphens
  v_base := regexp_replace(v_base, '\s+', '-', 'g');
  -- Remove anything that is not alphanumeric or hyphen
  v_base := regexp_replace(v_base, '[^a-z0-9\-]', '', 'g');
  -- Collapse repeated hyphens
  v_base := regexp_replace(v_base, '-{2,}', '-', 'g');
  -- Strip leading/trailing hyphens
  v_base := trim(both '-' from v_base);

  -- Fall back to a random slug if name produces an empty string
  if v_base = '' then
    v_base := 'salon';
  end if;

  v_slug := v_base;

  -- Check uniqueness; append suffix when colliding
  select exists(
    select 1 from public.businesses
    where portfolio_slug = v_slug
      and id <> new.id   -- exclude self on UPDATE
  ) into v_exists;

  if v_exists then
    -- 4-char hex suffix from a random uuid segment
    v_suffix := left(replace(gen_random_uuid()::text, '-', ''), 4);
    v_slug   := v_base || '-' || v_suffix;

    -- Second collision is astronomically unlikely but guard anyway
    select exists(
      select 1 from public.businesses
      where portfolio_slug = v_slug
        and id <> new.id
    ) into v_exists;

    if v_exists then
      v_suffix := left(replace(gen_random_uuid()::text, '-', ''), 8);
      v_slug   := v_base || '-' || v_suffix;
    end if;
  end if;

  new.portfolio_slug := v_slug;
  return new;
end;
$$;

comment on function public.generate_portfolio_slug() is
  'BEFORE trigger: auto-generates portfolio_slug from business name when slug is absent. Handles uniqueness by appending a random hex suffix on collision.';

-- Attach trigger — fires on INSERT always, and on UPDATE only when name or
-- slug changes (avoids unnecessary re-runs on unrelated column updates).
drop trigger if exists businesses_generate_portfolio_slug on public.businesses;
create trigger businesses_generate_portfolio_slug
  before insert or update of name, portfolio_slug
  on public.businesses
  for each row
  execute function public.generate_portfolio_slug();

-- ---------------------------------------------------------------------------
-- 3. Add portfolio columns to staff
-- ---------------------------------------------------------------------------
alter table public.staff
  add column if not exists bio         text,
  add column if not exists specialties text[];

comment on column public.staff.bio         is 'Staff member biography shown on portfolio and booking cards';
comment on column public.staff.specialties is 'Array of specialty tags (e.g. {''balayage'', ''keratin'', ''updos''})';

-- ---------------------------------------------------------------------------
-- 4. portfolio_photos table
-- ---------------------------------------------------------------------------
create table if not exists public.portfolio_photos (
  id               uuid        not null default gen_random_uuid(),
  business_id      uuid        not null references public.businesses(id) on delete cascade,
  staff_id         uuid                 references public.staff(id)      on delete set null,
  before_url       text,                              -- null = after-only entry
  after_url        text        not null,
  photo_type       text        not null default 'after_only',
  service_category text,
  caption          text,
  product_tags     jsonb,
  sort_order       integer     not null default 0,
  is_visible       boolean     not null default true,
  created_at       timestamptz not null default now(),

  constraint portfolio_photos_pkey primary key (id),
  constraint portfolio_photos_photo_type_check
    check (photo_type in ('before_after', 'after_only'))
);

comment on table  public.portfolio_photos                  is 'Before/after and portfolio photos uploaded by business owners or attributed staff';
comment on column public.portfolio_photos.business_id      is 'Owning business; cascade-deleted when business is removed';
comment on column public.portfolio_photos.staff_id         is 'Optional staff attribution; nulled when staff is removed';
comment on column public.portfolio_photos.before_url       is 'Storage URL for before photo. NULL when photo_type = after_only';
comment on column public.portfolio_photos.after_url        is 'Storage URL for the final/after photo. Always required';
comment on column public.portfolio_photos.photo_type       is 'before_after: paired images; after_only: single result image';
comment on column public.portfolio_photos.service_category is 'Service category tag for filtering (e.g. ''hair'', ''nails'', ''lashes'')';
comment on column public.portfolio_photos.product_tags     is 'JSON array of product references used in this service';
comment on column public.portfolio_photos.sort_order       is 'Display order within business portfolio (ascending)';
comment on column public.portfolio_photos.is_visible       is 'Soft-hide without deleting; excluded from public reads when false';

-- Indexes
create index if not exists idx_portfolio_photos_business_id
  on public.portfolio_photos (business_id);

create index if not exists idx_portfolio_photos_staff_id
  on public.portfolio_photos (staff_id)
  where staff_id is not null;

-- Partial index for the hot path: public gallery queries filter on both columns
create index if not exists idx_portfolio_photos_business_visible
  on public.portfolio_photos (business_id, sort_order)
  where is_visible = true;

-- ---------------------------------------------------------------------------
-- 5. RLS for portfolio_photos
-- ---------------------------------------------------------------------------
alter table public.portfolio_photos enable row level security;

-- Public: anyone can read visible photos belonging to a public portfolio
create policy "Portfolio photos: public can view visible photos on public portfolios"
  on public.portfolio_photos for select
  using (
    is_visible = true
    and exists (
      select 1 from public.businesses
      where id            = portfolio_photos.business_id
        and portfolio_public = true
    )
  );

-- Owner: full control over their own business photos
create policy "Portfolio photos: owner can select own"
  on public.portfolio_photos for select
  to authenticated
  using (
    exists (
      select 1 from public.businesses
      where id       = portfolio_photos.business_id
        and owner_id = auth.uid()
    )
  );

create policy "Portfolio photos: owner can insert"
  on public.portfolio_photos for insert
  to authenticated
  with check (
    exists (
      select 1 from public.businesses
      where id       = portfolio_photos.business_id
        and owner_id = auth.uid()
    )
  );

create policy "Portfolio photos: owner can update"
  on public.portfolio_photos for update
  to authenticated
  using (
    exists (
      select 1 from public.businesses
      where id       = portfolio_photos.business_id
        and owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.businesses
      where id       = portfolio_photos.business_id
        and owner_id = auth.uid()
    )
  );

create policy "Portfolio photos: owner can delete"
  on public.portfolio_photos for delete
  to authenticated
  using (
    exists (
      select 1 from public.businesses
      where id       = portfolio_photos.business_id
        and owner_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 6. portfolio_agreements table
-- ---------------------------------------------------------------------------
create table if not exists public.portfolio_agreements (
  id                uuid        not null default gen_random_uuid(),
  business_id       uuid        not null references public.businesses(id) on delete cascade,
  agreement_type    text        not null,
  agreement_version text        not null,
  accepted_at       timestamptz not null default now(),

  constraint portfolio_agreements_pkey primary key (id),
  constraint portfolio_agreements_unique_version
    unique (business_id, agreement_type, agreement_version)
);

comment on table  public.portfolio_agreements                    is 'Records of legal agreements accepted by business owners for the portfolio feature';
comment on column public.portfolio_agreements.agreement_type    is 'Agreement identifier (e.g. ''model_release'', ''terms_of_use'')';
comment on column public.portfolio_agreements.agreement_version is 'Version string of the agreement document accepted';
comment on column public.portfolio_agreements.accepted_at       is 'Timestamp when the business owner accepted this agreement version';

-- Index for lookups by business
create index if not exists idx_portfolio_agreements_business_id
  on public.portfolio_agreements (business_id);

-- ---------------------------------------------------------------------------
-- 7. RLS for portfolio_agreements
-- ---------------------------------------------------------------------------
alter table public.portfolio_agreements enable row level security;

create policy "Portfolio agreements: owner can select own"
  on public.portfolio_agreements for select
  to authenticated
  using (
    exists (
      select 1 from public.businesses
      where id       = portfolio_agreements.business_id
        and owner_id = auth.uid()
    )
  );

create policy "Portfolio agreements: owner can insert"
  on public.portfolio_agreements for insert
  to authenticated
  with check (
    exists (
      select 1 from public.businesses
      where id       = portfolio_agreements.business_id
        and owner_id = auth.uid()
    )
  );

create policy "Portfolio agreements: owner can delete"
  on public.portfolio_agreements for delete
  to authenticated
  using (
    exists (
      select 1 from public.businesses
      where id       = portfolio_agreements.business_id
        and owner_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 8. Backfill: generate slugs for all existing businesses that have none
--    Runs the same normalization logic as the trigger, inline.
--    Each row gets its own derived slug; duplicates get a random suffix.
-- ---------------------------------------------------------------------------
do $$
declare
  rec     record;
  v_base  text;
  v_slug  text;
  v_suffix text;
  v_exists boolean;
begin
  for rec in
    select id, name
    from public.businesses
    where portfolio_slug is null or portfolio_slug = ''
    order by created_at
  loop
    -- Normalize name to slug
    v_base := lower(rec.name);
    v_base := regexp_replace(v_base, '\s+', '-', 'g');
    v_base := regexp_replace(v_base, '[^a-z0-9\-]', '', 'g');
    v_base := regexp_replace(v_base, '-{2,}', '-', 'g');
    v_base := trim(both '-' from v_base);

    if v_base = '' then
      v_base := 'salon';
    end if;

    v_slug := v_base;

    select exists(
      select 1 from public.businesses
      where portfolio_slug = v_slug
        and id <> rec.id
    ) into v_exists;

    if v_exists then
      v_suffix := left(replace(gen_random_uuid()::text, '-', ''), 4);
      v_slug   := v_base || '-' || v_suffix;

      select exists(
        select 1 from public.businesses
        where portfolio_slug = v_slug
          and id <> rec.id
      ) into v_exists;

      if v_exists then
        v_suffix := left(replace(gen_random_uuid()::text, '-', ''), 8);
        v_slug   := v_base || '-' || v_suffix;
      end if;
    end if;

    update public.businesses
    set portfolio_slug = v_slug
    where id = rec.id;
  end loop;
end;
$$;
