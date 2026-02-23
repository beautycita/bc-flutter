-- Allow anon role to read discovered_salons for web registration prefill.
-- The static landing page at beautycita.com/registro uses the anon key
-- to fetch salon data (name, phone, address, photo) when ?ref=<id> is present.

CREATE POLICY "discovered_salons: anon read for registration prefill"
  ON public.discovered_salons FOR SELECT
  TO anon
  USING (true);
