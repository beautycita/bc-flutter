# Web Reservar Page Design

**Date:** 2026-03-02
**Status:** Approved
**Project:** beautycita_web

---

## Overview

The `/reservar` route is the client-facing booking flow for the BeautyCita web app. It implements the intelligent booking agent concept adapted for desktop-first web UX: a progressive single-page flow where sections reveal as the user makes choices, with a persistent summary sidebar.

## Architecture Rules

- Desktop-first, responsive down to mobile
- Built from scratch for web — no mobile screen reuse
- Shares only: data models, theme constants, Supabase client (via beautycita_core)
- Same design language (Rose & Gold palette, Poppins/Nunito fonts), different UX patterns

## Layout

- **Desktop (>=1200px):** Two columns — active step (60%) | summary sidebar (40%)
- **Tablet (800-1200px):** Same but 55/45 split
- **Mobile (<800px):** Full-width steps + sticky bottom bar (selected service + price + "Continuar")

## Flow Steps

### Step 1: Category Grid

- 7 service categories as large clickable cards
- Responsive grid: 4 across (desktop), 3 (tablet), 2 (mobile)
- Each card: category icon + Spanish name + subtle category color from palette
- Tapping animates subcategory chips into view

### Step 2: Subcategory + Service Selection

- Horizontal scrollable chip row for subcategories
- Below: service items as selectable list tiles (name + typical price range + duration)
- Selecting a service triggers engine to check for follow-up questions via service profile

### Step 3: Follow-up Questions (conditional, 0-3)

- Visual cards for each question (per FollowUpQuestion model)
- Types: visual_cards (image grid), date_picker, yes_no
- Skipped entirely if service profile has max_follow_up_questions = 0

### Step 4: Results

**Path A — Registered salons available (next 48hrs):**

- 3 curated result cards, stacked vertically
- Each card: salon photo, name, stylist name + avatar, rating + review count, service price, best slot (date + time), travel time estimate (assumes car), review snippet
- Big "RESERVAR" button on each card
- Below cards: "Ver mas salones cerca de ti" link -> transitions to Path B

**Path B — No registered salons available (or user tapped "see more"):**

- WhatsApp-style list of discovered salons nearby (from discovered_salons table)
- Each row: salon name, address, phone, WA verified badge (if applicable)
- "Invitar" button on each -> sends WA invite via BeautyCita WA API on user's behalf
- Header: "Estos salones aun no estan en BeautyCita. Invitalos!"
- Only shown when no registered salons have open slots in next 48hrs, OR user explicitly asks to see more

### Step 5: Booking Confirmation + Payment

- Full summary: service, salon, stylist, date/time, price
- Stripe.js Elements embedded card form (card number, expiry, CVC)
- OXXO as alternative payment tab
- "Confirmar y Pagar" button
- Creates payment intent via create-payment-intent edge function
- Confirms payment via Stripe.js
- On success: animated confirmation with booking ID, salon contact info

### Step 6: Post-Booking Transport

- "Como llegaras?" with 3 options: Carro / Uber / Transporte Publico
- If Uber: prompt to connect Uber account, schedule round-trip
- If Car: show Google Maps directions link
- If Transit: show transit summary
- Updates appointment record with transport_mode

## Summary Sidebar

Builds progressively as user makes choices:

1. Selected category + service (after step 2)
2. Follow-up answers if any (after step 3)
3. Selected salon + stylist (after step 4)
4. Date/time (after step 4)
5. Price breakdown (after step 4)

Each item slides in with subtle animation. On mobile, this collapses into a sticky bottom bar showing current selection + price + action button.

## Authentication

- Steps 1-4: fully accessible without auth (browse freely)
- Step 5 (payment): if not authenticated, show inline phone verification
  - Enter phone number -> receive SMS code -> verify
  - Minimal friction, no full registration page
  - Phone number becomes the user's primary identifier

## Data Flow

| Step | Data Source | Method |
|------|-----------|--------|
| 1-2 | service_categories_tree + service_profiles | Fetch once on page load, cache client-side |
| 3 | service_profiles.max_follow_up_questions + follow_up_questions table | Fetched when service selected |
| 4A | curate edge function | POST with service_type + location + follow-up answers. Engine assumes transport_mode=car. Returns 3 ResultCards or empty |
| 4B | discovered_salons table | Query by location + category when no registered results |
| 5 | create-payment-intent edge function | POST with appointment details. Returns client_secret for Stripe.js |
| 6 | appointments table | UPDATE transport_mode after booking |

## Engine Assumptions

- Transport mode defaults to "car" for ranking/travel time calculations
- Time is inferred (no calendar picker) — engine uses current time + day + service profile's typical_lead_time
- Search radius from service profile, auto-expands if < 3 results
- Location: browser geolocation API (prompt user), fallback to IP geolocation

## Stripe Web Integration

- flutter_stripe does NOT work on Flutter web
- Use Stripe.js via dart:js_interop or url_launcher for Stripe Checkout
- Preferred: Stripe.js Elements embedded directly in the page
- Load Stripe.js script in web/index.html
- Create Dart interop wrapper to mount card element and confirm payment
- Edge functions (create-payment-intent, stripe-webhook) are shared with mobile — no changes needed

## Technical Notes

- New files go in beautycita_web/lib/pages/client/
- State management: Riverpod providers
- Router: add sub-routes under /reservar if needed, or manage steps with internal state
- Responsive: use LayoutBuilder + WebBreakpoints
- Theme: use buildWebTheme(palette) with Rose & Gold palette
- Location: request browser geolocation, cache in provider
