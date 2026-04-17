-- Service modifier tags (60056). Scope: 4 modifiers behind feature toggle.
-- Skipped: mobile_service (booking-flow variant, separate build),
--          pet_grooming (Phase 2).
--
-- Modifiers shipped here:
--   kids_friendly          — salon caters to children (stations, products, patience)
--   accessibility_equipped — wheelchair-accessible, ramp, ground floor, etc.
--   senior_friendly        — experience with elderly clients
--   event_specialist       — weddings/quinceañeras/photoshoots packages
--
-- Everything dormant until enable_service_modifiers toggle flips on.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Feature toggle (default OFF).
-- ─────────────────────────────────────────────────────────────────────────────

insert into public.app_config (key, value, data_type, group_name, description_es)
values (
  'enable_service_modifiers', 'false', 'bool', 'features',
  'Modificadores de servicio: kids_friendly, accessibility, senior, event_specialist. Cuando se activa: filtros, preferencias de usuario, y insignias en tarjetas.'
)
on conflict (key) do nothing;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Salon modifier tags.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.businesses
  add column if not exists service_tags text[] not null default '{}';

-- Enforce allowed values via trigger (array-typed CHECK is clunky).
create or replace function public.validate_business_service_tags()
returns trigger language plpgsql as $$
declare
  v_tag text;
  v_allowed text[] := array[
    'kids_friendly',
    'accessibility_equipped',
    'senior_friendly',
    'event_specialist'
  ];
begin
  if new.service_tags is null then
    new.service_tags := '{}';
    return new;
  end if;

  foreach v_tag in array new.service_tags loop
    if not (v_tag = any(v_allowed)) then
      raise exception 'INVALID_SERVICE_TAG: %, allowed: %', v_tag, v_allowed
        using errcode = '23514';
    end if;
  end loop;

  -- Dedup while preserving first-seen order.
  new.service_tags := (
    select array_agg(distinct t order by t)
    from unnest(new.service_tags) t
  );

  return new;
end $$;

drop trigger if exists businesses_validate_service_tags on public.businesses;
create trigger businesses_validate_service_tags
  before insert or update of service_tags on public.businesses
  for each row execute procedure public.validate_business_service_tags();

create index if not exists businesses_service_tags_gin_idx
  on public.businesses using gin (service_tags);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Per-service tags (a salon may offer event packages only on certain services).
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.services
  add column if not exists tags text[] not null default '{}';

create index if not exists services_tags_gin_idx
  on public.services using gin (tags);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. User preferences for modifier-aware search.
--    Stored as jsonb so we can add preference keys without schema churn.
--    Shape:
--      {
--        "kids_friendly": true,
--        "accessibility_required": false,
--        "senior_friendly_override": null   -- null = auto-derive from birthday
--      }
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.profiles
  add column if not exists service_preferences jsonb not null default '{}'::jsonb;

-- GIN index so curate-results can query the jsonb cheaply.
create index if not exists profiles_service_preferences_gin_idx
  on public.profiles using gin (service_preferences);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Helper: compute effective senior preference from profile birthday.
--    Returns true when user is >= 65 OR they explicitly set senior_friendly_override=true.
--    Returns false when override is explicitly false.
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.effective_senior_preference(p_user_id uuid)
returns boolean
language sql
stable
as $$
  select case
    when (prefs ->> 'senior_friendly_override') = 'true'  then true
    when (prefs ->> 'senior_friendly_override') = 'false' then false
    when birthday is not null and
         age(birthday) >= interval '65 years'             then true
    else false
  end
  from (
    select service_preferences as prefs, birthday
    from public.profiles
    where id = p_user_id
  ) p;
$$;

grant execute on function public.effective_senior_preference(uuid) to authenticated, service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. RLS: users can read their own service_preferences (already covered by
--    existing profiles policy). No new policies needed.
-- ─────────────────────────────────────────────────────────────────────────────

comment on column public.businesses.service_tags is
  'Modifier tags: kids_friendly, accessibility_equipped, senior_friendly, event_specialist. Read by curate-results when enable_service_modifiers is on.';
comment on column public.profiles.service_preferences is
  'User search preferences jsonb. Keys: kids_friendly, accessibility_required, senior_friendly_override (null = auto from birthday). Dormant until enable_service_modifiers is on.';
