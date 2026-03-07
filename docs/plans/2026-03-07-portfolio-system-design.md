# BeautyCita Portfolio System — Design Specification

**Date:** 2026-03-07
**Status:** Approved
**Author:** BC + Claude

---

## Overview

A personal website system for salons, served as lightweight static HTML pages hydrated with live data. Each salon gets one portfolio page at a shareable URL (`beautycita.com/p/salon-slug`). The page showcases the salon, its team, their work, services, reviews, and location. White-label — no BeautyCita branding except a tiny "powered by BeautyCita" footer.

Portfolios start **private by default**. The salon owner builds it up, then toggles public when satisfied. Can be toggled off at any time.

---

## Architecture: Hybrid Static Shell + Dynamic Data

Each theme is a standalone HTML/CSS template. On page load, a lightweight JS fetch pulls salon data from a Supabase API endpoint and hydrates the template. No Flutter web rendering for portfolio pages.

**Why not Flutter web:** Portfolio links get shared on Instagram, WhatsApp, business cards. They need to load instantly, be SEO-indexable, and work on any device without a heavy framework.

**Flow:**
1. Client clicks `beautycita.com/p/salon-luna`
2. Nginx serves the static HTML template for that salon's chosen theme
3. JS fetches salon data from Supabase (public read, respects `portfolio_public` flag)
4. Template hydrates with data, page renders
5. If `portfolio_public = false` → shows "Este portafolio aún no está disponible"

---

## Data Model

### New columns on `businesses`
- `portfolio_slug` (text, unique) — URL-friendly name, auto-generated from salon name, editable
- `portfolio_public` (boolean, default false)
- `portfolio_theme` (text, default 'portfolio') — theme name
- `portfolio_bio` (text) — owner's personal story
- `portfolio_tagline` (text) — short one-liner

### New columns on `staff`
- `bio` (text) — individual team member bio
- `specialties` (text[]) — what they're known for

### New table: `portfolio_photos`
| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| business_id | uuid FK → businesses | |
| staff_id | uuid FK → staff, nullable | null = salon-level photo |
| before_url | text, nullable | null = after-only shot |
| after_url | text, NOT NULL | always present |
| photo_type | text | 'before_after' or 'after_only' |
| service_category | text | what service was performed |
| caption | text, nullable | |
| product_tags | jsonb, nullable | for future POS — products used |
| sort_order | integer | display ordering |
| is_visible | boolean, default true | hide without deleting |
| created_at | timestamptz | |

### New table: `portfolio_agreements`
| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| business_id | uuid FK → businesses | |
| agreement_type | text | 'portfolio', 'pos_seller', etc. |
| agreement_version | text | version string |
| accepted_at | timestamptz | |

---

## Salon Hierarchy

| Role | Has BC account | Gets portfolio section | Bookable | Payments go to |
|------|---------------|----------------------|----------|----------------|
| Salon owner/stylist | Yes | Yes (bio + work) | Yes | Their own account |
| Apprentice | No | Yes (bio + work) | Yes | Salon owner |
| Employee | No | No | No | Salon owner |
| Linked stylist (rare) | Yes (existing) | Yes (under salon + their own page) | Yes | Salon owner (when booked via salon) |

All portfolio content managed by the salon owner (or delegated to assistant). Apprentices and employees don't manage their own sections.

---

## Team Member Stats

Each team member card on the portfolio page displays:
- Name, photo, bio, specialties
- Average services per week
- Rating (stars)
- Number of reviews
- Before/after photo count
- Creates healthy visibility without framing it as competition

---

## Portfolio Themes

5 themes. Each displays ALL available data — themes control visual arrangement, not content inclusion. Any theme works for any salon size. Missing data sections auto-hide gracefully.

| Theme | Optimized For | Visual Style |
|-------|--------------|-------------|
| **Portfolio** | Solo stylist showcase | One person's work front and center, personal bio prominent |
| **Team Builder** | Multi-staff salon | Team grid prominent, individual stats, "Estamos buscando..." hiring slot |
| **Storefront** | Service & pricing focus | Services/prices lead, catalog feel, gallery secondary |
| **Gallery** | Photo-heavy, work speaks | Minimal text, maximum visuals, masonry/grid dominates |
| **Local** | Neighborhood/community salon | Map and location prominent, reviews featured, warm/approachable |

All themes are just CSS + HTML skeletons. Same JS fetch, same data shape, different visual presentation. Prevents clone/eBay-listing look across salons.

**"Estamos buscando..." slot:** Available on all themes (not just Team Builder). Shows an empty team member card with hiring message. Toggle on/off by salon owner. Application handling is external to BeautyCita.

---

## Before/After Camera Flow (Mobile App)

### Trigger
- **5-10 minutes before appointment arrival** → push notification to stylist: "Tu cita con [client] es en X min. ¿Foto del antes?"
- **Appointment marked complete** → push notification: "¡Servicio completado! ¿Foto del después?"

### First-Time Tips (shows once, dismissable, revisitable in settings)
- Visual illustration: model standing on tape X with backdrop and lights
- "Para mejores resultados:"
  - Use a backdrop (floral, sunset, solid white)
  - Mark a spot on the floor (tape X) for consistent positioning
  - Good lighting makes the difference
- Suggestions only, not requirements

### Photo Capture
- Opens inside the app — custom camera UI, not default phone camera
- Guided overlay for framing (head/shoulders for hair, hands for nails, etc.)
- **No minimum, no maximum** — 1 quick snap or 15 shots, whatever the client allows
- Client consent: "¿La clienta autoriza la foto del antes?" — if no, after-only
- Before and after are separate capture sessions

### Auto-Processing
- System selects best image(s) from each set (sharpness, composition, lighting)
- Auto-corrects: color balance, exposure, brightness, saturation
- Stylist can override system's pick
- Best before paired with best after automatically

### Tagging
- Service performed (required)
- Staff member who did the work (required)
- Products used (optional, for future POS/feed)
- Caption (optional)

### Manual Upload
- Salon owner can bulk upload from phone gallery anytime
- For existing work not captured through the appointment flow

---

## Portfolio Management (Mobile App + Web Business Portal)

Same capabilities on both platforms, designed independently for each.

### Settings
- Toggle public/private
- Pick theme (preview all 5 before selecting)
- Set/edit slug
- Edit salon bio, tagline
- Edit team member bios, specialties

### Photo Management
- Grid view of all portfolio photos
- Reorder (drag and drop)
- Toggle visibility per photo
- Delete
- Edit captions, product tags
- Filter by staff member
- Bulk upload from phone gallery

### Social Import
- Facebook/Instagram connected during onboarding → pull photos
- Salon from `discovered_salons` → import `portfolio_images` from scraper data
- Owner reviews and approves which imported photos go live

### Team Management (portfolio-specific)
- Edit bios and specialties
- Reorder team member display order
- Toggle hiring slot on/off

### UI Location
- **Web:** New "Portafolio" tab in existing business portal
- **Mobile:** New section in business settings or dedicated tab

---

## Portfolio Page Structure

Rendered in order, sections auto-hide if no data:

1. **Hero** — salon photo/logo + name + tagline
2. **About** — owner bio + contact info + social links (WhatsApp, Instagram, Facebook)
3. **Team** — member cards with stats (if multiple staff) + hiring slot (if enabled)
4. **Gallery** — before/afters + standalone work, filterable by team member. Before/after pairs show side-by-side slider. After-only shows as standalone.
5. **Services** — service list with prices
6. **Reviews** — client reviews with ratings
7. **Location** — address, hours, embedded map
8. **Footer** — tiny "powered by BeautyCita"

---

## Privacy & Visibility

- Portfolio is **private by default** (`portfolio_public = false`)
- Private portfolio URL returns: "Este portafolio aún no está disponible"
- No data leaked when private — API returns nothing
- Owner toggles public when ready
- Can toggle off at any time
- Individual photos can be hidden without deleting (`is_visible = false`)
- Client consent required for before photos (enforced in camera flow)

---

## URL Routing

- Salon page: `beautycita.com/p/salon-luna`
- Link to specific team member: `beautycita.com/p/salon-luna?staff=jessica` (same page, filtered/scrolled)
- Nginx routes `/s/*` to the portfolio template system
- Slug uniqueness enforced at DB level

---

## Future Integration Points (not built now, data model supports)

- **Inspiration Feed:** `portfolio_photos` feed into global feed. `product_tags` become shoppable.
- **POS:** Products tagged in photos link to salon's product catalog.
- **Direct Stylist Booking:** Earned privilege. Portfolio page gets a "Reservar" button when client has access.
- **Client-Stylist Chat:** Earned access clients can message from portfolio page.

---

## Legal

- **Portfolio Agreement** required before going public — checkbox acceptance, versioned, timestamped
- Covers: photo usage rights, content standards, client consent obligations
- Must re-accept if agreement is updated
