-- Add slug column to businesses table (needed by feed-public, portfolio pages)
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS slug text UNIQUE;

CREATE INDEX IF NOT EXISTS idx_businesses_slug
  ON public.businesses (slug) WHERE slug IS NOT NULL;

-- Create portfolio_photos table for before/after inspiration feed
CREATE TABLE IF NOT EXISTS public.portfolio_photos (
  id               uuid        NOT NULL DEFAULT gen_random_uuid(),
  business_id      uuid        NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  staff_id         uuid        REFERENCES public.staff(id) ON DELETE SET NULL,
  before_url       text        NOT NULL,
  after_url        text        NOT NULL,
  caption          text,
  service_category text,
  product_tags     jsonb       DEFAULT '[]'::jsonb,
  is_visible       boolean     NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT portfolio_photos_pkey PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_portfolio_business_id
  ON public.portfolio_photos(business_id);

CREATE INDEX IF NOT EXISTS idx_portfolio_created_at
  ON public.portfolio_photos(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_portfolio_visible
  ON public.portfolio_photos(is_visible) WHERE is_visible = true;

CREATE TRIGGER portfolio_photos_updated_at
  BEFORE UPDATE ON public.portfolio_photos
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.portfolio_photos ENABLE ROW LEVEL SECURITY;

-- Anyone can read visible photos from active businesses
CREATE POLICY "portfolio_photos_select_public"
  ON public.portfolio_photos FOR SELECT
  USING (
    is_visible = true
    AND EXISTS (
      SELECT 1 FROM public.businesses
      WHERE id = portfolio_photos.business_id AND is_active = true
    )
  );

-- Business owner CRUD
CREATE POLICY "portfolio_photos_insert_owner"
  ON public.portfolio_photos FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = portfolio_photos.business_id AND owner_id = auth.uid()
  ));

CREATE POLICY "portfolio_photos_update_owner"
  ON public.portfolio_photos FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = portfolio_photos.business_id AND owner_id = auth.uid()
  ));

CREATE POLICY "portfolio_photos_delete_owner"
  ON public.portfolio_photos FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = portfolio_photos.business_id AND owner_id = auth.uid()
  ));

-- Service role full access for edge functions
CREATE POLICY "portfolio_photos_service_role"
  ON public.portfolio_photos FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
