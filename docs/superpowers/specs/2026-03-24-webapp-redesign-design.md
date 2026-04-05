# BeautyCita Web App Redesign — Design Spec

**Date:** 2026-03-24
**Status:** Structure finished (trimmed 2026-04-03). Open: promo material review + demo UX initiative.

---

## Design System

- `web_theme.dart` — exact spec tokens: #FFFAF5 background, brand gradient (pink→purple→blue 135°), system font stack
- Typography hierarchy: 48-56px displays, 36-42px headlines, 18-20px card titles, 16-18px body
- Components: gradient CTAs, outlined CTAs, feature cards with hover lift, info rows, trust badges
- Radial burst transition implemented for navigation

## Landing Page

All 10 sections built in `landing_page.dart` (4,352 lines):
Sticky nav, hero, comparison table, for-salons (12 cards), demo funnel, for-clients, testimonials, pricing, download CTA, footer. Scroll animations, hover effects, staggered entry.

## Auth Flow

6 pages with split-panel layout (brand left, form right on desktop):
Login (email/password + OAuth + WebAuthn), register, verify, forgot, callback.

## Client Portal

Horizontal top nav shell. Pages: reservar (7-step booking flow, 136KB, Stripe.js + OXXO), feed/discovery, mis citas, invite.

## Business Portal

Sidebar shell (240px/64px). 18 pages: dashboard, calendar (drag & drop), services, staff, payments, POS, orders, reviews, disputes, portfolio, settings, QR, analytics, banking, clients, gift cards, marketing, calendar-sync.

## Admin Portal

Sidebar shell. 26 pages restyled with design system.

## Information Architecture

Complete routing across 5 areas: public (12 routes), auth (6), client (6+), business (18), admin (26). All shells integrated with route guards.

## Salon Demo (existing)

Full read-only business portal at `/demo/*` with 11 routes, static "Salon de Vallarta" data, provider overrides. WA funnel for phone verification via `demo-wa-funnel` edge function.

## Open: Promo & Demo Quality Initiative

The structural rebuild is done. What remains is making the promo material and demos actually convert:

- **Landing page + sales content** — review the data, iterate copy/presentation toward perfection. Not a redesign, a quality pass driven by what the data says.
- **Salon demo UX overhaul** — the priority demo. Needs to feel flawless and intuitive. Add impactful overlays, grade UX quality, iterate. Users should want to use the tools.
- **Client-side demo** — show salon owners what their clients see (booking flow with fake controlled data). Not yet built.
