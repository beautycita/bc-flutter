-- =============================================================================
-- Migration: Enforce is_verified on all customer-facing business queries
-- No unverified (pending admin review) salon should appear to customers.
-- =============================================================================

-- Recreate curate_candidates to require is_verified = true
create or replace function public.curate_candidates(
  p_service_type   text,
  p_lat            double precision,
  p_lng            double precision,
  p_radius_meters  integer,
  p_window_start   timestamptz,
  p_window_end     timestamptz,
  p_business_id    uuid default null
)
returns table (
  business_id      uuid,
  business_name    text,
  business_photo   text,
  business_address text,
  business_lat     double precision,
  business_lng     double precision,
  business_whatsapp text,
  business_rating  numeric,
  business_reviews integer,
  cancellation_hours integer,
  deposit_required boolean,
  auto_confirm     boolean,
  accept_walkins   boolean,
  service_id       uuid,
  service_name     text,
  service_price    numeric,
  duration_minutes integer,
  buffer_minutes   integer,
  staff_id         uuid,
  staff_name       text,
  staff_avatar     text,
  experience_years integer,
  staff_rating     numeric,
  staff_reviews    integer,
  effective_price  numeric,
  effective_duration integer,
  distance_m       double precision,
  slot_start       timestamptz,
  slot_end         timestamptz
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
      and b.is_verified  = true   -- Only admin-approved businesses
      and b.onboarding_complete = true
      and (p_business_id is null or b.id = p_business_id)
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
    avail.slot_start,
    avail.slot_start + (sm.effective_duration || ' minutes')::interval as slot_end
  from service_match sm
  cross join lateral public.find_available_slots(
    sm.staff_id,
    sm.effective_duration,
    p_window_start,
    p_window_end
  ) avail
  order by sm.distance_m, avail.slot_start
  limit 50;
$$;
