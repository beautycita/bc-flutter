# Web Invite Experience + Toggle Enforcement — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the desktop-first web invite experience (master-detail split panel) and wire ALL 32 feature toggles to client-side enforcement in the mobile app.

**Architecture:** Web invite shares the same edge function backend as mobile — no new APIs needed. Split into two independent workstreams: (A) web invite UI, (B) toggle enforcement sweep. Both can run in parallel.

**Tech Stack:** Flutter Web (beautycita_web), Flutter Mobile (beautycita_app), Riverpod, GoRouter, Supabase Edge Functions

**Specs:**
- `docs/superpowers/specs/2026-03-15-web-invite-experience-design.md`
- `docs/superpowers/specs/2026-03-15-salon-invite-experience-design.md` (mobile, for context)

---

## File Structure

### Workstream A: Web Invite Experience

**New Files (beautycita_web):**
- `lib/pages/client/invite_page.dart` — master-detail page in client shell
- `lib/pages/public/invite_public_page.dart` — standalone public page wrapper
- `lib/widgets/invite/salon_list_panel.dart` — left panel: search + salon cards
- `lib/widgets/invite/salon_detail_panel.dart` — right panel: detail + Aphrodite bio + invite message
- `lib/widgets/invite/invite_message_card.dart` — web-styled invite message card with Aphrodite badge
- `lib/widgets/invite/salon_card.dart` — individual salon card for the list
- `lib/providers/web_invite_provider.dart` — state management (same state machine as mobile, fresh implementation)

**Modified Files (beautycita_web):**
- `lib/config/router.dart` — add `/client/invitar` and `/invitar` routes
- `lib/shells/client_shell.dart` — add "Invitar" nav button

### Workstream B: Toggle Enforcement (beautycita_app)

**Modified Files — 13 files need toggle checks added:**
- `lib/screens/chat_conversation_screen.dart` — gate virtual studio button (`enable_virtual_studio`)
- `lib/screens/home_screen.dart` — gate invite button (`enable_salon_invite`), already gates feed + chat
- `lib/screens/invite/invite_experience_screen.dart` — gate on-demand scrape button (`enable_on_demand_scrape`)
- `lib/screens/cita_express_screen.dart` — gate entire screen (`enable_cita_express`)
- `lib/screens/booking_detail_screen.dart` — gate dispute button (`enable_disputes`)
- `lib/screens/business/business_disputes_screen.dart` — gate disputes tab (`enable_disputes`)
- `lib/screens/business/business_calendar_sync_screen.dart` — gate calendar sync (`enable_google_calendar`)
- `lib/screens/profile_screen.dart` — gate AI avatar section (`enable_ai_avatars`)
- `lib/screens/auth_screen.dart` — gate QR auth option (`enable_qr_auth`)
- `lib/widgets/screenshot_report_button.dart` — gate button visibility (`enable_screenshot_report`)
- `lib/screens/admin/admin_pipeline_screen.dart` — gate pipeline tab (`enable_outreach_pipeline`)
- `lib/screens/transport_selection_screen.dart` — gate Uber option (`enable_uber_integration`) — verify this is already done
- `lib/providers/feature_toggle_provider.dart` — add defaults for all 13 new toggles

**New File:**
- `test/toggle_enforcement_test.dart` — verify all 32 toggles have client enforcement

---

## Chunk 1: Web Invite — Provider + Widgets

### Task 1: Web Invite Provider

**Files:**
- Create: `beautycita_web/lib/providers/web_invite_provider.dart`

- [ ] **Step 1: Implement WebInviteProvider**

Same state machine as mobile's InviteProvider but using `SupabaseCore.client` (not `SupabaseClientService`). States: loading, browsing, searching, scraping, salonDetail, generating, readyToSend, sending, sent, error. Methods: initialize, searchSalons, scrapeAndShow, selectSalon, generateBio, generateMessage, sendInvite, backToList, clearSearch.

Edge function calls via `SupabaseCore.client.functions.invoke(...)`.

Location: use browser Geolocation API via `dart:html` `window.navigator.geolocation`. Fallback to null (show city selector or all salons).

- [ ] **Step 2: Analyze**

```bash
cd beautycita_web && flutter analyze lib/providers/web_invite_provider.dart
```

- [ ] **Step 3: Commit**

```bash
git add beautycita_web/lib/providers/web_invite_provider.dart
git commit -m "feat(web): invite provider — state machine for salon invite"
```

---

### Task 2: Salon Card Widget

**Files:**
- Create: `beautycita_web/lib/widgets/invite/salon_card.dart`

- [ ] **Step 1: Build SalonCard**

Desktop-optimized card: salon photo (rounded, with hover zoom), name, category tag chip, star rating + review count, distance pill. Hover: card lifts (translateY -2px + shadow increase). Selected state: left border accent (brand gradient), subtle background tint. Takes `selected` bool, `onTap` callback, and salon data map.

- [ ] **Step 2: Commit**

```bash
git add beautycita_web/lib/widgets/invite/salon_card.dart
git commit -m "feat(web): salon card widget with hover + selection states"
```

---

### Task 3: Invite Message Card Widget

**Files:**
- Create: `beautycita_web/lib/widgets/invite/invite_message_card.dart`

- [ ] **Step 1: Build InviteMessageCard**

Web-styled message card (NOT the mobile green bubble). Clean white card with subtle left border in brand gradient. Message text, "Creado por Aphrodite" badge in gradient italic text below. Redo IconButton inline. Shimmer state when `isGenerating` is true. Takes: `message` (nullable), `isGenerating`, `onRedo`.

- [ ] **Step 2: Commit**

```bash
git add beautycita_web/lib/widgets/invite/invite_message_card.dart
git commit -m "feat(web): invite message card with Aphrodite badge"
```

---

## Chunk 2: Web Invite — Panels + Page

### Task 4: Salon List Panel (Left Side)

**Files:**
- Create: `beautycita_web/lib/widgets/invite/salon_list_panel.dart`

- [ ] **Step 1: Build SalonListPanel**

Width: 420px fixed. Background: `Color(0xFFF8F7F5)` (warm off-white). Contains:
- Search bar at top: large TextField, animated placeholder cycling examples (use AnimationController + IndexedStack of hint texts). Clear button when text present.
- Scrollable list of SalonCard widgets below
- Gradient masks at top/bottom of scroll area (ShaderMask with LinearGradient)
- States: loading (shimmer cards), searching (shimmer), scraping (Aphrodite pulsing orb animation), empty + suggestScrape ("Buscarlo en Google?" gradient button), populated (card list)
- Staggered entrance animation on first load (TweenAnimationBuilder with delayed intervals)

- [ ] **Step 2: Commit**

```bash
git add beautycita_web/lib/widgets/invite/salon_list_panel.dart
git commit -m "feat(web): salon list panel — search + animated card list"
```

---

### Task 5: Salon Detail Panel (Right Side)

**Files:**
- Create: `beautycita_web/lib/widgets/invite/salon_detail_panel.dart`

- [ ] **Step 1: Build SalonDetailPanel**

Takes the full remaining width (min 600px). Contains:
- **Empty state** (no salon selected): centered brand illustration/icon with "Selecciona un salon para ver detalles" text
- **Salon selected** (slide/fade transition, 200ms):
  - Hero: full-width photo with dark gradient overlay (or animated brand gradient placeholder with salon initial)
  - Info row: name (large Poppins), address, rating stars + count, category chips — horizontal
  - "Acerca de este estilista" blockquote card with shimmer while loading
  - Divider
  - "Tu invitacion personalizada" section header with gradient Aphrodite icon
  - InviteMessageCard widget
  - If no message yet: "Generar invitacion" gradient button
- **Bottom**: full-width gradient "Enviar Invitacion" button with WhatsApp icon. States: ready → sending (spinner) → sent (green check). Opens `wa.me` in new tab via `url_launcher`.

- [ ] **Step 2: Commit**

```bash
git add beautycita_web/lib/widgets/invite/salon_detail_panel.dart
git commit -m "feat(web): salon detail panel — bio + invite message + send"
```

---

### Task 6: Invite Page (Master-Detail) + Routes

**Files:**
- Create: `beautycita_web/lib/pages/client/invite_page.dart`
- Create: `beautycita_web/lib/pages/public/invite_public_page.dart`
- Modify: `beautycita_web/lib/config/router.dart`
- Modify: `beautycita_web/lib/shells/client_shell.dart`

- [ ] **Step 1: Build InvitePage**

Responsive layout:
- Desktop (≥1200px): Row with SalonListPanel (420px) + SalonDetailPanel (flex). Subtle shadow on detail panel left edge for depth.
- Tablet (800-1199px): SalonListPanel full-width as 2-column grid. Tap card opens modal overlay (centered dialog with backdrop blur) containing SalonDetailPanel.
- Mobile (<800px): SalonListPanel full-width single column. Tap navigates to a detail sub-page.

Initialize provider in initState. Accept optional `serviceType` parameter.

- [ ] **Step 2: Build InvitePublicPage**

Minimal wrapper: brand gradient header bar ("BeautyCita — Invita tu salon"), InvitePage as body. On "Enviar" without auth: show login dialog.

- [ ] **Step 3: Add routes**

In `beautycita_web/lib/config/router.dart`:
- Add `WebRoutes.invitar = '/client/invitar'`
- Add route inside client ShellRoute: `GoRoute(path: 'invitar', builder: ...)` → `InvitePage`
- Add public route: `GoRoute(path: '/invitar', builder: ...)` → `InvitePublicPage`

- [ ] **Step 4: Add nav button to client shell**

In `beautycita_web/lib/shells/client_shell.dart`, add a `_NavButton` for "Invitar" between "Reservar" and "Mis Citas":
```dart
_NavButton(
  label: 'Invitar',
  route: WebRoutes.invitar,
  isActive: currentPath == WebRoutes.invitar,
),
```

- [ ] **Step 5: Analyze all web files**

```bash
cd beautycita_web && flutter analyze lib/pages/client/invite_page.dart lib/pages/public/invite_public_page.dart lib/widgets/invite/ lib/providers/web_invite_provider.dart lib/shells/client_shell.dart lib/config/router.dart
```

- [ ] **Step 6: Commit**

```bash
git add beautycita_web/lib/pages/ beautycita_web/lib/widgets/invite/ beautycita_web/lib/config/router.dart beautycita_web/lib/shells/client_shell.dart
git commit -m "feat(web): invite page — master-detail split panel + public page + routes"
```

---

## Chunk 3: Toggle Enforcement Sweep (Mobile)

### Task 7: Add new toggle defaults to feature_toggle_provider

**Files:**
- Modify: `beautycita_app/lib/providers/feature_toggle_provider.dart`

- [ ] **Step 1: Add defaults for all 13 new toggles**

Add to the `_kDefaults` map:
```dart
'enable_virtual_studio': true,
'enable_aphrodite_ai': true,
'enable_eros_support': true,
'enable_ai_copy': true,
'enable_ai_avatars': true,
'enable_google_calendar': true,
'enable_cita_express': true,
'enable_salon_invite': true,
'enable_disputes': true,
'enable_on_demand_scrape': true,
'enable_outreach_pipeline': true,
'enable_screenshot_report': true,
'enable_qr_auth': true,
```

- [ ] **Step 2: Commit**

```bash
git add beautycita_app/lib/providers/feature_toggle_provider.dart
git commit -m "feat: add defaults for all 13 new feature toggles"
```

---

### Task 8: Wire toggles to 13 screens

**Files:**
- Modify: 13 files (see list above)

Each file needs the same pattern — import the provider, watch it, conditionally show/hide the feature:

```dart
import '../../providers/feature_toggle_provider.dart';
// In build():
final toggles = ref.watch(featureTogglesProvider);
if (!toggles.isEnabled('enable_xxx')) return const SizedBox.shrink();
```

- [ ] **Step 1: Gate home screen invite button**

`lib/screens/home_screen.dart` — wrap the invite `_HeaderButton` Consumer with `enable_salon_invite` check. Already has the pattern from the feed button.

- [ ] **Step 2: Gate Cita Express screen**

`lib/screens/cita_express_screen.dart` — at the top of `build()`, check `enable_cita_express`. If disabled, show a "Esta funcion no esta disponible" message instead of the booking flow.

- [ ] **Step 3: Gate virtual studio button**

Find the virtual studio / try-on button in the chat conversation screen. Wrap with `enable_virtual_studio` check.

- [ ] **Step 4: Gate Aphrodite and Eros chat options**

In the chat home/selection screen, gate Aphrodite option with `enable_aphrodite_ai` and Eros with `enable_eros_support`.

- [ ] **Step 5: Gate AI copy generation**

In business staff and service screens, find the "generate bio" / "generate description" buttons. Wrap with `enable_ai_copy`.

- [ ] **Step 6: Gate AI avatars**

In `profile_screen.dart`, find the avatar generation section. Wrap with `enable_ai_avatars`.

- [ ] **Step 7: Gate Google Calendar sync**

In the business calendar sync screen, check `enable_google_calendar` at the top.

- [ ] **Step 8: Gate disputes**

In `business_disputes_screen.dart` and `booking_detail_screen.dart`, gate dispute buttons with `enable_disputes`.

- [ ] **Step 9: Gate screenshot report button**

In `screenshot_report_button.dart`, add `enable_screenshot_report` check. If disabled, return SizedBox.shrink(). Need to make it a ConsumerWidget or use a Consumer wrapper.

- [ ] **Step 10: Gate outreach pipeline**

In `admin_pipeline_screen.dart`, check `enable_outreach_pipeline`.

- [ ] **Step 11: Gate on-demand scrape**

In `invite_experience_screen.dart`, wrap the "Buscar en Google" scrape button with `enable_on_demand_scrape`.

- [ ] **Step 12: Gate QR auth**

In `auth_screen.dart` (or wherever QR login option is shown), gate with `enable_qr_auth`.

- [ ] **Step 13: Gate Uber in transport selection**

Check if `enable_uber_integration` is already enforced in transport selection. If not, add it.

- [ ] **Step 14: Analyze all modified files**

```bash
cd beautycita_app && flutter analyze lib/screens/ lib/widgets/ lib/providers/feature_toggle_provider.dart
```

- [ ] **Step 15: Commit**

```bash
git add -A
git commit -m "feat: wire all 32 feature toggles to client-side enforcement"
```

---

### Task 9: Toggle Enforcement Test

**Files:**
- Create: `beautycita_app/test/toggle_enforcement_test.dart`

- [ ] **Step 1: Write verification test**

Test that every toggle key in the DB has a corresponding `isEnabled()` call somewhere in the codebase. This is a grep-based test:

```dart
test('every toggle has client-side enforcement', () {
  // List of all 32 toggle keys
  final toggleKeys = [
    'enable_stripe_payments', 'enable_cash_payments', ...all 32...
  ];

  // Keys that are server-side only or not enforceable in UI
  final serverOnly = {
    'tax_withholding_enabled',  // server-side only
    'enable_analytics',         // no UI gating needed
    'enable_waitlist',          // feature not built
    'enable_voice_booking',     // feature not built
    'enable_instant_booking',   // no fallback exists
    'enable_time_inference',    // no fallback exists
  };

  for (final key in toggleKeys) {
    if (serverOnly.contains(key)) continue;
    // Verify key exists in defaults map
    expect(kToggleDefaults.containsKey(key), isTrue,
        reason: '$key missing from defaults');
  }
});
```

- [ ] **Step 2: Run test**

```bash
flutter test test/toggle_enforcement_test.dart -v
```

- [ ] **Step 3: Commit**

```bash
git add test/toggle_enforcement_test.dart
git commit -m "test: verify all feature toggles have client-side defaults"
```

---

## Chunk 4: Build + Deploy

### Task 10: Deploy Web + Build APK/IPA

- [ ] **Step 1: Build and deploy web**

```bash
cd beautycita_web && flutter build web --release
rsync -avz --delete --exclude sativa build/web/ www-bc:/var/www/beautycita.com/frontend/dist/
```

- [ ] **Step 2: Deploy edge functions** (if any changed)

```bash
rsync -avz beautycita_app/supabase/functions/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 3: Build APK**

Re-read MEMORY.md build section. Bump build number to 50020. Split-per-abi. Upload arm64 to R2. Update version.json.

- [ ] **Step 4: Trigger IPA build**

Push to main, trigger GitHub Actions, download artifact, upload to R2, update ipa.html.

- [ ] **Step 5: Commit build bump**

```bash
git add beautycita_app/pubspec.yaml
git commit -m "chore: bump build to 50020"
```
