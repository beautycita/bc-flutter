-- =============================================================================
-- Fix admin RLS policies that only check role = 'admin' but miss 'superadmin'
-- Root cause: older migrations hardcoded 'admin', newer ones use IN ('admin', 'superadmin')
-- This caused the entire admin panel to show empty for superadmin users.
-- =============================================================================

-- 1. businesses: admin read-all policy
DROP POLICY IF EXISTS "Businesses: admin can read all" ON public.businesses;
CREATE POLICY "Businesses: admin can read all"
  ON public.businesses FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

-- 2. Initial schema admin policies (from 20260201000000)
-- These are on the main admin CRUD functions

-- profiles: admin read all
DROP POLICY IF EXISTS "Admin: full access to profiles" ON public.profiles;
CREATE POLICY "Admin: full access to profiles"
  ON public.profiles FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('admin', 'superadmin')
    )
  );

-- appointments: admin read all
DROP POLICY IF EXISTS "Admin: full access to appointments" ON public.appointments;
CREATE POLICY "Admin: full access to appointments"
  ON public.appointments FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

-- staff: admin read all
DROP POLICY IF EXISTS "Admin: full access to staff" ON public.staff;
CREATE POLICY "Admin: full access to staff"
  ON public.staff FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

-- services: admin read all
DROP POLICY IF EXISTS "Admin: full access to services" ON public.services;
CREATE POLICY "Admin: full access to services"
  ON public.services FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

-- reviews: admin read all
DROP POLICY IF EXISTS "Admin: full access to reviews" ON public.reviews;
CREATE POLICY "Admin: full access to reviews"
  ON public.reviews FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

-- payments: admin read all
DROP POLICY IF EXISTS "Admin: full access to payments" ON public.payments;
CREATE POLICY "Admin: full access to payments"
  ON public.payments FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

-- disputes: admin read all (if table exists)
DO $$ BEGIN
  IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'disputes') THEN
    EXECUTE 'DROP POLICY IF EXISTS "Admin: full access to disputes" ON public.disputes';
    EXECUTE '
      CREATE POLICY "Admin: full access to disputes"
        ON public.disputes FOR ALL
        TO authenticated
        USING (
          EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN (''admin'', ''superadmin'')
          )
        )';
  END IF;
END $$;

-- salon_banking: fix policies that only check 'admin'
DROP POLICY IF EXISTS "salon_banking: admin can read all" ON public.salon_banking;
CREATE POLICY "salon_banking: admin can read all"
  ON public.salon_banking FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

DROP POLICY IF EXISTS "salon_banking: admin can update" ON public.salon_banking;
CREATE POLICY "salon_banking: admin can update"
  ON public.salon_banking FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
    )
  );

-- Fix the function-based admin checks (initial schema lines 973, 982)
-- These are likely in check_admin functions used by RPC calls
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'superadmin')
  );
$$;
