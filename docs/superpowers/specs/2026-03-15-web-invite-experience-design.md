# Web Invite Experience — Design Spec

**Date:** 2026-03-15
**Status:** Draft
**Purpose:** Desktop-first salon invite experience for beautycita.com. Same growth engine as mobile, built natively for web — NOT a copy of the mobile UI.

---

## Core Principle

Desktop has more space. Use it. The invite experience should feel like a single immersive surface — not two boxes bolted together. The split panel must look intentional, elegant, and premium. When a salon is selected, the detail panel should feel like it belongs to the list, not like a separate page crammed next to it.

---

## Entry Points

### 1. Client Shell Nav Item
Logged-in users see "Invita Salones" in the client sidebar alongside Feed, Mis Citas, Reservar. Route: `/client/invitar`.

### 2. Public Page
Standalone page at `/invitar` — no auth shell, branded header. Anyone can browse and search salons. Clicking "Enviar Invitacion" prompts login. Good for shareability. Uses the same page component wrapped in a minimal public shell.

---

## Desktop Layout (1200px+): Immersive Master-Detail

NOT two flat boxes. One flowing surface with depth and visual hierarchy.

### Left Panel — Salon Discovery (~420px fixed width)
- Subtle background: very light warm grey or off-white with faint texture
- **Search bar** at top — large, prominent, with search icon and animated placeholder text cycling through examples: "Barberia Orozco...", "Studio Queens...", "Mi salon favorito..."
- **Salon cards** in a scrollable list below search
  - Each card: salon photo (rounded, with subtle parallax on hover), name, category tag, star rating, distance pill
  - Hover state: card lifts slightly (translateY + shadow increase), photo zooms subtly
  - Selected card: left border accent (brand gradient), background tint, stays highlighted
  - Smooth scroll, no hard edges — cards fade at top/bottom with gradient masks
- **Empty state** (search returned nothing): "No lo encontramos" + "Buscar en Google" CTA with Aphrodite sparkle animation
- **Scraping state**: Aphrodite animated orb replacing the list content momentarily

### Divider
- NOT a hard line. A subtle shadow/depth effect — the detail panel sits slightly "above" the list panel visually (1-2px shadow on the left edge)
- Or: no divider at all — the detail panel has a white background that naturally separates from the light grey list

### Right Panel — Salon Detail + Invite (~remaining width, min 600px)
- **No salon selected state**: Large centered illustration or brand graphic with "Selecciona un salon para ver detalles" text. Warm, inviting, not empty-feeling.
- **Salon selected state** (animated transition — slide in from right or fade):
  - **Hero**: Full-width photo with gradient overlay. If no photo, animated brand gradient with salon initial letter
  - **Info row**: Name (large), address, rating stars + count, category chips — all in one clean horizontal layout
  - **"Acerca de este estilista"**: Aphrodite-generated bio in a styled blockquote or card. Shimmer while loading.
  - **Invite section**:
    - Section header with Aphrodite gradient icon
    - WhatsApp-style message bubble (but web-styled — not the mobile green bubble. Use a clean card with a subtle left border in brand gradient)
    - "Creado por Aphrodite" badge
    - Redo button (regenerate icon) — inline, not floating
    - **"Enviar Invitacion"** button — full width, gradient, WhatsApp icon. Opens wa.me link in new tab.
  - Vertical scroll if content overflows

### Visual Polish Details
- Transitions: panel content fades/slides when switching salons (200ms ease)
- Cards in list: staggered entrance animation on first load (each card delays 50ms)
- Search: results filter in real-time with smooth height transitions
- Brand gradient accents: selected states, buttons, badges, hover highlights — cohesive
- Typography: clean hierarchy. Salon names in Poppins 600, body in Nunito 400
- Spacing: generous — this is desktop, don't cram things

---

## Tablet Layout (800-1199px)

Split panel collapses. List shows as a grid (2 columns of cards). Tapping a card opens a modal/overlay detail panel (bottom sheet style but centered, with backdrop blur). Not a page navigation.

---

## Mobile Layout (<800px)

Full page flow — list of cards, tap navigates to detail page. Back button returns. Same content, different arrangement. This mirrors the mobile app experience naturally.

---

## Shared Backend

All edge function calls are identical to mobile — the web just calls them through `SupabaseCore.client.functions.invoke()`:

- `outreach-discovered-salon` action `list` — nearby salons
- `outreach-discovered-salon` action `search` — name search
- `on-demand-scrape` action `search_place` — Google Places lookup
- `aphrodite-chat` action `generate_salon_bio` — unique bio
- `aphrodite-chat` action `generate_invite_message` — personalized message
- `outreach-discovered-salon` action `invite` — record + platform WA

No new edge functions needed.

---

## Web-Specific Considerations

### Auth Gate
- Public page (`/invitar`): browsing is free, sending invite requires auth
- Client page (`/client/invitar`): already authenticated
- On "Enviar" click without auth: show login modal (existing web auth flow)

### Location
- Use browser Geolocation API for nearby salon ranking
- If denied: default to user's profile city, or show a city selector
- Location permission prompt should be friendly — explain why (to find nearby salons)

### WhatsApp Send
- `wa.me` links open WhatsApp Web or the WA desktop app in a new tab
- On mobile browsers: opens WA app directly
- Show a toast after opening: "Mensaje listo en WhatsApp — solo toca enviar"

### SEO (public page only)
- Page title: "Invita tu salon favorito — BeautyCita"
- Meta description: "Ayuda a tu salon de belleza favorito a unirse a BeautyCita. Busca, invita, y se parte de su exito."
- No SSR needed — client-rendered is fine for now

---

## File Structure

### New Files
- `beautycita_web/lib/pages/client/invite_page.dart` — the main invite experience (master-detail)
- `beautycita_web/lib/pages/public/invite_public_page.dart` — public wrapper (minimal shell + same content)
- `beautycita_web/lib/widgets/invite/salon_list_panel.dart` — left panel (search + cards)
- `beautycita_web/lib/widgets/invite/salon_detail_panel.dart` — right panel (detail + invite)
- `beautycita_web/lib/widgets/invite/invite_message_card.dart` — web-styled invite bubble
- `beautycita_web/lib/widgets/invite/salon_card.dart` — individual salon list card
- `beautycita_web/lib/providers/web_invite_provider.dart` — web state management

### Modified Files
- `beautycita_web/lib/config/router.dart` — add `/client/invitar` and `/invitar` routes
- `beautycita_web/lib/widgets/client_sidebar.dart` (or equivalent) — add nav item

### NOT Modified
- `beautycita_app/` — nothing. This is web-only.
- `beautycita_core/` — no UI in the shared package.

---

## Future (not now)
- Reward badges for top inviters (when reward system is built)
- Social sharing: "I just invited X salon" card for social media
- Invite analytics dashboard in admin panel
