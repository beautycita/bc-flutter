-- Restrict discovered_salons from world-readable to authenticated-only.
-- Previously any anonymous user could scrape 46K salon records with PII (phone, email, owner_name).
-- Edge function outreach-discovered-salon already strips PII from responses (fixed 2026-03-10),
-- but the DB-level policy was still wide open.

DROP POLICY IF EXISTS "Discovered salons: anyone can read" ON public.discovered_salons;

-- Also drop the duplicate anon read policy from 20260222120000 if it exists
DROP POLICY IF EXISTS "anon_read_discovered_salons" ON public.discovered_salons;

-- Authenticated users can read (edge functions use service_role which bypasses RLS)
CREATE POLICY "Discovered salons: authenticated read safe columns"
  ON public.discovered_salons FOR SELECT
  TO authenticated
  USING (true);
