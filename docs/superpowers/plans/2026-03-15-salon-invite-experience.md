# Salon Invite Experience — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the primary user-driven salon acquisition tool — users browse nearby discovered salons, view Aphrodite-generated bios, get personalized invite messages, and send them via WhatsApp.

**Architecture:** New invite screen replaces existing `InviteSalonScreen`. Aphrodite generates unique salon bios and invite messages via new actions in the `aphrodite-chat` edge function. On-demand scraping handles salons not in the DB. Dual WhatsApp messages (user personal + platform business pitch) on every invite. Smart web registration form for salons.

**Tech Stack:** Flutter (Riverpod, GoRouter), Supabase Edge Functions (Deno/TS), OpenAI GPT-4o-mini (via Aphrodite), Google Places API, WhatsApp API (beautypi), Flutter Web (registration page)

**Spec:** `docs/superpowers/specs/2026-03-15-salon-invite-experience-design.md`

---

## File Structure

### New Files (Mobile)
- `lib/screens/invite/invite_experience_screen.dart` — main invite screen (search + list)
- `lib/screens/invite/invite_salon_detail_screen.dart` — salon detail with Aphrodite bio + invite message
- `lib/screens/invite/invite_message_bubble.dart` — WhatsApp-style message bubble widget
- `lib/providers/invite_provider.dart` — state management for invite flow
- `lib/services/invite_service.dart` — API calls (search, scrape, generate bio/message, send invite)
- `test/providers/invite_provider_test.dart` — unit tests for invite state machine
- `test/services/invite_service_test.dart` — unit tests for service layer
- `test/screens/invite_experience_screen_test.dart` — widget tests

### New Files (Web)
- `beautycita_web/lib/pages/registro_page.dart` — smart salon registration form

### New Files (Edge Functions)
- None — extend existing `aphrodite-chat` and `outreach-discovered-salon`

### Modified Files
- `lib/screens/home_screen.dart` — add invite nav button (~lines 262-274)
- `lib/config/routes.dart` — update invite route to new screen
- `supabase/functions/aphrodite-chat/index.ts` — add `generate_salon_bio` + `generate_invite_message` actions
- `supabase/functions/outreach-discovered-salon/index.ts` — add `search` action (fuzzy name search) + enhance `invite` action with platform WA message containing registration + demo links
- `supabase/functions/on-demand-scrape/index.ts` — add `search_place` action (Google Places text search → enrich → insert)
- `beautycita_web/lib/config/router.dart` — add `/registro/:salonId` route
- DB migration: add `generated_bio` to `discovered_salons`, create `user_salon_invites` table

### Retired
- `lib/screens/invite_salon_screen.dart` — replaced by new invite experience (keep file, redirect imports)

---

## Chunk 1: Database + Edge Function Backend

### Task 1: Migration — discovered_salons.generated_bio + user_salon_invites table

**Files:**
- Create: `beautycita_app/supabase/migrations/20260316000000_invite_experience.sql`

- [ ] **Step 1: Write migration SQL**

```sql
-- Add cached Aphrodite bio to discovered salons
ALTER TABLE discovered_salons
  ADD COLUMN IF NOT EXISTS generated_bio TEXT;

-- Track user-initiated salon invites
CREATE TABLE IF NOT EXISTS user_salon_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  discovered_salon_id UUID NOT NULL REFERENCES discovered_salons(id) ON DELETE CASCADE,
  invite_message TEXT NOT NULL,
  platform_message_sent BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_salon_invites_user ON user_salon_invites(user_id);
CREATE INDEX idx_user_salon_invites_salon ON user_salon_invites(discovered_salon_id);

-- RLS
ALTER TABLE user_salon_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own invites"
  ON user_salon_invites FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create invites"
  ON user_salon_invites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Service role full access for edge functions
CREATE POLICY "Service role full access on invites"
  ON user_salon_invites FOR ALL
  USING (auth.role() = 'service_role');
```

- [ ] **Step 2: Run migration on production**

```bash
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"ALTER TABLE discovered_salons ADD COLUMN IF NOT EXISTS generated_bio TEXT;\""
# Then run the CREATE TABLE + indexes + RLS
```

- [ ] **Step 3: Verify**

```bash
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"\d user_salon_invites\""
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"SELECT column_name FROM information_schema.columns WHERE table_name = 'discovered_salons' AND column_name = 'generated_bio';\""
```

- [ ] **Step 4: Commit**

```bash
git add beautycita_app/supabase/migrations/20260316000000_invite_experience.sql
git commit -m "feat: migration for invite experience — generated_bio + user_salon_invites"
```

---

### Task 2: Aphrodite — generate_salon_bio + generate_invite_message actions

**Files:**
- Modify: `beautycita_app/supabase/functions/aphrodite-chat/index.ts` (lines 70-81 ChatRequest interface, lines 460-562 generate_copy action)

- [ ] **Step 1: Add new action types to ChatRequest interface**

In the `ChatRequest` interface (~line 70), add `"generate_salon_bio" | "generate_invite_message"` to the action union type.

- [ ] **Step 2: Add generate_salon_bio handler**

After the `generate_copy` action block (~line 562), add a new handler. Input: `salon_name`, `salon_category`, `salon_specialties`, `salon_city`, `salon_rating`, `salon_review_count`. Output: 2-3 sentence bio in Spanish. Use GPT-4o-mini via `callResponsesAPI()`. System prompt instructs Aphrodite to write a warm, specific bio — not generic. Cache result by updating `discovered_salons.generated_bio` via service client.

- [ ] **Step 3: Add generate_invite_message handler**

Input: `user_name`, `salon_name`, `salon_category`, `service_searched` (nullable), `salon_city`. Output: 1-3 sentence casual WhatsApp message. System prompt: modern casual Spanish, zero errors, different every time, mentions the user wants to book, mentions BeautyCita naturally (not a sales pitch). Do NOT cache — fresh every generation.

- [ ] **Step 4: Deploy and test**

```bash
rsync -avz beautycita_app/supabase/functions/aphrodite-chat/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/aphrodite-chat/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

Test via curl with a real salon from discovered_salons.

- [ ] **Step 5: Commit**

```bash
git add beautycita_app/supabase/functions/aphrodite-chat/index.ts
git commit -m "feat: Aphrodite salon bio + invite message generation"
```

---

### Task 3: outreach-discovered-salon — search action + enhanced invite

**Files:**
- Modify: `beautycita_app/supabase/functions/outreach-discovered-salon/index.ts`

- [ ] **Step 1: Add `search` action**

New action that accepts `query` (string) + `lat`/`lng`. Does ILIKE search on `business_name` in `discovered_salons` within radius. Returns top 10 matches sorted by relevance (name match quality + distance). If zero results, returns `{ salons: [], suggest_scrape: true }`.

- [ ] **Step 2: Enhance `invite` action**

After recording the interest signal and evaluating outreach thresholds, also:
- Insert into `user_salon_invites` (user_id, discovered_salon_id, invite_message, platform_message_sent)
- Send platform WA message with: "Hoy un usuario quiso reservar tu servicio en BeautyCita. Más clientes, menos costos, herramientas gratis." + link to `beautycita.com/registro/{salon_id}` + link to `beautycita.com/demo`
- Accept `invite_message` parameter (the Aphrodite text the user is sending)

- [ ] **Step 3: Deploy and test**

```bash
rsync -avz beautycita_app/supabase/functions/outreach-discovered-salon/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/outreach-discovered-salon/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 4: Commit**

```bash
git add beautycita_app/supabase/functions/outreach-discovered-salon/index.ts
git commit -m "feat: search action + enhanced invite with platform WA + registration link"
```

---

### Task 4: on-demand-scrape — search_place action

**Files:**
- Modify: `beautycita_app/supabase/functions/on-demand-scrape/index.ts`

- [ ] **Step 1: Add `search_place` action**

New action: accepts `query` (salon name), `lat`, `lng`. Calls Google Places `textSearch` API with the query + location bias. Takes the top result. Extracts: name, address, phone, lat/lng, rating, review count, photo reference, types/categories. Inserts into `discovered_salons` with `source: 'user_search'`. Runs category mapping. Returns the enriched salon as JSON matching the `DiscoveredSalon` model shape.

- [ ] **Step 2: Handle duplicate detection**

Before inserting, check if a salon with the same `source_id` (Google Place ID) already exists. If so, return the existing record instead of creating a duplicate.

- [ ] **Step 3: Deploy and test**

```bash
rsync -avz beautycita_app/supabase/functions/on-demand-scrape/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/on-demand-scrape/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 4: Commit**

```bash
git add beautycita_app/supabase/functions/on-demand-scrape/index.ts
git commit -m "feat: on-demand Google Places search for user salon lookup"
```

---

## Chunk 2: Flutter Service + Provider Layer

### Task 5: Invite Service

**Files:**
- Create: `beautycita_app/lib/services/invite_service.dart`
- Create: `beautycita_app/test/services/invite_service_test.dart`

- [ ] **Step 1: Write failing tests**

Test that `InviteService.fetchNearbySalons()` calls the edge function with correct params and parses the response. Test `searchSalons()`, `scrapeAndEnrich()`, `generateBio()`, `generateInviteMessage()`, `sendInvite()`. Use mocktail to mock Supabase function calls.

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd beautycita_app && flutter test test/services/invite_service_test.dart -v
```

- [ ] **Step 3: Implement InviteService**

Methods:
- `fetchNearbySalons(lat, lng, {serviceType, limit})` → calls `outreach-discovered-salon` action `list`
- `searchSalons(query, lat, lng)` → calls `outreach-discovered-salon` action `search`
- `scrapeAndEnrich(query, lat, lng)` → calls `on-demand-scrape` action `search_place`
- `generateBio(salon)` → calls `aphrodite-chat` action `generate_salon_bio`
- `generateInviteMessage(userName, salon, {serviceSearched})` → calls `aphrodite-chat` action `generate_invite_message`
- `sendInvite(salonId, inviteMessage)` → calls `outreach-discovered-salon` action `invite`

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add lib/services/invite_service.dart test/services/invite_service_test.dart
git commit -m "feat: InviteService — API layer for invite experience"
```

---

### Task 6: Invite Provider (State Machine)

**Files:**
- Create: `beautycita_app/lib/providers/invite_provider.dart`
- Create: `beautycita_app/test/providers/invite_provider_test.dart`

- [ ] **Step 1: Write failing tests**

Test the state machine: initial → loading salons → salons loaded → salon selected → bio generated → message generated → message regenerated → invite sent. Test context-aware filtering (service type passed from booking flow vs null from nav button). Test search flow including on-demand scrape fallback.

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement InviteProvider**

State: `InviteState` with fields: `step` (enum: loading, browsing, salonDetail, generating, readyToSend, sending, sent, error), `salons` (List), `selectedSalon`, `generatedBio`, `inviteMessage`, `serviceFilter`, `searchQuery`, `isSearching`, `isScraping`, `error`.

Notifier methods:
- `loadSalons(lat, lng, {serviceType})` — fetch top 20, sets browsing
- `searchSalons(query)` — search DB, if empty set `suggest_scrape`
- `scrapeAndShow(query)` — on-demand scrape, add to list, select result
- `selectSalon(salon)` — load/generate bio, transition to salonDetail
- `generateInviteMessage()` — call Aphrodite, transition to readyToSend
- `regenerateMessage()` — call Aphrodite again, new message
- `sendInvite()` — record invite, trigger platform WA, return WA URL for user

- [ ] **Step 4: Run tests to verify they pass**

- [ ] **Step 5: Commit**

```bash
git add lib/providers/invite_provider.dart test/providers/invite_provider_test.dart
git commit -m "feat: InviteProvider — state machine for invite flow"
```

---

## Chunk 3: Flutter UI Screens

### Task 7: Invite Experience Screen (search + list)

**Files:**
- Create: `beautycita_app/lib/screens/invite/invite_experience_screen.dart`
- Create: `beautycita_app/test/screens/invite_experience_screen_test.dart`

- [ ] **Step 1: Write widget test**

Test that the screen renders search bar + salon list. Test that tapping a salon navigates to detail. Test that search bar triggers search. Test empty state shows scrape suggestion.

- [ ] **Step 2: Build the screen**

Layout:
- Search bar at top (TextField with search icon, debounced 500ms)
- Below: list of salon cards (photo, name, category, rating, distance)
- Cards match app design language (rounded corners, shadows, brand colors)
- During search: loading shimmer
- If search returns empty + suggest_scrape: show "No lo encontramos. Buscarlo en Google?" button → Aphrodite animation while scraping
- Infinite scroll: load 20 more on scroll to bottom
- Pull-to-refresh reloads from GPS

- [ ] **Step 3: Run widget test**

- [ ] **Step 4: Commit**

```bash
git add lib/screens/invite/invite_experience_screen.dart test/screens/invite_experience_screen_test.dart
git commit -m "feat: invite experience screen — search + salon list"
```

---

### Task 8: Invite Salon Detail Screen (bio + message + send)

**Files:**
- Create: `beautycita_app/lib/screens/invite/invite_salon_detail_screen.dart`
- Create: `beautycita_app/lib/screens/invite/invite_message_bubble.dart`

- [ ] **Step 1: Build salon detail screen**

Layout:
- Hero photo with gradient overlay
- Salon info: name, address, rating, category chips
- "Acerca de este estilista" section — shimmer while loading, then Aphrodite bio
- Divider
- Invite section header: "Tu invitacion personalizada"
- `InviteMessageBubble` — WhatsApp-style bubble with the message text, "Creado por Aphrodite" badge (gradient text, small)
- Redo button (refresh icon) next to the bubble → regenerates
- Fixed bottom bar: "Enviar Invitacion" gradient button

- [ ] **Step 2: Build InviteMessageBubble widget**

WhatsApp-style: rounded rect, light green tint (`#DCF8C6`), tail on right side, message text inside. "Creado por Aphrodite" badge below message in small italic gradient text. Shimmer state while generating.

- [ ] **Step 3: Wire send button**

On tap:
1. Call `inviteProvider.sendInvite()` — records in DB + fires platform WA
2. Build WhatsApp URL: `wa.me/{phone}?text={encoded_message}`
3. Launch URL (opens user's WhatsApp)
4. Show success toast after return

- [ ] **Step 4: Commit**

```bash
git add lib/screens/invite/invite_salon_detail_screen.dart lib/screens/invite/invite_message_bubble.dart
git commit -m "feat: invite salon detail — Aphrodite bio + personalized message + send"
```

---

### Task 9: Home Screen Nav Button + Route Wiring

**Files:**
- Modify: `beautycita_app/lib/screens/home_screen.dart` (~lines 262-274)
- Modify: `beautycita_app/lib/config/routes.dart` (~lines 330-345)

- [ ] **Step 1: Add invite button to home screen top row**

In the Row at ~line 258, add a new Consumer block for the invite button. Icon: `Icons.card_giftcard_rounded` or `Icons.volunteer_activism_rounded`. Positioned alongside the existing feed/chat/settings buttons. On tap: `context.push('/invite')`.

- [ ] **Step 2: Update route**

In `routes.dart`, change the `/invite` GoRoute (~line 330) to point to the new `InviteExperienceScreen()` instead of the old `InviteSalonScreen()`. Pass optional `serviceType` parameter via `state.extra` for context-aware filtering.

- [ ] **Step 3: Update booking flow fallback**

In `result_cards_screen.dart`, update `_NoResultsWithNearbySalons` to navigate to the new invite experience screen with the service type context instead of showing the inline basic list. Keep the inline list as a preview (3 salons) with a "Ver más" button that opens the full invite screen.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home_screen.dart lib/config/routes.dart lib/screens/result_cards_screen.dart
git commit -m "feat: invite nav button on home + route wiring + booking flow link"
```

---

## Chunk 4: Web Registration + Polish + Deploy

### Task 10: Smart Registration Page (Web)

**Files:**
- Create: `beautycita_web/lib/pages/registro_page.dart`
- Modify: `beautycita_web/lib/config/router.dart` — add `/registro/:salonId` route

- [ ] **Step 1: Build RegistroPage**

Desktop-first responsive form. On load, fetch discovered salon data by ID from Supabase. Pre-fill: business name, address, city, phone, photo. All editable.

Progressive steps:
1. Confirm/edit business info
2. Verify email (inline — send verification code) OR phone
3. Add services (quick-pick from common services grid) + schedule (day/time pickers)
4. Success — redirect to business portal with confetti

- [ ] **Step 2: Enforce verification before stylist role**

After step 2 verification, create the Supabase auth account (email+password or phone), create the profile row, THEN create the business. The user cannot proceed to step 3 without verified identity.

- [ ] **Step 3: Add route**

In `beautycita_web/lib/config/router.dart`, add:
```dart
GoRoute(
  path: '/registro/:salonId',
  builder: (context, state) => RegistroPage(
    salonId: state.pathParameters['salonId'] ?? '',
  ),
),
```

- [ ] **Step 4: Build and deploy web**

```bash
cd beautycita_web && flutter build web --release --no-tree-shake-icons
rsync -avz --delete --exclude sativa build/web/ www-bc:/var/www/beautycita.com/frontend/dist/
```

- [ ] **Step 5: Commit**

```bash
git add beautycita_web/lib/pages/registro_page.dart beautycita_web/lib/config/router.dart
git commit -m "feat: smart salon registration page — pre-filled from discovered data"
```

---

### Task 11: Integration Testing + Edge Function Deploy

**Files:**
- All edge function files from Tasks 2-4
- Test files from Tasks 5-7

- [ ] **Step 1: Run all unit tests**

```bash
cd beautycita_app && flutter test test/services/invite_service_test.dart test/providers/invite_provider_test.dart -v
```

- [ ] **Step 2: Deploy all edge functions**

```bash
rsync -avz beautycita_app/supabase/functions/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 3: End-to-end manual test**

1. Open app → tap invite button → see nearby salons list
2. Search for a known salon → see it in results
3. Search for unknown salon → scrape animation → salon appears
4. Tap salon → see Aphrodite bio (unique, not canned)
5. See invite message → tap redo → new message generated
6. Tap send → WhatsApp opens with message pre-filled
7. Verify platform WA message was sent to salon
8. Verify `user_salon_invites` record created
9. Check `beautycita.com/registro/{salonId}` → pre-filled form loads

- [ ] **Step 4: Flutter analyze**

```bash
flutter analyze lib/screens/invite/ lib/providers/invite_provider.dart lib/services/invite_service.dart
```
Expected: 0 issues

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: salon invite experience — complete implementation"
```

---

## Chunk 5: Build + Release

### Task 12: Build APK + IPA

- [ ] **Step 1: Build APK**

Re-read MEMORY.md build section. Use `flutter build apk --split-per-abi` with dart-defines. Upload arm64 to R2. Update version.json with bumped build number.

- [ ] **Step 2: Trigger IPA build**

Push to main, trigger GitHub Actions `build-ios.yml`, download artifact, upload to R2, update `beautycita.com/bc/ipa.html`.

- [ ] **Step 3: Install on test devices and verify**

Install APK on Galaxy S10 + S24. Install IPA on iPad via Sideloadly. Run through the full invite flow on each device.
