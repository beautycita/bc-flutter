-- =============================================================================
-- Migration: 20260307100000_feed_marketplace.sql
-- Description: Inspiration feed + POS marketplace — products, orders,
--              engagement tracking, saves, showcases, seller agreements.
-- New tables: products, product_showcases, orders, feed_engagement,
--             feed_saves, pos_agreements
-- Modified tables: businesses (pos_enabled column)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. POS enabled flag on businesses
-- ---------------------------------------------------------------------------
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS pos_enabled boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.businesses.pos_enabled IS 'When true, salon can list products for sale in the marketplace';

-- ---------------------------------------------------------------------------
-- 2. Products table (POS catalog)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.products (
  id           uuid          NOT NULL DEFAULT gen_random_uuid(),
  business_id  uuid          NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name         text          NOT NULL,
  brand        text,
  price        numeric(10,2) NOT NULL,
  photo_url    text          NOT NULL,
  category     text          NOT NULL,
  description  text,
  in_stock     boolean       NOT NULL DEFAULT true,
  created_at   timestamptz   NOT NULL DEFAULT now(),
  updated_at   timestamptz   NOT NULL DEFAULT now(),

  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_price_positive CHECK (price > 0),
  CONSTRAINT products_category_check CHECK (
    category IN (
      'perfume', 'lipstick', 'powder', 'serums', 'cleansers',
      'shampoo', 'scrubs', 'moisturisers', 'body_wash', 'foundation'
    )
  )
);

COMMENT ON TABLE  public.products              IS 'Beauty products listed for sale by salons in the marketplace';
COMMENT ON COLUMN public.products.brand        IS 'Manufacturer/brand name for cross-salon product recognition';
COMMENT ON COLUMN public.products.category     IS 'Product category from 10 TikTok beauty starter categories';
COMMENT ON COLUMN public.products.in_stock     IS 'Simple stock toggle — no inventory counting';

CREATE INDEX IF NOT EXISTS idx_products_business_id
  ON public.products(business_id);

CREATE INDEX IF NOT EXISTS idx_products_category_stock
  ON public.products(category)
  WHERE in_stock = true;

CREATE TRIGGER products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Products: anyone can read in-stock from POS-enabled businesses"
  ON public.products FOR SELECT
  USING (
    in_stock = true
    AND EXISTS (
      SELECT 1 FROM public.businesses
      WHERE id = products.business_id
        AND pos_enabled = true
        AND is_active = true
    )
  );

CREATE POLICY "Products: owner can select own"
  ON public.products FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = products.business_id AND owner_id = auth.uid()
  ));

CREATE POLICY "Products: owner can insert"
  ON public.products FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = products.business_id AND owner_id = auth.uid()
  ));

CREATE POLICY "Products: owner can update"
  ON public.products FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = products.business_id AND owner_id = auth.uid()
  ));

CREATE POLICY "Products: owner can delete"
  ON public.products FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = products.business_id AND owner_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- 3. Product showcases (standalone product posts for the feed)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.product_showcases (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  business_id  uuid        NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  product_id   uuid        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  caption      text,
  created_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT product_showcases_pkey PRIMARY KEY (id)
);

COMMENT ON TABLE public.product_showcases IS 'Standalone product announcements that appear in the inspiration feed';

CREATE INDEX IF NOT EXISTS idx_showcases_business_id
  ON public.product_showcases(business_id);

CREATE INDEX IF NOT EXISTS idx_showcases_created_at
  ON public.product_showcases(created_at DESC);

ALTER TABLE public.product_showcases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Showcases: anyone can read from active businesses"
  ON public.product_showcases FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = product_showcases.business_id AND is_active = true
  ));

CREATE POLICY "Showcases: owner can insert"
  ON public.product_showcases FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = product_showcases.business_id AND owner_id = auth.uid()
  ));

CREATE POLICY "Showcases: owner can delete"
  ON public.product_showcases FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = product_showcases.business_id AND owner_id = auth.uid()
  ));

-- ---------------------------------------------------------------------------
-- 4. Orders table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.orders (
  id                       uuid          NOT NULL DEFAULT gen_random_uuid(),
  buyer_id                 uuid          NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  business_id              uuid          NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  product_id               uuid          REFERENCES public.products(id) ON DELETE SET NULL,
  product_name             text          NOT NULL,
  quantity                 integer       NOT NULL DEFAULT 1,
  total_amount             numeric(10,2) NOT NULL,
  commission_amount        numeric(10,2) NOT NULL,
  stripe_payment_intent_id text,
  status                   text          NOT NULL DEFAULT 'paid',
  shipping_address         jsonb,
  shipped_at               timestamptz,
  delivered_at             timestamptz,
  refunded_at              timestamptz,
  created_at               timestamptz   NOT NULL DEFAULT now(),
  updated_at               timestamptz   NOT NULL DEFAULT now(),

  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_status_check CHECK (
    status IN ('paid', 'shipped', 'delivered', 'refunded', 'cancelled')
  ),
  CONSTRAINT orders_amount_positive CHECK (total_amount > 0),
  CONSTRAINT orders_commission_positive CHECK (commission_amount >= 0)
);

COMMENT ON TABLE  public.orders                          IS 'Product purchase orders from the marketplace';
COMMENT ON COLUMN public.orders.product_name             IS 'Denormalized product name preserved even if product is deleted';
COMMENT ON COLUMN public.orders.commission_amount        IS 'BeautyCita commission (10% flat)';
COMMENT ON COLUMN public.orders.shipping_address         IS 'JSON: {street, city, state, zip, country, phone}';

CREATE INDEX IF NOT EXISTS idx_orders_buyer
  ON public.orders(buyer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_business
  ON public.orders(business_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_pending
  ON public.orders(status, created_at)
  WHERE status IN ('paid', 'shipped');

CREATE TRIGGER orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Buyer can read their own orders
CREATE POLICY "Orders: buyer can read own"
  ON public.orders FOR SELECT
  TO authenticated
  USING (auth.uid() = buyer_id);

-- Business owner can read orders for their business
CREATE POLICY "Orders: business can read own"
  ON public.orders FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = orders.business_id AND owner_id = auth.uid()
  ));

-- Business owner can update order status (mark shipped, etc.)
CREATE POLICY "Orders: business can update own"
  ON public.orders FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = orders.business_id AND owner_id = auth.uid()
  ));

-- Service role for edge functions (create orders, auto-refund)
CREATE POLICY "Orders: service role full access"
  ON public.orders FOR ALL
  TO service_role
  USING (true);

-- ---------------------------------------------------------------------------
-- 5. Feed engagement tracking
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.feed_engagement (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  content_type text        NOT NULL,
  content_id   uuid        NOT NULL,
  action       text        NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT feed_engagement_pkey PRIMARY KEY (id),
  CONSTRAINT feed_engagement_type_check CHECK (content_type IN ('photo', 'showcase')),
  CONSTRAINT feed_engagement_action_check CHECK (action IN ('view', 'save', 'product_tap'))
);

COMMENT ON TABLE public.feed_engagement IS 'Tracks user interactions with feed content for ranking algorithm';

CREATE INDEX IF NOT EXISTS idx_engagement_content
  ON public.feed_engagement(content_type, content_id);

CREATE INDEX IF NOT EXISTS idx_engagement_user_recent
  ON public.feed_engagement(user_id, created_at DESC);

-- Aggregate index for scoring queries
CREATE INDEX IF NOT EXISTS idx_engagement_scoring
  ON public.feed_engagement(content_id, action);

ALTER TABLE public.feed_engagement ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Engagement: user can insert own"
  ON public.feed_engagement FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Engagement: service role reads"
  ON public.feed_engagement FOR SELECT
  TO service_role
  USING (true);

-- ---------------------------------------------------------------------------
-- 6. Feed saves
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.feed_saves (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  content_type text        NOT NULL,
  content_id   uuid        NOT NULL,
  saved_at     timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT feed_saves_pkey PRIMARY KEY (id),
  CONSTRAINT feed_saves_unique UNIQUE (user_id, content_type, content_id),
  CONSTRAINT feed_saves_type_check CHECK (content_type IN ('photo', 'product', 'showcase'))
);

COMMENT ON TABLE public.feed_saves IS 'User-saved feed items (heart/bookmark). Single flat list per user.';

CREATE INDEX IF NOT EXISTS idx_saves_user_recent
  ON public.feed_saves(user_id, saved_at DESC);

ALTER TABLE public.feed_saves ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Saves: user can select own"
  ON public.feed_saves FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Saves: user can insert own"
  ON public.feed_saves FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Saves: user can delete own"
  ON public.feed_saves FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Service role for feed scoring queries
CREATE POLICY "Saves: service role reads"
  ON public.feed_saves FOR SELECT
  TO service_role
  USING (true);

-- ---------------------------------------------------------------------------
-- 7. POS agreements
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pos_agreements (
  id                uuid        NOT NULL DEFAULT gen_random_uuid(),
  business_id       uuid        NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  agreement_type    text        NOT NULL,
  agreement_version text        NOT NULL,
  accepted_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT pos_agreements_pkey PRIMARY KEY (id),
  CONSTRAINT pos_agreements_unique UNIQUE (business_id, agreement_type, agreement_version)
);

COMMENT ON TABLE public.pos_agreements IS 'Records of POS seller agreements accepted by business owners';

CREATE INDEX IF NOT EXISTS idx_pos_agreements_business
  ON public.pos_agreements(business_id);

ALTER TABLE public.pos_agreements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "POS agreements: owner can select own"
  ON public.pos_agreements FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = pos_agreements.business_id AND owner_id = auth.uid()
  ));

CREATE POLICY "POS agreements: owner can insert"
  ON public.pos_agreements FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.businesses
    WHERE id = pos_agreements.business_id AND owner_id = auth.uid()
  ));
