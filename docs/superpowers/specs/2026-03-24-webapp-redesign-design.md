# BeautyCita Web App Redesign — Design Spec

**Date:** 2026-03-24
**Status:** APPROVED by BC — "this design style and layout is very workable"
**Mockup:** beautycita.com/bc/webRebuild/

---

## Design System (Web)

### Foundation
- **Background:** #FFFAF5 (warm white)
- **Cards:** #FFFFFF, border: 1px solid #f0ebe6, radius: 16-20px, shadow: 0 2px 10px rgba(0,0,0,0.04)
- **Brand gradient:** linear-gradient(135deg, #ec4899, #9333ea, #3b82f6)
- **Text primary:** #1a1a1a
- **Text secondary:** #666
- **Text hint:** #999
- **Max content width:** 1200px centered
- **Section spacing:** 80-120px vertical
- **Font:** System stack (-apple-system, system-ui, sans-serif)
- **Icons:** Wireframe/outlined style only

### Typography
- Hero headlines: 48-56px, weight 800
- Section titles: 36-42px, weight 800
- Card titles: 18-20px, weight 700
- Body: 16-18px, weight 400, line-height 1.7
- Labels/small: 12-14px, weight 600
- Section labels: 12px, uppercase, letter-spacing 2px, gradient text

### Components
- **Filled CTA:** gradient background, white text, 16px radius, hover scale(1.02) + glow
- **Outlined CTA:** 2px border primary, transparent fill, hover fill with gradient
- **Feature cards:** white bg, border, subtle shadow, hover translateY(-4px)
- **Info rows:** 34x34 icon box (colored bg 8% opacity, radius 10) + label + value
- **Section headers:** small uppercase label above, large bold title below
- **Trust badges:** pill shape, gradient or outlined
- **Comparison table:** alternating row colors, highlighted BC column

### Transitions (3 types, used across all navigation)
1. **Sweep + Card Stagger** — gradient line sweeps, then content cards cascade in with delay. Use for: main navigation (settings → sub-page, portal switching)
2. **Radial Gradient Burst** — gradient glow expands from click point. Use for: opening detail views, modals, expanding cards
3. **Diagonal Slash** — angled gradient line cuts across. Use for: tab switches, filter changes, category transitions

### Animations
- Sections fade+slide in on scroll (IntersectionObserver / scroll controller)
- Cards lift on hover (translateY -4px, shadow deepens)
- CTAs glow on hover (box-shadow with gradient color)
- Staggered entry on page load (100ms delay per element)
- Smooth scroll between sections

---

## Information Architecture

### Public Pages (no auth)
```
/                    Landing page (the mockup)
/para-salones        Salon value proposition deep dive
/para-clientes       Client value proposition deep dive
/precios             Pricing comparison
/demo                Demo entry (phone capture → verification → embedded demo)
/soporte             Support / FAQ / Contact
/privacidad          Privacy policy
/terminos            Terms of service
/descargar           Download page (APK, QR, app stores)
/p/:slug             Salon portfolio pages (existing, keep)
/registro/:id        Salon registration flow
/invitar             Public invite page
```

### Auth Pages
```
/auth                Login (email/password + OAuth + QR)
/auth/register       Client signup
/auth/verify         Verification
/auth/forgot         Password reset
/auth/callback       OAuth callback
```

### Client Portal
```
/explorar            Feed / discovery (redesigned)
/reservar            Booking flow (redesigned from scratch)
/mis-citas           My bookings
/perfil              Profile (web version of mobile profile)
/preferencias        Preferences (web version)
/chat                Aphrodite AI + salon chat
```

### Business Portal (/negocio/*)
```
/negocio             Dashboard
/negocio/calendario  Calendar (drag & drop)
/negocio/servicios   Service catalog CRUD
/negocio/equipo      Staff management + analytics
/negocio/pagos       Payments & payouts
/negocio/pos         Point of sale
/negocio/pedidos     Product orders
/negocio/resenas     Reviews
/negocio/disputas    Disputes
/negocio/portfolio   Portfolio management
/negocio/ajustes     Business settings
/negocio/qr          QR walk-in codes
```

### Admin Portal (/admin/*)
Keep existing structure — 22 pages, just restyle with new design system.

### Demo Portal (/demo/*)
- Salon owner demo (existing, restyle)
- Client demo (NEW — needs building)

---

## Landing Page Sections (approved)

1. **Sticky Nav** — logo, links, language toggle, gradient CTA
2. **Hero** — split layout, headline, two CTAs, trust badges, phone mockup
3. **Comparison** — BC vs AgendaPro vs Booksy feature table
4. **For Salons** — 12 feature cards in grid
5. **Demo** — phone capture → WA verification → embedded demo
6. **For Clients** — 3 value prop cards + download CTA
7. **Testimonials** — 3 cards + trust metrics bar
8. **Pricing** — single $0/month card with competitor strikethrough
9. **Download** — gradient bg, app store buttons, QR, viral CTA
10. **Footer** — links, social, contact, legal

---

## Demo Funnel (WA-powered)

### Flow:
1. User enters phone number on website
2. Immediately: WA message with 6-digit verification code
3. User enters code → demo unlocks
4. User explores demo (salon dashboard or client booking flow)
5. On demo close (one-time): WA message with app download link + "forward to a friend" CTA
6. If phone not registered as app user after 24h: follow-up WA message — "X clients are searching for salons in your area. You're missing out. Download now."

### Edge Function: `demo-wa-funnel`
- POST /demo-wa-funnel with { phone, action: 'send_code' | 'verify' | 'close' | 'followup' }
- Stores: phone, verified_at, demo_opened_at, demo_closed_at, followup_sent_at
- 24h cron checks for unregistered verified phones → sends followup

---

## Client-Side Demo (NEW)

A read-only client experience showing:
- Category selection → service picker → follow-up questions → curated results
- Fake but realistic data (salons in PV with real-looking names, prices, ratings)
- "This is what your clients see" messaging for salon owners viewing it
- "Download the app to book for real" CTA at the end

---

## Booking Flow Redesign

The current 7-step flow is correct in logic but needs visual redesign:

1. **Category** — large visual grid (not a list), icons + gradient accents
2. **Service** — card selection with price ranges visible
3. **Follow-up** — visual card Q&A (time, preferences)
4. **Results** — top 3 curated cards with salon photo, rating, price, best slot, one-click book
5. **Payment** — Stripe card + OXXO + cash options, clear pricing breakdown
6. **Transport** — car/Uber/transit with map preview
7. **Confirmation** — success card with all details + add to calendar + share

Each step uses the **sweep + card stagger** transition.
Back navigation uses the transition in reverse.

---

## Portal Shells (restyled)

### Admin Shell
- Sidebar: 240px expanded / 64px collapsed
- Background: warm white (#FFFAF5)
- Sidebar bg: white with right border
- Active nav item: gradient left accent bar + light primary bg
- Icons: wireframe outlined
- Keyboard shortcuts preserved

### Business Shell
- Same sidebar pattern as admin
- Dashboard hero with gradient card (salon name, quick stats)

### Client Shell
- Horizontal top nav (not sidebar)
- Clean white bar with nav links + avatar
- Minimal — let the content breathe

---

## Implementation Order

### Phase 1: Foundation
- Web design system (theme, components, transitions)
- Landing page (from mockup → real Flutter)
- Demo WA funnel edge function

### Phase 2: Client Experience
- Client shell redesign
- Booking flow visual overhaul
- Feed/discovery page
- My bookings restyling

### Phase 3: Business Portal
- Business shell restyling
- Dashboard redesign
- Calendar + core pages

### Phase 4: Admin Portal
- Admin shell restyling
- All admin pages with new design system

### Phase 5: Polish
- Client-side demo
- Transitions on all navigation
- Final responsive testing
- Performance optimization

---

## Rules

- **NEVER copy mobile screen layouts** — desktop-first, designed for mouse+keyboard
- **Same colors, icons, logo** as mobile — visual identity is shared
- **Different layout, navigation, interaction patterns** — web has its own UX
- **Three transitions only:** sweep+stagger, radial burst, diagonal slash
- **All text in Spanish** (primary), English support via toggle
- **Warm minimal theme** throughout — no dark mode for initial launch
