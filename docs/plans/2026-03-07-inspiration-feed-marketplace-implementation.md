# Inspiration Feed + Marketplace Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a global inspiration feed (bottom nav tab) with inline product shopping, POS product catalog, order management, and engagement tracking.

**Architecture:** Feed queries public portfolio_photos + product_showcases via a ranked edge function. POS uses Stripe Connect for payments. Orders tracked with automated notification pipeline. Engagement data feeds ranking algorithm.

**Tech Stack:** Flutter (mobile + web), Supabase (DB + Storage + Edge Functions + Scheduled), Stripe Connect (payments), Riverpod (state), vanilla HTML/CSS for any public pages.

---

## Task 1: Database Migration — Products, Orders, Feed Tables

**Files:**
- Create: `beautycita_app/supabase/migrations/20260307100000_feed_marketplace.sql`

**Step 1: Write migration**

```sql
-- =========================================================================
-- Feed + Marketplace: products, orders, engagement, saves, showcases
-- =========================================================================

-- 1. Products table (POS catalog)
CREATE TABLE IF NOT EXISTS public.products (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  business_id  uuid        NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name         text        NOT NULL,
  brand        text,
  price        numeric(10,2) NOT NULL,
  photo_url    text        NOT NULL,
  category     text        NOT NULL,
  description  text,
  in_stock     boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_category_check CHECK (
    category IN (
      'perfume', 'lipstick', 'powder', 'serums', 'cleansers',
      'shampoo', 'scrubs', 'moisturisers', 'body_wash', 'foundation'
    )
  )
);

CREATE INDEX idx_products_business ON public.products(business_id);
CREATE INDEX idx_products_category ON public.products(category) WHERE in_stock = true;

CREATE TRIGGER products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Products: anyone can read in-stock"
  ON public.products FOR SELECT
  USING (in_stock = true);

CREATE POLICY "Products: owner can manage"
  ON public.products FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses WHERE id = products.business_id AND owner_id = auth.uid()
  ));

-- 2. POS enabled flag on businesses
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS pos_enabled boolean NOT NULL DEFAULT false;

-- 3. Product showcases (standalone product posts for the feed)
CREATE TABLE IF NOT EXISTS public.product_showcases (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  business_id  uuid        NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  product_id   uuid        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  caption      text,
  created_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT product_showcases_pkey PRIMARY KEY (id)
);

CREATE INDEX idx_showcases_business ON public.product_showcases(business_id);
CREATE INDEX idx_showcases_created ON public.product_showcases(created_at DESC);

ALTER TABLE public.product_showcases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Showcases: anyone can read"
  ON public.product_showcases FOR SELECT USING (true);

CREATE POLICY "Showcases: owner can manage"
  ON public.product_showcases FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses WHERE id = product_showcases.business_id AND owner_id = auth.uid()
  ));

-- 4. Orders table
CREATE TABLE IF NOT EXISTS public.orders (
  id                      uuid        NOT NULL DEFAULT gen_random_uuid(),
  buyer_id                uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  business_id             uuid        NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  product_id              uuid        NOT NULL REFERENCES public.products(id) ON DELETE SET NULL,
  product_name            text        NOT NULL,
  quantity                integer     NOT NULL DEFAULT 1,
  total_amount            numeric(10,2) NOT NULL,
  commission_amount       numeric(10,2) NOT NULL,
  stripe_payment_intent_id text,
  status                  text        NOT NULL DEFAULT 'paid',
  shipping_address        jsonb,
  shipped_at              timestamptz,
  delivered_at            timestamptz,
  refunded_at             timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT orders_pkey PRIMARY KEY (id),
  CONSTRAINT orders_status_check CHECK (
    status IN ('paid', 'shipped', 'delivered', 'refunded', 'cancelled')
  )
);

CREATE INDEX idx_orders_buyer ON public.orders(buyer_id, created_at DESC);
CREATE INDEX idx_orders_business ON public.orders(business_id, created_at DESC);
CREATE INDEX idx_orders_status ON public.orders(status) WHERE status IN ('paid', 'shipped');

CREATE TRIGGER orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Orders: buyer can read own"
  ON public.orders FOR SELECT
  TO authenticated
  USING (auth.uid() = buyer_id);

CREATE POLICY "Orders: business can read own"
  ON public.orders FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses WHERE id = orders.business_id AND owner_id = auth.uid()
  ));

CREATE POLICY "Orders: business can update own"
  ON public.orders FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses WHERE id = orders.business_id AND owner_id = auth.uid()
  ));

-- 5. Feed engagement tracking
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

CREATE INDEX idx_engagement_content ON public.feed_engagement(content_type, content_id);
CREATE INDEX idx_engagement_user ON public.feed_engagement(user_id, created_at DESC);

ALTER TABLE public.feed_engagement ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Engagement: user can insert own"
  ON public.feed_engagement FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Engagement: service role reads"
  ON public.feed_engagement FOR SELECT
  TO service_role
  USING (true);

-- 6. Feed saves
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

CREATE INDEX idx_saves_user ON public.feed_saves(user_id, saved_at DESC);

ALTER TABLE public.feed_saves ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Saves: user can manage own"
  ON public.feed_saves FOR ALL
  TO authenticated
  USING (auth.uid() = user_id);

-- 7. POS agreements (same pattern as portfolio_agreements)
CREATE TABLE IF NOT EXISTS public.pos_agreements (
  id                uuid        NOT NULL DEFAULT gen_random_uuid(),
  business_id       uuid        NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  agreement_type    text        NOT NULL,
  agreement_version text        NOT NULL,
  accepted_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT pos_agreements_pkey PRIMARY KEY (id),
  CONSTRAINT pos_agreements_unique UNIQUE (business_id, agreement_type, agreement_version)
);

ALTER TABLE public.pos_agreements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "POS agreements: owner can manage"
  ON public.pos_agreements FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.businesses WHERE id = pos_agreements.business_id AND owner_id = auth.uid()
  ));
```

**Step 2: Commit**

```bash
git add beautycita_app/supabase/migrations/20260307100000_feed_marketplace.sql
git commit -m "feat: feed + marketplace DB migration — products, orders, engagement, saves"
```

---

## Task 2: Data Models in beautycita_core

**Files:**
- Create: `packages/beautycita_core/lib/src/models/product.dart`
- Create: `packages/beautycita_core/lib/src/models/order.dart`
- Create: `packages/beautycita_core/lib/src/models/feed_item.dart`
- Create: `packages/beautycita_core/lib/src/models/product_showcase.dart`
- Modify: `packages/beautycita_core/lib/models.dart` (barrel exports)

### Product model
```dart
class Product {
  final String id;
  final String businessId;
  final String name;
  final String? brand;
  final double price;
  final String photoUrl;
  final String category;
  final String? description;
  final bool inStock;
  final DateTime createdAt;
  // + fromJson, toJson
}
```

### Order model
```dart
class Order {
  final String id;
  final String buyerId;
  final String businessId;
  final String? productId;
  final String productName;
  final int quantity;
  final double totalAmount;
  final double commissionAmount;
  final String? stripePaymentIntentId;
  final String status; // paid, shipped, delivered, refunded, cancelled
  final Map<String, dynamic>? shippingAddress;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? refundedAt;
  final DateTime createdAt;
  // + fromJson, toJson
}
```

### FeedItem model (unified feed card)
```dart
class FeedItem {
  final String id;
  final String type; // 'photo' or 'showcase'
  final String businessId;
  final String businessName;
  final String? businessPhotoUrl;
  final String? staffName;
  final String? beforeUrl;
  final String afterUrl;
  final String? caption;
  final String? serviceCategory;
  final List<FeedProductTag> productTags;
  final int saveCount;
  final bool isSaved; // by current user
  final DateTime createdAt;
  // + fromJson
}

class FeedProductTag {
  final String productId;
  final String name;
  final String? brand;
  final double price;
  final String photoUrl;
  final bool inStock;
  // + fromJson
}
```

### ProductShowcase model
```dart
class ProductShowcase {
  final String id;
  final String businessId;
  final String productId;
  final String? caption;
  final DateTime createdAt;
  // + fromJson, toJson
}
```

**Commit:**
```bash
git add packages/beautycita_core/
git commit -m "feat: feed + marketplace data models — Product, Order, FeedItem, ProductShowcase"
```

---

## Task 3: Feed Public API (Edge Function)

**Files:**
- Create: `beautycita_app/supabase/functions/feed-public/index.ts`

Endpoint: `GET /feed-public?page=0&limit=20&category=hair`

Returns paginated feed items ranked by hybrid algorithm:
1. Query visible portfolio_photos from public businesses + product_showcases
2. Join business info (name, photo_url)
3. Join staff info (first_name)
4. Left join products for product_tags resolution
5. Left join feed_saves for current user's save status (via auth header, optional)
6. Calculate score: freshness_boost * (1 + save_count * 0.1 + view_count * 0.01) * quality_multiplier
7. Order by score DESC, paginate
8. Return array of FeedItem-shaped JSON

Auth is optional — anonymous users see feed without save status.

**Commit:**
```bash
git add beautycita_app/supabase/functions/feed-public/
git commit -m "feat: feed API — paginated ranked feed with engagement scoring"
```

---

## Task 4: Product Service + Providers (Mobile)

**Files:**
- Create: `beautycita_app/lib/services/product_service.dart`
- Create: `beautycita_app/lib/providers/product_provider.dart`

ProductService: CRUD for products, toggle POS, accept agreement.
ProductProvider: productsProvider (by businessId), posEnabledProvider, posAgreementProvider.

**Commit:**
```bash
git add beautycita_app/lib/services/product_service.dart beautycita_app/lib/providers/product_provider.dart
git commit -m "feat: product service + providers — CRUD, POS toggle, agreement"
```

---

## Task 5: Feed Service + Providers (Mobile)

**Files:**
- Create: `beautycita_app/lib/services/feed_service.dart`
- Create: `beautycita_app/lib/providers/feed_provider.dart`

FeedService: fetchFeed (paginated), toggleSave, trackEngagement, fetchSaved.
FeedProvider: feedProvider (with category filter + pagination), savedItemsProvider, feedCategoryProvider.

**Commit:**
```bash
git add beautycita_app/lib/services/feed_service.dart beautycita_app/lib/providers/feed_provider.dart
git commit -m "feat: feed service + providers — paginated feed, saves, engagement"
```

---

## Task 6: Feed Screen (Mobile) — Bottom Nav Tab

**Files:**
- Create: `beautycita_app/lib/screens/feed/feed_screen.dart`
- Create: `beautycita_app/lib/screens/feed/feed_card.dart`
- Create: `beautycita_app/lib/screens/feed/product_detail_sheet.dart`
- Create: `beautycita_app/lib/screens/feed/saved_screen.dart`
- Modify: main navigation shell to add feed tab with explore icon

Feed screen: vertical ListView.builder with pull-to-refresh, infinite scroll pagination, category filter chips at top. Each card is a FeedCard widget with before/after slider (reuse pattern from portfolio themes), salon info, save button, product pills.

Product detail sheet: bottom sheet showing product photo, name, brand, price, salon, "Comprar" button.

Saved screen: grid of saved items, accessible from profile or feed header.

**Commit:**
```bash
git add beautycita_app/lib/screens/feed/
git commit -m "feat: feed screen — card layout, before/after slider, product pills, saves"
```

---

## Task 7: Feed Screen — Navigation Integration

**Files:**
- Modify: `beautycita_app/lib/screens/main_shell.dart` (or equivalent navigation shell)
- Modify: `beautycita_app/lib/config/routes.dart`

Add feed as a bottom nav tab. Update the shell to include the feed icon (Icons.explore_outlined) between Home and whatever the current second tab is. Add routes for /feed and /feed/saved.

**Commit:**
```bash
git add beautycita_app/lib/screens/ beautycita_app/lib/config/routes.dart
git commit -m "feat: feed bottom nav tab — explore icon, route integration"
```

---

## Task 8: POS Management Screen (Mobile)

**Files:**
- Create: `beautycita_app/lib/screens/business/pos_management_screen.dart`
- Modify: `beautycita_app/lib/screens/business/business_settings_screen.dart` (add POS entry)

POS management: product list with add/edit/delete, in_stock toggle, photo upload, category picker (10 categories), brand field. Product showcase posting (select product → add caption → post to feed).

Entry point: "Punto de Venta" card in business settings (only visible when pos_enabled or as opt-in prompt).

**Commit:**
```bash
git add beautycita_app/lib/screens/business/pos_management_screen.dart beautycita_app/lib/screens/business/business_settings_screen.dart
git commit -m "feat: POS management screen — product catalog + showcase posting"
```

---

## Task 9: Order Management Screen (Mobile)

**Files:**
- Create: `beautycita_app/lib/screens/business/orders_screen.dart`
- Create: `beautycita_app/lib/services/order_service.dart`
- Create: `beautycita_app/lib/providers/order_provider.dart`

For salon owners: list of orders (paid/shipped/delivered/refunded), mark as shipped button, order detail view.

For buyers: "Mis Compras" accessible from profile — order list, status tracking.

OrderService: fetchOrders, markShipped, requestRefund.

**Commit:**
```bash
git add beautycita_app/lib/screens/business/orders_screen.dart beautycita_app/lib/services/order_service.dart beautycita_app/lib/providers/order_provider.dart
git commit -m "feat: order management — salon orders + buyer purchase history"
```

---

## Task 10: Product Payment Edge Function

**Files:**
- Create: `beautycita_app/supabase/functions/create-product-payment/index.ts`
- Modify: `beautycita_app/supabase/functions/stripe-webhook/index.ts` (add product payment handling)

create-product-payment: Creates Stripe PaymentIntent with application_fee_amount (10%). Takes product_id, shipping_address. Returns client_secret.

stripe-webhook: On payment_intent.succeeded for product payments, create order row with status 'paid', send push notification + email to salon.

**Commit:**
```bash
git add beautycita_app/supabase/functions/create-product-payment/ beautycita_app/supabase/functions/stripe-webhook/
git commit -m "feat: product payment — Stripe Connect with 10% commission + order creation"
```

---

## Task 11: Order Follow-up Edge Function (Scheduled)

**Files:**
- Create: `beautycita_app/supabase/functions/order-followup/index.ts`

Scheduled function (runs daily or via cron):
- Day 3: Query orders WHERE status='paid' AND created_at < now()-3days → send follow-up push
- Day 7: Query orders WHERE status='paid' AND created_at < now()-7days → send escalation push+email
- Day 14: Query orders WHERE status='paid' AND created_at < now()-14days → trigger Stripe refund, set status='refunded', notify buyer

**Commit:**
```bash
git add beautycita_app/supabase/functions/order-followup/
git commit -m "feat: order follow-up — 3/7/14 day notifications + auto-refund"
```

---

## Task 12: POS Seller Agreement

**Files:**
- Create: `beautycita_app/lib/screens/business/pos_agreement_dialog.dart`

Same pattern as portfolio_agreement_dialog.dart. Spanish legal text covering shipping, quality, auto-refund, prohibited items, 10% commission. Checkbox + accept. Stored in pos_agreements table.

**Commit:**
```bash
git add beautycita_app/lib/screens/business/pos_agreement_dialog.dart
git commit -m "feat: POS seller agreement — required before enabling product sales"
```

---

## Task 13: Feed Page (Web)

**Files:**
- Create: `beautycita_web/lib/pages/client/feed_page.dart`
- Modify: `beautycita_web/lib/config/router.dart` (add route)
- Modify: navigation (add feed link)

Desktop-first masonry grid. Same data source (feed-public API), different layout. Sidebar filters, click-to-expand photo detail with products. DO NOT copy from mobile.

**Commit:**
```bash
git add beautycita_web/lib/pages/client/feed_page.dart beautycita_web/lib/config/router.dart
git commit -m "feat: web feed page — masonry grid, filters, product details"
```

---

## Task 14: POS Management Page (Web)

**Files:**
- Create: `beautycita_web/lib/pages/business/biz_pos_page.dart`
- Modify: `beautycita_web/lib/config/router.dart`
- Modify: business shell nav

Desktop product catalog management. Same capabilities as mobile, desktop layout. DO NOT copy from mobile.

**Commit:**
```bash
git add beautycita_web/lib/pages/business/biz_pos_page.dart beautycita_web/lib/config/router.dart
git commit -m "feat: web POS management — desktop product catalog + orders"
```

---

## Task 15: Integration Testing + Polish

- Verify feed loads on mobile + web
- Verify product creation, tagging, and display in feed
- Verify checkout flow end-to-end
- Verify order notifications (mock)
- Verify saves persist and display
- Verify POS agreement gates product creation
- Fix any analyzer warnings
- Final commit

---

## Dependency Order

```
Task 1 (DB migration)
  └→ Task 2 (models)
       ├→ Task 3 (feed API)
       ├→ Task 4 (product service)
       └→ Task 5 (feed service)
            ├→ Task 6 (feed screen)
            │    └→ Task 7 (nav integration)
            ├→ Task 8 (POS management mobile)
            └→ Task 9 (order management)
       Task 4 → Task 10 (payment edge function)
       Task 10 → Task 11 (order follow-up)
       Task 12 (POS agreement) — after Task 4
       Task 13 (web feed) — after Task 3
       Task 14 (web POS) — after Task 4
       Task 15 (testing) — after all
```

Tasks 3, 4, 5 can run in parallel after Task 2.
Tasks 6, 8, 9, 12, 13, 14 can partially overlap after their dependencies.
