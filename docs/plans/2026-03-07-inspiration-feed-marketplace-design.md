# BeautyCita Inspiration Feed + Marketplace — Design Specification

**Date:** 2026-03-07
**Status:** Approved
**Author:** BC + Claude

## Overview

Two interconnected systems sharing the same UI surface:

1. **Inspiration Feed** — A global, scrollable feed of beauty transformations (portfolio photos) and product showcases. Lives as a dedicated bottom nav tab in mobile, dedicated page on web. Content ranked by hybrid algorithm (freshness boost + engagement weight).

2. **POS Marketplace** — Optional per-salon product catalog. Products tagged on photos become shoppable inline in the feed. Orders flow through Stripe Connect with 10% commission. Fulfillment is salon-ships with a 14-day auto-refund safety net.

**Data flow:** Stylist takes photo → tags products → photo appears in feed → user taps product → buys → salon ships → BeautyCita takes 10%.

**Key rule:** NO booking from the feed. Feed is inspiration + shopping only. Booking stays in the intelligent agent flow.

---

## 1. Feed Tab (Mobile)

- New bottom nav tab with explore/compass icon
- Full-screen vertical scroll, card-based layout
- Each card: photo (before/after slider or single), salon name + avatar, staff name, service category tag, caption, heart (save) button, product tags (tappable pills)
- Pull to refresh, infinite scroll with pagination
- Filter chips at top: All, Hair, Nails, Makeup, Lashes, etc. (from service categories)
- No booking button anywhere in the feed
- Touch-only, one-thumb operable (consistent with app UX model)

## 2. Feed Page (Web)

- Masonry grid layout, desktop-first
- Same content as mobile, different layout (NOT copied from mobile)
- Sidebar filters (categories, sort by)
- Click photo → expanded view with details + products
- Responsive: stacks to single column on narrow screens

## 3. Content Types

Two types of posts in the feed:

1. **Portfolio photos** — from the camera flow, before/after or after-only, with optional product tags. These are the primary content. Source: `portfolio_photos` table where `is_visible = true` and business has `portfolio_public = true`.

2. **Product showcases** — standalone product photo + description, posted by salon from POS management. Marked with a "Producto" badge in the feed. Source: `product_showcases` table.

## 4. Ranking Algorithm

- **Freshness boost**: Content < 72 hours gets a score multiplier (2x decaying linearly to 1x at 72h)
- **Engagement signals**: saves, detail views, product taps. Tracked in `feed_engagement` table.
- **Quality signals**: business average_rating, staff average_rating, portfolio photo count
- **Score formula**: `(engagement_score + freshness_boost) * quality_multiplier`
- At launch with no engagement data, effectively recency-first. Algorithm improves organically.
- Feed is GLOBAL — users see content from all cities/countries

## 5. Saves

- Heart icon on every feed card, single tap to save/unsave
- Single flat "Saved" list accessible from profile
- `feed_saves` table: user_id, content_type ('photo' or 'product'), content_id, saved_at
- Saved items grid view, tap opens full card
- No collections at launch — add later when users accumulate 50+ saves

## 6. Engagement Tracking

- `feed_engagement` table: user_id, content_type, content_id, action ('view', 'save', 'product_tap'), created_at
- "View" = card fully visible for 2+ seconds (client-side detection)
- "Save" = heart tapped
- "Product tap" = product pill tapped (opens detail)
- Aggregated daily into `feed_scores` materialized view for ranking queries

## 7. POS Product Catalog

### Opt-in
- Toggle in business settings: "Vender productos"
- Requires accepting POS Seller Agreement before enabling
- When disabled, existing products hidden but not deleted

### Product fields
- `name` (text, required)
- `brand` (text, optional) — manufacturer/brand name for recognition across salons
- `price` (numeric, required, MXN)
- `photo_url` (text, required) — product image
- `category` (text, required) — one of 10 starter categories
- `description` (text, optional)
- `in_stock` (boolean, default true) — simple toggle, no inventory counting
- No variants (size, color), no SKUs, no inventory counts

### 10 Product Categories (from TikTok beauty top sellers)
1. Perfume
2. Lipstick & Lip Gloss
3. Powder
4. Serums & Essences
5. Facial Cleansers
6. Shampoo & Conditioner
7. Body Scrubs & Peels
8. Moisturisers & Mists
9. Body Wash & Soap
10. Concealer & Foundation

### Product-Photo Connection
- At capture time: camera flow prompts for product tags
- Retroactively: portfolio management screen allows editing product tags on existing photos
- `product_tags` jsonb on `portfolio_photos` stores array of product IDs
- Both paths produce identical display in the feed

## 8. Product in Feed

- Photos with `product_tags` show tappable pills below the image
- Each pill: product name + price
- Tap pill → product detail bottom sheet:
  - Product photo, name, brand, price
  - Salon name + avatar
  - "Comprar" button
  - "In stock" / "Agotado" status
- Product showcases (standalone posts) show the product directly as the card content

## 9. Checkout Flow

- "Comprar" → Stripe payment intent via `create-product-payment` edge function
- `application_fee_amount` = 10% flat commission
- Payment methods: card, OXXO (same as bookings, via Stripe)
- On success → order created in `orders` table
- Buyer sees confirmation with estimated shipping info

## 10. Order Flow & Notifications

| Day | Action |
|-----|--------|
| 0 | Order paid. Instant push + email to salon: "Nuevo pedido: [product]" |
| 0 | Buyer sees order confirmation |
| — | Salon marks as shipped → buyer gets push + email with tracking (optional) |
| 3 | No shipment → follow-up push to salon: "Pedido pendiente de envio" |
| 7 | No shipment → escalation push + email: "Envia o se reembolsara en 7 dias" |
| 14 | No shipment → auto-refund to buyer. Order status → `refunded` |

### Order Statuses
- `paid` — payment received, awaiting shipment
- `shipped` — salon confirmed shipment
- `delivered` — buyer confirmed receipt (optional)
- `refunded` — auto-refunded (14 days) or manually refunded
- `cancelled` — cancelled before shipment

## 11. POS Seller Agreement

Required before enabling POS. Version-tracked like portfolio agreement. Covers:
- Shipping responsibility: salon packs and ships within 14 days
- Product accuracy: photos and descriptions must match actual product
- Quality standards: no expired, damaged, or counterfeit products
- Auto-refund acknowledgment: unfulfilled orders refunded at day 14
- Prohibited items: no controlled substances, no prescription products, no weapons
- Commission: 10% on all sales
- Returns: salon sets own return policy, displayed at checkout

## 12. Database Schema (New Tables)

### products
- id, business_id, name, brand, price, photo_url, category, description, in_stock, created_at

### product_showcases
- id, business_id, product_id, caption, created_at

### orders
- id, buyer_id, business_id, product_id, quantity (default 1), total_amount, commission_amount, stripe_payment_intent_id, status, shipping_address (jsonb), shipped_at, delivered_at, refunded_at, created_at

### feed_engagement
- id, user_id, content_type, content_id, action, created_at

### feed_saves
- id, user_id, content_type, content_id, saved_at (unique on user_id + content_type + content_id)

### pos_agreements
- id, business_id, agreement_type, agreement_version, accepted_at

## 13. Edge Functions (New)

- `feed-public` — paginated feed query with ranking, filters, engagement tracking
- `create-product-payment` — Stripe payment intent for product purchase
- `product-payment-webhook` — Stripe webhook for product payments (order creation)
- `order-followup` — scheduled function for 3/7/14 day notifications + auto-refund

## 14. URL Structure

- Mobile: bottom nav tab (no URL, native navigation)
- Web feed: `beautycita.com/inspiracion` (or `/feed`)
- Web product detail: modal/overlay, no separate URL needed

## 15. Future Integration Points

- **Product tags → POS**: Already wired via `product_tags` jsonb on portfolio_photos
- **Feed → Portfolio**: Tap salon name in feed → opens their portfolio page (`/p/slug`)
- **Collections**: Add named save folders when users accumulate enough saves
- **AR Try-On**: LightX integration could let users "try" a look from the feed
- **Variants**: Add size/color variants to products table when needed
