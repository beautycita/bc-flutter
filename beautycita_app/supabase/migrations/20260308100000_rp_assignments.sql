-- =============================================================================
-- Migration: 20260308100000_rp_assignments.sql
-- Description: RP (Representative) salon assignment system — assign RPs to
--              discovered salons, track visits, and manage onboarding pipeline.
-- New tables: rp_assignments, rp_visits
-- Modified tables: profiles (role constraint), discovered_salons (rp columns)
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Fix profiles role constraint — add 'superadmin' and 'rp'
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('customer', 'stylist', 'admin', 'superadmin', 'rp'));

COMMENT ON CONSTRAINT profiles_role_check ON public.profiles IS 'Allowed roles: customer, stylist, admin, superadmin, rp';

-- ---------------------------------------------------------------------------
-- 2. Add RP columns to discovered_salons
-- ---------------------------------------------------------------------------
ALTER TABLE public.discovered_salons
  ADD COLUMN IF NOT EXISTS assigned_rp_id uuid REFERENCES public.profiles(id);

ALTER TABLE public.discovered_salons
  ADD COLUMN IF NOT EXISTS rp_status text NOT NULL DEFAULT 'unassigned';

COMMENT ON COLUMN public.discovered_salons.assigned_rp_id IS 'Currently assigned RP user (NULL = unassigned)';
COMMENT ON COLUMN public.discovered_salons.rp_status IS 'RP pipeline status: unassigned, assigned, contacted, visiting, onboarding, converted, declined';

CREATE INDEX IF NOT EXISTS idx_discovered_salons_assigned_rp
  ON public.discovered_salons (assigned_rp_id)
  WHERE assigned_rp_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_discovered_salons_rp_status
  ON public.discovered_salons (rp_status);

-- RLS: RPs can SELECT their assigned salons
CREATE POLICY "Discovered salons: RPs can read assigned"
  ON public.discovered_salons FOR SELECT
  USING (
    assigned_rp_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Create rp_assignments table (assignment history)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rp_assignments (
  id                   uuid        NOT NULL DEFAULT gen_random_uuid(),
  discovered_salon_id  uuid        NOT NULL REFERENCES public.discovered_salons(id) ON DELETE CASCADE,
  rp_user_id           uuid        NOT NULL REFERENCES public.profiles(id),
  assigned_by          uuid        NOT NULL REFERENCES public.profiles(id),
  assigned_at          timestamptz NOT NULL DEFAULT now(),
  unassigned_at        timestamptz,

  CONSTRAINT rp_assignments_pkey PRIMARY KEY (id)
);

COMMENT ON TABLE public.rp_assignments IS 'History of RP-to-salon assignments. unassigned_at NULL = currently active assignment.';
COMMENT ON COLUMN public.rp_assignments.unassigned_at IS 'NULL means assignment is active; set to deactivate';

-- Only one active assignment per salon
CREATE UNIQUE INDEX IF NOT EXISTS idx_rp_assignments_active_salon
  ON public.rp_assignments (discovered_salon_id)
  WHERE unassigned_at IS NULL;

-- Find all active assignments for an RP
CREATE INDEX IF NOT EXISTS idx_rp_assignments_active_rp
  ON public.rp_assignments (rp_user_id)
  WHERE unassigned_at IS NULL;

-- RLS
ALTER TABLE public.rp_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rp_assignments: admins full access"
  ON public.rp_assignments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

CREATE POLICY "rp_assignments: RPs read own"
  ON public.rp_assignments FOR SELECT
  USING (rp_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4. Create rp_visits table (visit log)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rp_visits (
  id                   uuid        NOT NULL DEFAULT gen_random_uuid(),
  rp_assignment_id     uuid        NOT NULL REFERENCES public.rp_assignments(id) ON DELETE CASCADE,
  discovered_salon_id  uuid        NOT NULL REFERENCES public.discovered_salons(id) ON DELETE CASCADE,
  rp_user_id           uuid        NOT NULL REFERENCES public.profiles(id),
  visited_at           timestamptz NOT NULL DEFAULT now(),
  verbal_contact       boolean     NOT NULL,
  onboarding_complete  boolean     NOT NULL DEFAULT false,
  interest_level       smallint    CHECK (interest_level >= 0 AND interest_level <= 5),
  notes                text,

  CONSTRAINT rp_visits_pkey PRIMARY KEY (id)
);

COMMENT ON TABLE public.rp_visits IS 'Log of RP visits to assigned salons with contact outcomes and interest tracking.';
COMMENT ON COLUMN public.rp_visits.verbal_contact IS 'Whether the RP spoke with someone at the salon';
COMMENT ON COLUMN public.rp_visits.onboarding_complete IS 'Whether the salon completed onboarding during this visit';
COMMENT ON COLUMN public.rp_visits.interest_level IS 'Salon interest 0-5 (0=hostile, 5=eager to join)';

CREATE INDEX IF NOT EXISTS idx_rp_visits_salon
  ON public.rp_visits (discovered_salon_id);

CREATE INDEX IF NOT EXISTS idx_rp_visits_rp
  ON public.rp_visits (rp_user_id);

-- RLS
ALTER TABLE public.rp_visits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rp_visits: admins read all"
  ON public.rp_visits FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

CREATE POLICY "rp_visits: RPs full CRUD own"
  ON public.rp_visits FOR ALL
  USING (rp_user_id = auth.uid())
  WITH CHECK (rp_user_id = auth.uid());

COMMIT;
