# BeautyCita Web App Rebuild — Design Specification

**Date:** 2026-02-25
**Author:** BC + Claude
**Status:** Approved

---

## Background

The previous web app was a Flutter web build that converted mobile screens to web pages. Despite multiple corrections, the approach kept drifting back to "mobile app in a browser." BC trashed the entire codebase. This is the clean rebuild.

**Core principle:** The web app and mobile app are siblings — same family, same DNA, completely independent lives. They share a database, a design language, and a shared Dart package of models/theme/Supabase config. Everything else is built from scratch for its target platform.

---

## Architecture

### Hybrid Approach

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Public SEO pages** | Static HTML/CSS | Google can't crawl Flutter web. Landing page, pricing, legal pages need SEO indexability. |
| **Authenticated app** | Flutter Web (WASM) | App-like experience, shared Dart ecosystem with mobile, Riverpod state management, same Supabase SDK. Desktop-first, responsive for mobile. |

### Project Structure

```
futureBeauty/
├── beautycita_app/              # Mobile app (UNTOUCHED)
├── beautycita_web/              # NEW Flutter web app (desktop-first, WASM)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── config/
│   │   │   └── router.dart
│   │   ├── shells/
│   │   │   ├── admin_shell.dart
│   │   │   ├── business_shell.dart
│   │   │   └── client_shell.dart
│   │   ├── pages/               # ALL built from scratch for desktop
│   │   │   ├── admin/
│   │   │   ├── business/
│   │   │   ├── client/
│   │   │   ├── auth/
│   │   │   └── error/
│   │   ├── widgets/
│   │   ├── providers/
│   │   ├── services/
│   │   └── repositories/
│   ├── web/
│   │   └── index.html
│   └── pubspec.yaml
│
├── packages/
│   └── beautycita_core/
│       ├── lib/
│       │   ├── models/          # Data classes only
│       │   ├── theme/           # Color/typography/spacing constants only
│       │   └── supabase/        # Client config + table names + query builders
│       └── pubspec.yaml
│
└── public/                      # Static SEO pages (served directly by Nginx)
    ├── index.html               # Landing page / homepage
    ├── registro/                # Salon registration
    ├── precios/                 # Pricing comparison vs competitors
    ├── contacto/                # Contact us
    ├── nosotros/                # About / mission
    ├── prensa/                  # Press
    ├── empleo/                  # Employment / careers
    ├── cookies/                 # Cookie policy
    ├── privacidad/              # Privacy policy
    ├── terminos/                # Terms of service
    └── assets/                  # Shared brand assets (logo, fonts, CSS)
```

### Hard Rules (enforced in CLAUDE.md)

1. NEVER import, copy, adapt, or reference any file from `beautycita_app/lib/screens/` into the web project.
2. NEVER put widgets, screens, pages, or ANY UI component in `beautycita_core`.
3. The web app is PC/Mac desktop-first. Every page starts as a desktop layout.
4. "Looks like the app" means same design language (colors, fonts, spacing), NOT same layouts or widget trees.
5. When building a web page, do NOT open the equivalent mobile screen for reference.
6. If the thought "I can reuse this screen from mobile" appears — STOP. Build it fresh.

---

## Shared Package: `beautycita_core`

### Contains

- **Models:** UserProfile, Business, Service, Appointment, DiscoveredSalon, ChatThread, ChatMessage, Review, Dispute, Notification, ServiceProfile, Category, CurateResult — all with `fromJson`/`toJson`
- **Theme constants:** BCPalette class, all 7 palette definitions (rose_gold, black_gold, glass, midnight_orchid, ocean_noir, cherry_blossom, emerald_luxe), color constants, font family names, spacing/radius values
- **Supabase:** Client initialization wrapper, table name constants, shared query builders

### Does NOT Contain

- Widgets, screens, pages, or any UI component
- ThemeData construction (each app builds its own ThemeData from the shared palette constants)
- Riverpod providers
- Navigation/routing
- Platform-specific code

### Extraction Process

1. Copy model files from mobile app into package, remove any Flutter UI imports
2. Copy palette color values into theme constants
3. Copy Supabase client init
4. Update mobile app imports to point at package
5. Verify mobile app still builds
6. Web app imports the same package

---

## Auth System

Same Supabase auth backend. Same users, sessions, JWT. Different UX.

### Auth Routes

| Route | Page | Notes |
|-------|------|-------|
| `/app/auth` | Login | Split layout — brand left, form right. Google/Apple OAuth + email/password |
| `/app/auth/register` | Register | Same split layout. Name, email, password or OAuth one-click |
| `/app/auth/verify` | Phone OTP | Same phone-verify edge function as mobile |
| `/app/auth/callback` | OAuth callback | Handles redirect, routes by role |
| `/app/auth/forgot` | Password reset | Email input, sends magic link |
| `/app/auth/qr` | QR link | Scan QR from mobile to auth web session |

### Post-Auth Routing

| User role | Redirect |
|-----------|----------|
| admin / superadmin | `/app/admin` |
| stylist / salon_owner | `/app/negocio` |
| client | `/app/reservar` (or `/app/mis-citas` if returning) |

No biometric auth on web — that's mobile-only.

---

## Admin Panel

BC's daily driver. Desktop-first, multi-panel layout with persistent sidebar.

### Layout

- **Persistent sidebar** — always visible, collapsible to icons on smaller screens
- **Master-detail pattern** — tables on left, clicking a row opens detail panel on right
- **Keyboard shortcuts** — `/` to search, `Esc` to close panels, arrow keys for tables
- **Bulk actions** — checkbox select, action bar at top
- **Realtime** — Supabase realtime for new bookings, disputes, signups

### Routes

| Route | Page | Function |
|-------|------|----------|
| `/app/admin` | Dashboard | KPI cards (revenue, users, bookings, salons), activity feed, alerts |
| `/app/admin/users` | Users | User table, search, filter by role, click → detail panel |
| `/app/admin/salons` | Salons | Registered + discovered, status filters, click → detail |
| `/app/admin/bookings` | Bookings | All appointments, date/status filters, click → detail |
| `/app/admin/services` | Services | Service catalog management, category tree |
| `/app/admin/disputes` | Disputes | Open disputes, resolution workflow |
| `/app/admin/finance` | Finance | Revenue, payouts, Stripe/BTCPay stats |
| `/app/admin/analytics` | Analytics | Charts — bookings, growth, revenue, geographic heatmap |
| `/app/admin/engine` | Engine | Intelligent booking engine tuning |
| `/app/admin/engine/profiles` | Service Profiles | Per-service weights, radius, thresholds, live preview |
| `/app/admin/engine/categories` | Category Tree | Service hierarchy editor |
| `/app/admin/engine/time` | Time Rules | Time inference per service type |
| `/app/admin/outreach` | Outreach | Discovered salons pipeline, WA message log |
| `/app/admin/config` | Config | System settings, API keys status |
| `/app/admin/toggles` | Feature Toggles | Enable/disable features globally |

### Responsive Breakpoints

- **>1200px** — Full sidebar + content + detail panel (three columns)
- **800-1200px** — Collapsed sidebar (icons) + content + detail overlay
- **<800px** — Hamburger menu, single column, detail as full-screen modal

---

## Business Dashboard

Salon/stylist command center. Calendar, clients, money, marketing — full operational picture.

### Layout

- **Persistent sidebar** — same pattern as admin
- **Default landing** — today's schedule + quick stats + pending actions
- **Calendar is the star** — full-width interactive week view, drag appointments, hover for details
- **Split view tables** — click client → see full history on right
- **Inline editing** — prices, durations, names editable directly in tables
- **Drag and drop** — reorder services, reschedule on calendar, reorder portfolio
- **Realtime notifications** — new bookings, cancellations, reviews without refresh

### Routes

| Route | Page | Function |
|-------|------|----------|
| `/app/negocio` | Dashboard | Today's schedule, quick stats, pending actions, recent reviews |
| `/app/negocio/calendario` | Calendar | Week/month view, drag-to-create, drag-to-reschedule, staff colors, notes |
| `/app/negocio/citas` | Bookings | All appointments, date/status/staff filters, confirm/cancel/no-show |
| `/app/negocio/clientes` | Clients | Client list, visit history, spend totals, notes, full profile |
| `/app/negocio/servicios` | Services | Add/edit/remove, prices, duration, staff assignments, drag reorder |
| `/app/negocio/equipo` | Staff | Team management, schedules, service assignments, color coding |
| `/app/negocio/equipo/horarios` | Staff Schedules | Per-staff weekly availability, vacation/day-off management |
| `/app/negocio/finanzas` | Finance | Revenue charts, payout history, Stripe Connect, tips, commissions |
| `/app/negocio/marketing` | Marketing Hub | QR codes, business cards, social cards, embeddable widget |
| `/app/negocio/marketing/qr` | QR Branding | Custom branded QR codes for walk-in booking |
| `/app/negocio/marketing/widget` | Booking Widget | Embeddable code snippet for salon websites |
| `/app/negocio/portfolio` | Portfolio | Photo gallery — upload, tag, reorder, set featured |
| `/app/negocio/analytics` | Analytics | Trends, peak hours heatmap, service popularity, retention, revenue/service |
| `/app/negocio/resenas` | Reviews | All reviews, respond, flag, average over time |
| `/app/negocio/ajustes` | Settings | Business info, location, hours, payment setup, notifications |
| `/app/negocio/pagos` | Stripe Onboarding | Connect Stripe, verify bank, payout schedule |

### Responsive Breakpoints

- **>1200px** — Full sidebar + 7-day calendar + detail panels
- **800-1200px** — Collapsed sidebar, 3-day calendar, detail overlay
- **<800px** — Hamburger, day view calendar, single column

---

## Client Booking Flow

On mobile: 4-6 taps in 30 seconds. On desktop: same speed but with more information, more confidence, more control.

### Flow

| Step | What | Desktop advantage |
|------|------|-------------------|
| 1. Service | Category grid + subcategory chips | Context panel shows service info, price range, duration, popular salons — all visible without navigating |
| 2. Details | Follow-up questions (if needed) | Multi-column, larger image options, easier comparison |
| 3. Results | Top 3 curated side by side | All 3 visible simultaneously: galleries, prices, schedules, map |
| 4. Confirm | Summary + payment | Split view: booking summary left, payment right. Everything visible. |

### Client Routes

| Route | Page | Function |
|-------|------|----------|
| `/app/reservar` | Booking Flow | Progressive 4-step flow with progress bar |
| `/app/mis-citas` | My Bookings | Table of past/upcoming, filter, click → detail with receipt/review/dispute |
| `/app/favoritos` | Favorites | Saved salons grid with quick-book button |
| `/app/mensajes` | Messages | Split-pane chat — thread list left, conversation right |
| `/app/mensajes/aphrodite` | Aphrodite AI | AI assistant, wide conversation with suggested actions |
| `/app/ajustes` | Settings | Profile, phone, payment methods, notifications, linked accounts |
| `/app/notificaciones` | Notifications | Full history with filters |

### UX Patterns

- Top navbar with account dropdown (no bottom navigation)
- Hover states on cards and table rows
- Keyboard navigation (Tab, Enter, Esc)
- Split-pane chat (desktop email style)
- Map with pins on results page, hover card highlights pin

### Responsive Breakpoints

- **>1200px** — Three-column results, map below, context panels visible
- **800-1200px** — Two-column results, context panel collapses
- **<800px** — Single card carousel, map toggles

**Philosophy:** Mobile gives you the answer fast. Desktop gives you the confidence to choose.

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Framework | Flutter Web 3.38.x (stable) | Same as mobile, WASM support |
| Compilation | WASM (dart2wasm) | 40% faster loads, near-native. Auto-fallback to CanvasKit JS for older browsers |
| State | Riverpod 2.6.x | Same as mobile |
| Routing | GoRouter 14.8.x | Path-based URLs, role redirects |
| Backend | Supabase (self-hosted) | Same DB, auth, edge functions, realtime |
| Payments | Stripe Web SDK | Stripe Connect + Checkout |
| Maps | Mapbox GL JS (web interop) | Better desktop map experience |
| Charts | fl_chart 0.69.x | Works on web |
| Static pages | Vanilla HTML/CSS | SEO pages, zero framework overhead |

---

## URL Structure

```
beautycita.com/                    # Static landing (Nginx → /public/index.html)
beautycita.com/registro/           # Static salon registration
beautycita.com/precios/            # Static pricing comparison
beautycita.com/contacto/           # Static contact
beautycita.com/nosotros/           # Static about/mission
beautycita.com/prensa/             # Static press
beautycita.com/empleo/             # Static employment
beautycita.com/cookies/            # Static cookie policy
beautycita.com/privacidad/         # Static privacy
beautycita.com/terminos/           # Static terms

beautycita.com/app/                # Flutter web app (authenticated)
beautycita.com/app/auth            # Login
beautycita.com/app/admin/*         # Admin panel
beautycita.com/app/negocio/*       # Business dashboard
beautycita.com/app/reservar        # Client booking
beautycita.com/app/mis-citas       # Client bookings
beautycita.com/app/mensajes        # Chat
```

---

## Server Deployment

### Build Commands

```bash
# Flutter web (WASM)
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter build web --wasm --release --no-tree-shake-icons

# Deploy Flutter app
rsync -avz --delete build/web/ www-bc:/var/www/beautycita.com/webapp/dist/

# Deploy static pages
rsync -avz --delete /home/bc/futureBeauty/public/ www-bc:/var/www/beautycita.com/public/
```

### Server Directory

```
/var/www/beautycita.com/
├── public/              # Static SEO pages
├── webapp/dist/         # Flutter web build (WASM)
├── frontend/dist/       # OLD webapp (removed after migration)
├── bc-flutter/
│   └── supabase-docker/ # Self-hosted Supabase (unchanged)
└── docker-compose.yml   # Monitoring (unchanged)
```

---

## Build Phases

| Phase | Scope | Outcome |
|-------|-------|---------|
| **0** | Extract `beautycita_core` shared package | Foundation. Verify mobile still builds. |
| **1** | Auth + Admin panel | BC manages platform from desktop daily. Validates architecture. |
| **2** | Business dashboard | Salons manage operations from desktop. Full-featured. |
| **3** | Client experience | Clients book from desktop with confidence. |
| **4** | Static SEO pages | Public-facing, Google-indexable. Landing, pricing, legal, etc. |
| **5** | Graphics integration | 64 custom illustrations deployed and integrated throughout. |
| **6** | Old webapp removal | Delete legacy code, clean server, update nginx. |

---

## Custom Graphics

64 custom illustrations documented in `docs/plans/2026-02-25-beautycita-graphics-prompts.md`.

Categories: service category icons (12), subcategory icons (15), booking flow illustrations (6), empty states (8), status/feedback (6), landing/onboarding (8), dashboard decorative (5), brand elements (4).

All prompts include exact filenames, dimensions, and consistent brand style (Rose #660033, Gold #FFB300, cream #FFF8F0 backgrounds).

---

## References

- Brand colors and palette system: `beautycita_app/lib/config/palettes.dart`
- Graphics prompts: `docs/plans/2026-02-25-beautycita-graphics-prompts.md`
- Webapp architecture rules: `~/.claude/projects/-home-bc/memory/webapp-architecture.md`
- Supabase infrastructure: `~/.claude/projects/-home-bc/memory/supabase-infra.md`
- Security standards: `~/.claude/projects/-home-bc/memory/security-standards.md`
