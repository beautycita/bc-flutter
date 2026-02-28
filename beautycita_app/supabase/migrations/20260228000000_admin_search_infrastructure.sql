-- Migration: Admin Search Infrastructure
-- Adds pg_trgm fuzzy search, city aliases table, trigram indexes,
-- and expands salon_outreach_log for the admin search screens.

-- 1. Enable pg_trgm extension for fuzzy text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Create city_aliases table for intelligent search alias resolution
CREATE TABLE IF NOT EXISTS public.city_aliases (
  alias   text PRIMARY KEY,
  city    text NOT NULL,
  state   text,
  country text NOT NULL DEFAULT 'MX'
);

-- 3. Seed common aliases (idempotent)
INSERT INTO public.city_aliases (alias, city, state, country) VALUES
  -- Mexico
  ('gdl',               'Guadalajara',        'Jalisco',                    'MX'),
  ('guada',             'Guadalajara',        'Jalisco',                    'MX'),
  ('guadalajara',       'Guadalajara',        'Jalisco',                    'MX'),
  ('cdmx',              'Ciudad de Mexico',   'Ciudad de Mexico',           'MX'),
  ('df',                'Ciudad de Mexico',   'Ciudad de Mexico',           'MX'),
  ('mexico city',       'Ciudad de Mexico',   'Ciudad de Mexico',           'MX'),
  ('cabo',              'Cabo San Lucas',     'Baja California Sur',        'MX'),
  ('san lucas',         'Cabo San Lucas',     'Baja California Sur',        'MX'),
  ('los cabos',         'Cabo San Lucas',     'Baja California Sur',        'MX'),
  ('pvr',               'Puerto Vallarta',    'Jalisco',                    'MX'),
  ('vallarta',          'Puerto Vallarta',    'Jalisco',                    'MX'),
  ('puerto vallarta',   'Puerto Vallarta',    'Jalisco',                    'MX'),
  ('mty',               'Monterrey',          'Nuevo Leon',                 'MX'),
  ('monterrey',         'Monterrey',          'Nuevo Leon',                 'MX'),
  ('tj',                'Tijuana',            'Baja California',            'MX'),
  ('tijuana',           'Tijuana',            'Baja California',            'MX'),
  ('cancun',            'Cancun',             'Quintana Roo',               'MX'),
  ('merida',            'Merida',             'Yucatan',                    'MX'),
  ('puebla',            'Puebla',             'Puebla',                     'MX'),
  ('qro',               'Queretaro',          'Queretaro',                  'MX'),
  ('queretaro',         'Queretaro',          'Queretaro',                  'MX'),
  ('leon',              'Leon',               'Guanajuato',                 'MX'),
  ('slp',               'San Luis Potosi',    'San Luis Potosi',            'MX'),
  ('san luis potosi',   'San Luis Potosi',    'San Luis Potosi',            'MX'),
  ('playa',             'Playa del Carmen',   'Quintana Roo',               'MX'),
  ('playa del carmen',  'Playa del Carmen',   'Quintana Roo',               'MX'),
  -- USA
  ('htown',             'Houston',            'Texas',                      'US'),
  ('hou',               'Houston',            'Texas',                      'US'),
  ('htx',               'Houston',            'Texas',                      'US'),
  ('houston',           'Houston',            'Texas',                      'US'),
  ('dallas',            'Dallas',             'Texas',                      'US'),
  ('dfw',               'Dallas',             'Texas',                      'US'),
  ('sa',                'San Antonio',        'Texas',                      'US'),
  ('satx',              'San Antonio',        'Texas',                      'US'),
  ('san antonio',       'San Antonio',        'Texas',                      'US'),
  ('austin',            'Austin',             'Texas',                      'US'),
  ('atx',               'Austin',             'Texas',                      'US'),
  ('la',                'Los Angeles',        'California',                 'US'),
  ('los angeles',       'Los Angeles',        'California',                 'US'),
  ('nyc',               'New York',           'New York',                   'US'),
  ('new york',          'New York',           'New York',                   'US'),
  ('chi',               'Chicago',            'Illinois',                   'US'),
  ('chicago',           'Chicago',            'Illinois',                   'US'),
  ('miami',             'Miami',              'Florida',                    'US'),
  ('phx',               'Phoenix',            'Arizona',                    'US'),
  ('phoenix',           'Phoenix',            'Arizona',                    'US'),
  ('vegas',             'Las Vegas',          'Nevada',                     'US'),
  ('lv',                'Las Vegas',          'Nevada',                     'US'),
  ('las vegas',         'Las Vegas',          'Nevada',                     'US'),
  ('denver',            'Denver',             'Colorado',                   'US'),
  ('seattle',           'Seattle',            'Washington',                 'US'),
  ('portland',          'Portland',           'Oregon',                     'US'),
  ('atlanta',           'Atlanta',            'Georgia',                    'US'),
  ('atl',               'Atlanta',            'Georgia',                    'US')
ON CONFLICT (alias) DO NOTHING;

-- 4. Trigram indexes on businesses table
CREATE INDEX IF NOT EXISTS idx_businesses_name_trgm ON public.businesses USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_businesses_phone_btree ON public.businesses (phone);
CREATE INDEX IF NOT EXISTS idx_businesses_city_btree ON public.businesses (city);
CREATE INDEX IF NOT EXISTS idx_businesses_state_btree ON public.businesses (state);

-- 5. Trigram indexes on discovered_salons table (uses renamed columns)
CREATE INDEX IF NOT EXISTS idx_discovered_salons_name_trgm ON public.discovered_salons USING gin (business_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_discovered_salons_phone_btree ON public.discovered_salons (phone);
CREATE INDEX IF NOT EXISTS idx_discovered_salons_city_btree ON public.discovered_salons (location_city);
CREATE INDEX IF NOT EXISTS idx_discovered_salons_status_btree ON public.discovered_salons (status);

-- 6. Expand salon_outreach_log channel constraint to include manual channels
ALTER TABLE public.salon_outreach_log
  DROP CONSTRAINT IF EXISTS salon_outreach_log_channel_check;
ALTER TABLE public.salon_outreach_log
  ADD CONSTRAINT salon_outreach_log_channel_check
  CHECK (channel IN (
    'whatsapp', 'sms', 'email',
    'phone_call', 'in_person', 'radio_ad',
    'social_media_ad', 'flyer', 'referral', 'other'
  ));

-- 7. Add notes and outcome columns to salon_outreach_log
ALTER TABLE public.salon_outreach_log ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE public.salon_outreach_log ADD COLUMN IF NOT EXISTS outcome text;

-- 8. Enable RLS on city_aliases with public read policy
ALTER TABLE public.city_aliases ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'city_aliases'
      AND policyname = 'Anyone can read city aliases'
  ) THEN
    CREATE POLICY "Anyone can read city aliases"
      ON public.city_aliases FOR SELECT USING (true);
  END IF;
END
$$;
