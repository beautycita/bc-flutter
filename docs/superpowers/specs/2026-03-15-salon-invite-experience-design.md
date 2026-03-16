# Salon Invite Experience — Design Spec

**Date:** 2026-03-15
**Status:** Draft
**Purpose:** Primary user-driven salon acquisition tool. Users invite their favorite salons to BeautyCita via personalized WhatsApp messages. This is the growth engine — the thing that gets 8K salons.

---

## Core Principle

The user feels like they're part of the salon's success on BeautyCita. The invite is personal, fun, and effortless. Aphrodite generates unique content for every salon and every invite — no canned spam.

---

## Entry Points

### 1. Top Nav Button (alongside Feed/Chat/Settings)
Icon button in the home screen top row — same level as the feed/explore button. Tapping opens the invite screen. No service context — shows top 20 nearby salons weighted by proximity, rating, review count.

### 2. Booking Flow Fallback
When curate-results returns zero registered salons, the results screen shows the invite list filtered by the service the user searched for. This is the existing `_NoResultsWithNearbySalons` widget, upgraded to use the new invite experience instead of the basic list.

---

## Invite Screen

Full-screen, feels like browsing — not admin work.

### Search Bar
- Top of screen, always visible
- Type a salon name → searches `discovered_salons` by `business_name` (fuzzy/ILIKE)
- **If not found**: on-demand scrape via Google Places API → enrich (categories, photos, rating) → insert into `discovered_salons` → show result
- During scrape: fun Aphrodite animation ("Buscando tu salon...")
- Scrape takes 3-5 seconds

### Salon List
- **Top 20** nearby discovered salons
- Weighted ranking: proximity + rating + review count + photo availability (same `qualityScore` logic as outreach-discovered-salon edge function)
- **Context-aware filtering**: if arriving from booking flow with a service type, filter to salons matching that service. If arriving from the top nav button, show all categories
- Each card shows: photo (or placeholder), name, category, rating + review count, distance
- Infinite scroll for "load more" beyond initial 20

---

## Salon Detail

Tap any salon from the list → detail view.

### Salon Info
- Hero photo (from Google scrape `feature_image_url`, or gradient placeholder)
- Name, address, city
- Rating + review count
- Category chips (from `matched_categories`)
- Hours (if available from `working_hours`)

### "Acerca de este estilista" — Aphrodite-Generated Bio
- Unique per salon, generated on first view using scraped data: name, specialties, location, rating, review count, category
- Reads like a real profile, not a template. Aphrodite uses the salon's specifics to craft something compelling
- Cached in `discovered_salons.generated_bio` column after first generation (TEXT, nullable)
- If cached bio exists, show instantly. If not, generate on view (1-2 second shimmer)

### Invite Message Section
- WhatsApp-style message bubble displaying Aphrodite's generated invite message
- Clear **"Creado por Aphrodite"** badge (small, stylish — gradient text or icon)
- Message characteristics:
  - Modern casual Spanish, zero spelling/grammar errors
  - Uses the user's name/username + salon's name + service context
  - Not formal, not corporate — speaks like a real person texting
  - Different every generation — no two invites read the same
  - Mentions that the user wants to book with them
  - Mentions BeautyCita naturally (not a sales pitch)
- **Redo button** (refresh icon) — generates a new variation with different tone/angle. Instant — Aphrodite call is fast
- **"Enviar Invitacion" button** — triggers the dual-message flow (see below)

---

## Dual-Message Flow (on "Enviar Invitacion" tap)

### Message 1: User → Salon (Personal WhatsApp)
- Opens the user's WhatsApp app via `wa.me/{salon_phone}?text={encoded_message}`
- Pre-filled with the Aphrodite-generated message the user approved
- User just taps send in WhatsApp — one tap

### Message 2: Platform → Salon (BeautyCita WA via beautypi)
- Sent automatically when the invite button is pressed (fire-and-forget)
- Generic but informative business pitch:
  - "Hoy un usuario quiso reservar tu servicio en BeautyCita"
  - Value prop: more clients, lower costs, free business tools
  - Link to **smart registration form**: `beautycita.com/registro/{salon_id}` (pre-filled)
  - Link to **demo**: `beautycita.com/demo`
- Sent via beautypi WA API (existing infrastructure)
- Does NOT duplicate if salon already received a platform message within 48 hours (existing `MIN_OUTREACH_INTERVAL_HOURS` logic)

### Signal Recording
- Increment `interest_count` on `discovered_salons`
- Log in `salon_outreach_log` (user_id, salon_id, timestamp, channel: 'user_invite')
- Evaluate escalating outreach thresholds (existing logic in outreach-discovered-salon)

---

## On-Demand Scrape (salon not in DB)

When user searches for a salon not found in `discovered_salons`:

1. Call `on-demand-scrape` edge function with the search query + user's location
2. Edge function calls Google Places API (`textSearch` or `findPlaceFromText`)
3. Returns: name, address, phone, lat/lng, rating, review count, photo, categories, hours
4. Insert into `discovered_salons` with `source: 'user_search'`, `status: 'discovered'`
5. Run category mapping (existing `matched_categories` logic)
6. Return enriched salon to client → show in detail view
7. **Animation**: Aphrodite searching animation while scraping (3-5 sec)

---

## Smart Registration Form (Web)

New page at `beautycita.com/registro/{salon_id}`

### Pre-filled from discovered_salons
- Business name, address, city, phone, photo
- All editable — salon confirms or corrects

### Progressive Verification
- Step 1: Confirm/edit business info (pre-filled)
- Step 2: Verify email OR phone (inline, required before proceeding)
- Step 3: Add services + schedule (quick-pick from common services)
- Step 4: Done — account created, guided to business portal

### Key Behavior
- Knows what the salon needs next — doesn't ask redundant questions
- If salon already has a partial registration, resumes where they left off
- Mobile-friendly (salon owners will open this on their phone from WA)

---

## Aphrodite Integration

### Bio Generation
- **Prompt context**: salon name, category, specialties, city, rating, review count, years in business (if known)
- **Output**: 2-3 sentence bio in Spanish. Warm, specific, not generic
- **Model**: GPT-4o-mini (fast, cheap, good enough for short copy)
- **Caching**: store in `discovered_salons.generated_bio`, regenerate only on explicit request

### Invite Message Generation
- **Prompt context**: user's username, salon name, salon category, service the user was looking for (if any), salon city
- **Output**: 1-3 sentence casual WhatsApp message in Spanish. Modern language, no jargon, no formality, no spelling errors
- **Model**: GPT-4o-mini
- **No caching**: fresh every time (each invite should feel unique). Redo button = new generation

---

## DB Changes

### discovered_salons — new columns
- `generated_bio` (TEXT, nullable) — cached Aphrodite bio
- `source` needs 'user_search' value (already supports this)

### New table: user_salon_invites
- `id` UUID PK
- `user_id` UUID FK profiles
- `discovered_salon_id` UUID FK discovered_salons
- `invite_message` TEXT — the Aphrodite message the user sent
- `platform_message_sent` BOOLEAN — whether the platform WA was sent
- `created_at` TIMESTAMPTZ

---

## Edge Function Changes

### aphrodite-chat (existing)
- Add new actions: `generate_salon_bio` and `generate_invite_message`
- Both return generated text, no conversation state needed

### outreach-discovered-salon (existing)
- Add action: `on_demand_scrape` — Google Places search + insert + return
- Modify `invite` action to also trigger platform WA message with registration + demo links

### New: salon-invite (or extend outreach-discovered-salon)
- Handle the dual-message flow: record invite, send platform WA, return success

---

## Screens (Mobile App)

### New: InviteSalonExperienceScreen
- Replaces/upgrades existing `InviteSalonScreen`
- Search bar + weighted salon list + context-aware filtering
- Tapping salon → detail with Aphrodite bio + invite message

### Modified: result_cards_screen.dart
- `_NoResultsWithNearbySalons` → links to new invite experience instead of basic list

### Modified: home_screen.dart
- Add CTA card for invite experience below category grid

### New: Web — RegistrationPage
- `beautycita_web` page at `/registro/:salonId`
- Pre-filled smart form with progressive verification

---

## Future (not built now, keep architecture ready)
- Reward system for users who invite salons (badges, credits, priority booking)
- Leaderboard of top inviters
- Tracking: which invites converted to registered salons
