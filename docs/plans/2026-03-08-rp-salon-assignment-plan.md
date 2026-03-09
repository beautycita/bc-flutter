# RP Salon Assignment & Outreach System — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable admins to geographically search and assign discovered salons to field RP agents, and give RPs a dedicated map+list panel to visit, onboard, and track those salons.

**Architecture:** New migration for rp_assignments + rp_visits tables and profile role fix. Extend existing search_discovered_salons RPC with geo and assignment params. Enhance AdminPipelineScreen with pin-drop map dialog and RP assignment bulk actions. New RPShellScreen with flutter_map map view + grouped list view. New rp_provider.dart for RP-specific data.

**Tech Stack:** Flutter + Riverpod, flutter_map + latlong2 (already in pubspec), Supabase Postgres + RLS, url_launcher (already in pubspec), geolocator (already in pubspec).

---

## Task 1: Database Migration — Tables, Columns, RLS, Role Fix

**Files:**
- Create: `beautycita_app/supabase/migrations/20260308100000_rp_assignments.sql`

**Context:** The profiles table has a CHECK constraint allowing only `('customer', 'admin')` but the app code references `'superadmin'` and `'rp'` roles. The `isRpProvider` already exists in `admin_provider.dart:55-59`. Discovered salons already have `latitude`/`longitude` columns.

**Step 1: Write the migration**

```sql
-- =============================================================================
-- RP Assignment & Visit Tracking System
-- =============================================================================
-- Enables admin assignment of discovered salons to RP (Public Relations) agents
-- and tracks their field visits with onboarding outcomes.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Fix profiles role constraint (add superadmin + rp)
-- ---------------------------------------------------------------------------
-- Drop the existing constraint and recreate with all valid roles.
-- The constraint name from initial_schema.sql is "profiles_role_check".
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('customer', 'admin', 'superadmin', 'rp'));

-- ---------------------------------------------------------------------------
-- 2. Add RP tracking columns to discovered_salons
-- ---------------------------------------------------------------------------
ALTER TABLE public.discovered_salons
  ADD COLUMN IF NOT EXISTS assigned_rp_id uuid REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS rp_status text NOT NULL DEFAULT 'unassigned';

COMMENT ON COLUMN public.discovered_salons.assigned_rp_id IS 'Currently assigned RP user. NULL = unassigned.';
COMMENT ON COLUMN public.discovered_salons.rp_status IS 'RP workflow status: unassigned, assigned, visited, onboarding_complete';

CREATE INDEX IF NOT EXISTS idx_discovered_salons_assigned_rp
  ON public.discovered_salons (assigned_rp_id) WHERE assigned_rp_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_discovered_salons_rp_status
  ON public.discovered_salons (rp_status);

-- ---------------------------------------------------------------------------
-- 3. RP Assignments table (with history)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rp_assignments (
  id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  discovered_salon_id uuid          NOT NULL REFERENCES public.discovered_salons(id) ON DELETE CASCADE,
  rp_user_id          uuid          NOT NULL REFERENCES public.profiles(id),
  assigned_by         uuid          NOT NULL REFERENCES public.profiles(id),
  assigned_at         timestamptz   NOT NULL DEFAULT now(),
  unassigned_at       timestamptz   -- NULL = currently active
);

COMMENT ON TABLE public.rp_assignments IS 'Assignment history linking discovered salons to RP field agents. NULL unassigned_at = active.';

-- Only one active assignment per salon at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_rp_assignments_active
  ON public.rp_assignments (discovered_salon_id) WHERE unassigned_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_rp_assignments_rp
  ON public.rp_assignments (rp_user_id) WHERE unassigned_at IS NULL;

-- RLS
ALTER TABLE public.rp_assignments ENABLE ROW LEVEL SECURITY;

-- Admins: full access
CREATE POLICY "rp_assignments: admin full access"
  ON public.rp_assignments FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
  );

-- RPs: read their own assignments only
CREATE POLICY "rp_assignments: rp read own"
  ON public.rp_assignments FOR SELECT
  TO authenticated
  USING (rp_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4. RP Visits table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rp_visits (
  id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  rp_assignment_id    uuid          NOT NULL REFERENCES public.rp_assignments(id) ON DELETE CASCADE,
  discovered_salon_id uuid          NOT NULL REFERENCES public.discovered_salons(id) ON DELETE CASCADE,
  rp_user_id          uuid          NOT NULL REFERENCES public.profiles(id),
  visited_at          timestamptz   NOT NULL DEFAULT now(),
  verbal_contact      boolean       NOT NULL,
  onboarding_complete boolean       NOT NULL DEFAULT false,
  interest_level      smallint      CHECK (interest_level >= 0 AND interest_level <= 5),
  notes               text
);

COMMENT ON TABLE public.rp_visits IS 'RP field visit log. Each row = one visit to a salon. verbal_contact is required.';

CREATE INDEX IF NOT EXISTS idx_rp_visits_salon
  ON public.rp_visits (discovered_salon_id);

CREATE INDEX IF NOT EXISTS idx_rp_visits_rp
  ON public.rp_visits (rp_user_id);

-- RLS
ALTER TABLE public.rp_visits ENABLE ROW LEVEL SECURITY;

-- Admins: read all visits
CREATE POLICY "rp_visits: admin read all"
  ON public.rp_visits FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
  );

-- RPs: full CRUD on their own visits
CREATE POLICY "rp_visits: rp full access own"
  ON public.rp_visits FOR ALL
  TO authenticated
  USING (rp_user_id = auth.uid())
  WITH CHECK (rp_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 5. RLS for discovered_salons: RPs can read their assigned salons
-- ---------------------------------------------------------------------------
CREATE POLICY "discovered_salons: rp read assigned"
  ON public.discovered_salons FOR SELECT
  TO authenticated
  USING (assigned_rp_id = auth.uid());
```

**Step 2: Run migration on production**

```bash
ssh www-bc 'docker exec -i supabase-db psql -U postgres -d postgres' < beautycita_app/supabase/migrations/20260308100000_rp_assignments.sql
```

Expected: All CREATE/ALTER statements succeed.

**Step 3: Commit**

```bash
git add beautycita_app/supabase/migrations/20260308100000_rp_assignments.sql
git commit -m "feat: rp_assignments + rp_visits tables, role constraint fix, RLS"
```

---

## Task 2: Extend search_discovered_salons RPC with Geo + Assignment Filters

**Files:**
- Create: `beautycita_app/supabase/migrations/20260308100001_search_discovered_salons_v2.sql`

**Context:** The existing RPC at `20260228000002_search_discovered_salons_rpc.sql` has params: query, status_filter, city_filter_param, has_whatsapp, has_interest, source_filter, result_limit, result_offset. We need to add: `assigned_rp_id`, `rp_status_filter`, `pin_lat`, `pin_lng`, `radius_km`. The function returns columns including `relevance` — we add `assigned_rp_id`, `rp_status`, `latitude`, `longitude` to the return set.

**Step 1: Write the migration**

```sql
-- Migration: Extend search_discovered_salons with geo + RP assignment filters
-- Adds: pin_lat/pin_lng/radius_km for geographic search,
--        assigned_rp_id/rp_status_filter for RP assignment filtering.
-- Returns additional columns: assigned_rp_id, rp_status, latitude, longitude, rp_name.

-- We need to DROP the old function signature first since we're changing params
DROP FUNCTION IF EXISTS public.search_discovered_salons(text, text[], text, boolean, boolean, text, int, int);

CREATE OR REPLACE FUNCTION public.search_discovered_salons(
  query text DEFAULT '',
  status_filter text[] DEFAULT NULL,
  city_filter_param text DEFAULT NULL,
  has_whatsapp boolean DEFAULT NULL,
  has_interest boolean DEFAULT NULL,
  source_filter text DEFAULT NULL,
  result_limit int DEFAULT 50,
  result_offset int DEFAULT 0,
  -- New params for RP assignment
  p_assigned_rp_id uuid DEFAULT NULL,
  p_rp_status_filter text DEFAULT NULL,  -- 'unassigned', 'assigned', 'visited', 'onboarding_complete'
  -- New params for geographic search
  p_pin_lat double precision DEFAULT NULL,
  p_pin_lng double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  business_name text,
  phone text,
  whatsapp text,
  location_address text,
  location_city text,
  location_state text,
  country text,
  feature_image_url text,
  rating_average numeric,
  rating_count int,
  categories text,
  source text,
  status text,
  interest_count int,
  outreach_count int,
  last_outreach_at timestamptz,
  outreach_channel text,
  whatsapp_verified boolean,
  created_at timestamptz,
  relevance float,
  -- New return columns
  assigned_rp_id uuid,
  rp_status text,
  latitude double precision,
  longitude double precision,
  rp_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  raw_tokens  text[];
  tok         text;
  city_from_query text := NULL;
  state_from_query text := NULL;
  phone_filter text := NULL;
  name_tokens text[] := '{}';
  alias_row   record;
  has_search  boolean;
BEGIN
  has_search := query IS NOT NULL AND trim(query) <> '';

  IF has_search THEN
    raw_tokens := string_to_array(lower(trim(query)), ' ');

    FOREACH tok IN ARRAY raw_tokens LOOP
      IF tok = '' THEN CONTINUE; END IF;

      SELECT ca.city, ca.state INTO alias_row
        FROM public.city_aliases ca WHERE ca.alias = tok LIMIT 1;
      IF FOUND THEN
        city_from_query := alias_row.city;
        state_from_query := alias_row.state;
        CONTINUE;
      END IF;

      IF tok ~ '^\d{3,}$' THEN
        phone_filter := tok;
        CONTINUE;
      END IF;

      name_tokens := array_append(name_tokens, tok);
    END LOOP;

    IF city_from_query IS NULL THEN
      DECLARE multi_alias text;
      BEGIN
        multi_alias := array_to_string(name_tokens, ' ');
        IF multi_alias <> '' THEN
          SELECT ca.city, ca.state INTO alias_row
            FROM public.city_aliases ca WHERE ca.alias = multi_alias LIMIT 1;
          IF FOUND THEN
            city_from_query := alias_row.city;
            state_from_query := alias_row.state;
            name_tokens := '{}';
          END IF;
        END IF;
      END;
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.business_name,
    d.phone,
    d.whatsapp,
    d.location_address,
    d.location_city,
    d.location_state,
    d.country,
    d.feature_image_url,
    d.rating_average,
    d.rating_count,
    d.categories,
    d.source,
    d.status,
    d.interest_count,
    d.outreach_count,
    d.last_outreach_at,
    d.outreach_channel,
    d.whatsapp_verified,
    d.created_at,
    (
      CASE WHEN city_from_query IS NOT NULL AND lower(d.location_city) = lower(city_from_query) THEN 10.0 ELSE 0.0 END
      + CASE WHEN state_from_query IS NOT NULL AND lower(d.location_state) = lower(state_from_query) THEN 5.0 ELSE 0.0 END
      + CASE WHEN phone_filter IS NOT NULL AND (
            regexp_replace(coalesce(d.phone,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
            OR regexp_replace(coalesce(d.whatsapp,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
          ) THEN 15.0 ELSE 0.0 END
      + (
          SELECT coalesce(sum(
            CASE
              WHEN lower(d.business_name) = nt THEN 20.0
              WHEN lower(d.business_name) LIKE nt || '%' THEN 10.0
              WHEN lower(d.business_name) LIKE '%' || nt || '%' THEN 5.0
              ELSE 0.0
            END
            + similarity(lower(d.business_name), nt) * 8.0
            + CASE WHEN lower(coalesce(d.location_address,'')) LIKE '%' || nt || '%' THEN 3.0 ELSE 0.0 END
          ), 0.0)
          FROM unnest(name_tokens) AS nt
        )
      -- Geo proximity bonus: closer = higher relevance
      + CASE
          WHEN p_pin_lat IS NOT NULL AND p_pin_lng IS NOT NULL AND d.latitude IS NOT NULL AND d.longitude IS NOT NULL THEN
            GREATEST(0, 10.0 - (
              6371 * acos(
                LEAST(1.0, cos(radians(p_pin_lat)) * cos(radians(d.latitude))
                * cos(radians(d.longitude) - radians(p_pin_lng))
                + sin(radians(p_pin_lat)) * sin(radians(d.latitude)))
              )
            ) / COALESCE(p_radius_km, 25.0) * 10.0)
          ELSE 0.0
        END
    )::float AS relevance,
    -- New columns
    d.assigned_rp_id,
    d.rp_status,
    d.latitude,
    d.longitude,
    (SELECT p.full_name FROM public.profiles p WHERE p.id = d.assigned_rp_id) AS rp_name
  FROM public.discovered_salons d
  WHERE
    -- Existing filters
    (status_filter IS NULL OR d.status = ANY(status_filter))
    AND (city_filter_param IS NULL OR lower(d.location_city) = lower(city_filter_param))
    AND (has_whatsapp IS NULL OR (has_whatsapp = true AND d.whatsapp_verified = true) OR (has_whatsapp = false))
    AND (has_interest IS NULL OR (has_interest = true AND d.interest_count > 0) OR (has_interest = false))
    AND (source_filter IS NULL OR d.source = source_filter)
    -- New RP filters
    AND (p_assigned_rp_id IS NULL OR d.assigned_rp_id = p_assigned_rp_id)
    AND (p_rp_status_filter IS NULL OR d.rp_status = p_rp_status_filter)
    -- Text search filters
    AND (city_from_query IS NULL OR lower(d.location_city) = lower(city_from_query))
    AND (state_from_query IS NULL OR lower(d.location_state) = lower(state_from_query))
    AND (phone_filter IS NULL OR (
      regexp_replace(coalesce(d.phone,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
      OR regexp_replace(coalesce(d.whatsapp,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
    ))
    AND (
      array_length(name_tokens, 1) IS NULL
      OR NOT EXISTS (
        SELECT 1 FROM unnest(name_tokens) AS nt
        WHERE NOT (
          lower(d.business_name) LIKE '%' || nt || '%'
          OR lower(coalesce(d.location_address,'')) LIKE '%' || nt || '%'
          OR lower(d.location_city) LIKE '%' || nt || '%'
          OR lower(d.location_state) LIKE '%' || nt || '%'
          OR similarity(lower(d.business_name), nt) > 0.2
        )
      )
    )
    -- Geo radius filter (haversine)
    AND (
      p_pin_lat IS NULL OR p_pin_lng IS NULL OR p_radius_km IS NULL
      OR d.latitude IS NULL OR d.longitude IS NULL
      OR (
        6371 * acos(
          LEAST(1.0, cos(radians(p_pin_lat)) * cos(radians(d.latitude))
          * cos(radians(d.longitude) - radians(p_pin_lng))
          + sin(radians(p_pin_lat)) * sin(radians(d.latitude)))
        )
      ) <= p_radius_km
    )
  ORDER BY relevance DESC, d.interest_count DESC, d.business_name ASC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant to authenticated (new signature)
GRANT EXECUTE ON FUNCTION public.search_discovered_salons(
  text, text[], text, boolean, boolean, text, int, int,
  uuid, text, double precision, double precision, double precision
) TO authenticated;
```

**Step 2: Run migration on production**

```bash
ssh www-bc 'docker exec -i supabase-db psql -U postgres -d postgres' < beautycita_app/supabase/migrations/20260308100001_search_discovered_salons_v2.sql
```

**Step 3: Commit**

```bash
git add beautycita_app/supabase/migrations/20260308100001_search_discovered_salons_v2.sql
git commit -m "feat: extend search_discovered_salons with geo radius + RP assignment filters"
```

---

## Task 3: RP Provider — Data Layer for RP Panel + Admin Assignment

**Files:**
- Create: `beautycita_app/lib/providers/rp_provider.dart`
- Modify: `beautycita_app/lib/providers/admin_provider.dart` (add RP user list provider)

**Context:** `admin_provider.dart` already has `isRpProvider` (line 55-59), `rpWithinGeofenceProvider` (line 74-84), `searchDiscoveredSalonsProvider` (line 950-963), and `pipelineSearchParamsProvider` (line 967). The RP panel needs its own providers for assigned salons, visit logging, and salon detail. The admin needs a provider to list all RP users for the assignment picker.

**Step 1: Create rp_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';

// ---------------------------------------------------------------------------
// RP's assigned salons
// ---------------------------------------------------------------------------

/// Fetches all salons assigned to the current RP user.
final rpAssignedSalonsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseClientService.client
      .from('discovered_salons')
      .select(
        'id, business_name, phone, whatsapp, location_address, location_city, '
        'location_state, latitude, longitude, feature_image_url, rating_average, '
        'rating_count, categories, working_hours, website, facebook_url, '
        'instagram_url, rp_status, assigned_rp_id',
      )
      .eq('assigned_rp_id', userId)
      .order('rp_status')
      .order('business_name');

  return (response as List).cast<Map<String, dynamic>>();
});

/// Fetches visit history for a specific salon by the current RP.
final rpVisitsForSalonProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, salonId) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseClientService.client
      .from('rp_visits')
      .select()
      .eq('discovered_salon_id', salonId)
      .eq('rp_user_id', userId)
      .order('visited_at', ascending: false)
      .limit(20);

  return (response as List).cast<Map<String, dynamic>>();
});

/// Logs a visit for the current RP.
Future<void> rpLogVisit({
  required String assignmentId,
  required String salonId,
  required bool verbalContact,
  required bool onboardingComplete,
  int? interestLevel,
  String? notes,
}) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return;

  final client = SupabaseClientService.client;

  // Insert visit
  await client.from('rp_visits').insert({
    'rp_assignment_id': assignmentId,
    'discovered_salon_id': salonId,
    'rp_user_id': userId,
    'verbal_contact': verbalContact,
    'onboarding_complete': onboardingComplete,
    if (interestLevel != null) 'interest_level': interestLevel,
    if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
  });

  // Update denormalized rp_status on discovered_salons
  final newStatus = onboardingComplete ? 'onboarding_complete' : 'visited';
  await client
      .from('discovered_salons')
      .update({'rp_status': newStatus})
      .eq('id', salonId);
}

// ---------------------------------------------------------------------------
// Admin: RP user list for assignment picker
// ---------------------------------------------------------------------------

/// All users with role='rp' — for the admin assignment picker.
final rpUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseClientService.client
      .from('profiles')
      .select('id, full_name, username, phone, avatar_url')
      .eq('role', 'rp')
      .order('full_name');

  return (response as List).cast<Map<String, dynamic>>();
});

/// Assigns salons to an RP (admin action).
Future<void> adminAssignSalonsToRp({
  required List<String> salonIds,
  required String rpUserId,
}) async {
  final adminId = SupabaseClientService.currentUserId;
  if (adminId == null) return;

  final client = SupabaseClientService.client;

  for (final salonId in salonIds) {
    // Create assignment record
    await client.from('rp_assignments').insert({
      'discovered_salon_id': salonId,
      'rp_user_id': rpUserId,
      'assigned_by': adminId,
    });

    // Update denormalized fields
    await client.from('discovered_salons').update({
      'assigned_rp_id': rpUserId,
      'rp_status': 'assigned',
    }).eq('id', salonId);
  }
}

/// Unassigns salons from their current RP (admin action).
Future<void> adminUnassignSalons({
  required List<String> salonIds,
}) async {
  final client = SupabaseClientService.client;

  for (final salonId in salonIds) {
    // Close active assignment
    await client
        .from('rp_assignments')
        .update({'unassigned_at': DateTime.now().toUtc().toIso8601String()})
        .eq('discovered_salon_id', salonId)
        .isFilter('unassigned_at', null);

    // Clear denormalized fields
    await client.from('discovered_salons').update({
      'assigned_rp_id': null,
      'rp_status': 'unassigned',
    }).eq('id', salonId);
  }
}

/// Gets the active assignment ID for a salon (needed for visit logging).
Future<String?> getActiveAssignmentId(String salonId) async {
  final response = await SupabaseClientService.client
      .from('rp_assignments')
      .select('id')
      .eq('discovered_salon_id', salonId)
      .isFilter('unassigned_at', null)
      .maybeSingle();
  return response?['id'] as String?;
}
```

**Step 2: Commit**

```bash
git add beautycita_app/lib/providers/rp_provider.dart
git commit -m "feat: rp_provider — assigned salons, visit logging, admin assignment functions"
```

---

## Task 4: Admin Pipeline Screen — Geographic Search + RP Assignment

**Files:**
- Modify: `beautycita_app/lib/screens/admin/admin_pipeline_screen.dart`
- Modify: `beautycita_app/lib/providers/admin_provider.dart` (update searchDiscoveredSalonsProvider params)

**Context:** The pipeline screen is at `admin_pipeline_screen.dart` (~1400 lines). It has a search bar, filter row (status, source, WhatsApp, interest), metrics header, bulk actions (status change, delete, export), and a list of salon cards. The `searchDiscoveredSalonsProvider` calls the RPC via `pipelineSearchParamsProvider`. We need to add:

1. **RP assignment filter** — dropdown in filter row: "All" / "Unassigned" / specific RP name
2. **rp_status filter** — chips: unassigned/assigned/visited/onboarding_complete
3. **Pin drop button** — opens a flutter_map dialog where admin taps to place a pin, selects radius, confirms. Sets `p_pin_lat`, `p_pin_lng`, `p_radius_km` in search params.
4. **Bulk assign action** — select salons → "Assign to RP" → picker dialog → confirm
5. **Bulk unassign action** — select salons → "Unassign"
6. **RP name badge** — on each salon card, show assigned RP name + color-coded rp_status

**Implementation notes:**
- Import `rp_provider.dart` for `rpUsersProvider`, `adminAssignSalonsToRp`, `adminUnassignSalons`
- Import `flutter_map` and `latlong2` for pin drop dialog
- Add new params to `pipelineSearchParamsProvider` usage: `p_assigned_rp_id`, `p_rp_status_filter`, `p_pin_lat`, `p_pin_lng`, `p_radius_km`
- Update `searchDiscoveredSalonsProvider` to pass new params to RPC
- Pin drop dialog: `_PinDropDialog` — StatefulWidget with FlutterMap, tap to place marker, radius dropdown (5/10/25/50km), confirm/cancel
- RP picker dialog: `_RpPickerDialog` — shows list from `rpUsersProvider`, tap to select, confirm with count

**Step 1: Update searchDiscoveredSalonsProvider in admin_provider.dart**

In `admin_provider.dart`, update the `searchDiscoveredSalonsProvider` (line 950-963) to pass the new params:

```dart
// Replace the existing searchDiscoveredSalonsProvider (lines 950-963)
final searchDiscoveredSalonsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, key) async {
  final params = ref.read(pipelineSearchParamsProvider);
  final response = await SupabaseClientService.client.rpc('search_discovered_salons', params: {
    'query': params['query'] ?? '',
    if (params['status_filter'] != null) 'status_filter': params['status_filter'],
    if (params['city_filter'] != null) 'city_filter_param': params['city_filter'],
    if (params['has_whatsapp'] != null) 'has_whatsapp': params['has_whatsapp'],
    if (params['has_interest'] != null) 'has_interest': params['has_interest'],
    if (params['source_filter'] != null) 'source_filter': params['source_filter'],
    'result_limit': params['result_limit'] ?? 50,
    'result_offset': params['result_offset'] ?? 0,
    // RP assignment filters
    if (params['p_assigned_rp_id'] != null) 'p_assigned_rp_id': params['p_assigned_rp_id'],
    if (params['p_rp_status_filter'] != null) 'p_rp_status_filter': params['p_rp_status_filter'],
    // Geo filters
    if (params['p_pin_lat'] != null) 'p_pin_lat': params['p_pin_lat'],
    if (params['p_pin_lng'] != null) 'p_pin_lng': params['p_pin_lng'],
    if (params['p_radius_km'] != null) 'p_radius_km': params['p_radius_km'],
  });
  return (response as List).cast<Map<String, dynamic>>();
});
```

**Step 2: Add to admin_pipeline_screen.dart**

Add these imports at top:
```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../providers/rp_provider.dart';
```

Add to the filter row (after existing source filter):
- RP assignment dropdown (uses `rpUsersProvider`)
- RP status chips
- Pin drop button with active indicator

Add to bulk actions bar:
- "Asignar RP" button → opens `_RpPickerDialog`
- "Desasignar" button → calls `adminUnassignSalons`

Add to each salon card:
- RP name chip (colored by rp_status)
- Lat/lng available indicator

Add new dialogs as private widgets:
- `_PinDropDialog` — FlutterMap with tap-to-pin + radius selector
- `_RpPickerDialog` — list of RP users with selection

**Step 3: Commit**

```bash
git add beautycita_app/lib/providers/admin_provider.dart beautycita_app/lib/screens/admin/admin_pipeline_screen.dart
git commit -m "feat: pipeline geographic search, RP assignment/unassignment, pin drop dialog"
```

---

## Task 5: RP Shell Screen — Map View + List View + Visit Logging

**Files:**
- Create: `beautycita_app/lib/screens/rp/rp_shell_screen.dart`
- Modify: `beautycita_app/lib/config/routes.dart` (add `/rp` route)

**Context:** The RP shell is a separate screen accessed by users with `role='rp'`. It has 2 tabs: Map (default) and List. Uses `rpAssignedSalonsProvider` from `rp_provider.dart`. Map uses `flutter_map` (same as `route_map_widget.dart`). Navigation opens Google Maps/Waze via `url_launcher`. The existing `RouteMapWidget` at `lib/widgets/route_map_widget.dart` shows the pattern for flutter_map usage (OSM tiles, markers, polylines).

**Step 1: Create rp_shell_screen.dart**

Structure:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../providers/rp_provider.dart';
import '../../services/location_service.dart';
import '../../services/toast_service.dart';

class RPShellScreen extends ConsumerStatefulWidget { ... }

class _RPShellScreenState extends ConsumerState<RPShellScreen> {
  int _tabIndex = 0; // 0=Map, 1=List

  @override
  Widget build(BuildContext context) {
    final isRp = ref.watch(isRpProvider);
    // Gate: only role='rp' can access
    return isRp.when(
      data: (rp) => rp ? _RPContent(...) : _AccessDenied(),
      ...
    );
  }
}
```

**Map Tab:**
- FlutterMap centered on user's current location (via `LocationService.getCurrentLocation()`)
- MarkerLayer with pins for each assigned salon, colored by rp_status:
  - blue = assigned (not visited)
  - orange = visited
  - green = onboarding_complete
  - gray = interest_level == 0 (no interest)
- Tap pin → `_SalonDetailSheet` bottom sheet with:
  - Business name, address, city
  - Rating + review count
  - Categories, hours, website, social links
  - Visit history list
  - "Navegar" button → `launchUrl(Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)'))`
  - "Cercanos" button → filter map to show 5 nearest unvisited salons with distance
  - "Registrar Visita" button → opens `_LogVisitDialog`

**List Tab:**
- Grouped ListView with sections:
  - "Sin Visitar" (rp_status == 'assigned')
  - "Visitados — Seguimiento" (rp_status == 'visited', interest_level > 0)
  - "Onboarding Completo" (rp_status == 'onboarding_complete')
  - "Sin Interes" (rp_status == 'visited', interest_level == 0)
- Each card: name, address, rating, last visit date, interest badge
- Tap → same `_SalonDetailSheet`

**Visit Log Dialog (`_LogVisitDialog`):**
- Required: SwitchListTile "Contacto verbal con administrador?"
- If yes: Checkbox "Onboarding completo?"
- If not onboarding_complete: Slider 0-5 "Nivel de interes"
- Optional: TextField "Notas"
- Submit button → calls `rpLogVisit()` + invalidates `rpAssignedSalonsProvider`

**Nearby Logic:**
- When "Cercanos" tapped on a salon, calculate haversine distance from that salon to all other unvisited salons
- Sort by distance, take top 5
- Highlight those pins (larger, pulsing border)
- Show distance label on each

**Step 2: Add route in routes.dart**

After the admin route (around line 287), add:
```dart
GoRoute(
  path: '/rp',
  name: 'rp',
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: const RPShellScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  ),
),
```

Also add `import 'package:beautycita/screens/rp/rp_shell_screen.dart';` at top and `static const String rp = '/rp';` to AppRoutes.

**Step 3: Add RP panel entry point**

In `beautycita_app/lib/screens/home_screen.dart` or `settings_screen.dart`, add a button/tile visible when `isRpProvider` is true that navigates to `/rp`. Follow the same pattern used for the admin button that navigates to `/admin`.

**Step 4: Commit**

```bash
git add beautycita_app/lib/screens/rp/rp_shell_screen.dart beautycita_app/lib/config/routes.dart
git commit -m "feat: RP shell screen — map view, list view, visit logging, navigation"
```

---

## Task 6: Deploy + Build

**Step 1: Run both migrations on production**

```bash
ssh www-bc 'docker exec -i supabase-db psql -U postgres -d postgres' < beautycita_app/supabase/migrations/20260308100000_rp_assignments.sql
ssh www-bc 'docker exec -i supabase-db psql -U postgres -d postgres' < beautycita_app/supabase/migrations/20260308100001_search_discovered_salons_v2.sql
```

**Step 2: Build and deploy APK**

```bash
cd /home/bc/futureBeauty/beautycita_app
# Bump version in pubspec.yaml to next build number
flutter build apk --release --split-per-abi
aws s3 cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk s3://beautycita-medias/apk/beautycita.apk --profile r2
# Update version.json with new build number and required:true
```

**Step 3: Build and deploy web**

```bash
cd /home/bc/futureBeauty/beautycita_web
flutter build web --release --no-tree-shake-icons
rsync -avz --delete build/web/ www-bc:/var/www/beautycita.com/frontend/dist/
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: RP salon assignment system — geo search, assignment tracking, RP panel"
```
