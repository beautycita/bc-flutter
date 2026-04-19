-- ─────────────────────────────────────────────────────────────────────────────
-- Fix validate_business_service_tags trigger: empty array dedup returned NULL
-- ─────────────────────────────────────────────────────────────────────────────
-- The original trigger in 20260418000001_service_modifiers.sql had a latent
-- bug: when new.service_tags = '{}' (the column default), the foreach loop
-- was correctly skipped, but then the dedup
--
--     select array_agg(distinct t order by t) from unnest(new.service_tags) t
--
-- runs array_agg over zero rows, which returns NULL — not '{}'. That NULL
-- then hit the NOT NULL column constraint and every INSERT into businesses
-- that didn't explicitly pass service_tags (i.e. register-business edge fn,
-- which relies on the column default) blew up with:
--
--   null value in column "service_tags" of relation "businesses"
--   violates not-null constraint
--
-- Caught by bughunter's business-registration flow on 2026-04-19. Without
-- the hunter catch this would have silently blocked new salon onboarding.
--
-- Fix: coalesce the dedup result so empty arrays stay empty. Skipping the
-- dedup entirely when the array is empty would also work but coalesce is
-- more defensive against any future array_agg-returns-null corner case.

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

  new.service_tags := coalesce(
    (
      select array_agg(distinct t order by t)
      from unnest(new.service_tags) t
    ),
    '{}'::text[]
  );

  return new;
end $$;
