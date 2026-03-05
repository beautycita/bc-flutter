# V1 Production Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Take BeautyCita from current state to production-ready v1 — every button works or gets deleted, every flow completes end-to-end, no placeholders.

**Architecture:** Four phases executed sequentially. Phase 1 ships current work. Phase 2 adds Google One Tap email capture to biometric registration. Phase 3 fixes the salon invite/onboarding funnel end-to-end. Phase 4 audits and fixes every admin button in the web panel. No tests in this plan (deferred to post-v1 per BC's decision).

**Tech Stack:** Flutter 3.38 + Supabase (self-hosted) + Deno edge functions + Google Sign-In 6.x + WhatsApp API (beautypi)

---

## Phase 1: Ship Current Changes (Full APK Release)

### Task 1: Commit Eros Support Changes

The Eros AI support integration (4 files) is complete but uncommitted.

**Files:**
- Modified: `lib/providers/chat_provider.dart`
- Modified: `lib/screens/chat_conversation_screen.dart`
- Modified: `lib/screens/chat_list_screen.dart`
- Modified: `lib/screens/legal_screens.dart`

**Step 1: Stage and commit**
```bash
cd /home/bc/futureBeauty/beautycita_app
git add lib/providers/chat_provider.dart lib/screens/chat_conversation_screen.dart lib/screens/chat_list_screen.dart lib/screens/legal_screens.dart
git commit -m "feat: replace WhatsApp contact with Eros AI support + human escalation

- Add erosThreadProvider and SendErosMessageNotifier to chat_provider
- Wire support_ai contact type in chat_conversation_screen with blue bubbles
- Add ErosRow to chat list with blue gradient avatar
- Replace _ContactSection WhatsApp form with Eros AI + human support buttons
- Add 'Hablar con humano' escalation button in Eros chat app bar"
```

**Step 2: Push**
```bash
git push origin main
```

### Task 2: Bump Version and Build Release APK

**Files:**
- Modify: `pubspec.yaml` — version line
- Modify: `lib/config/constants.dart` — AppConstants.version and buildNumber

**Step 1: Bump version**

In `pubspec.yaml`, change:
```yaml
version: 0.9.2+45012
```

In `lib/config/constants.dart`, change:
```dart
static const String version = '0.9.2';
static const int buildNumber = 45012;
```

**Step 2: Build split release**
```bash
/home/bc/flutter/bin/flutter build apk --release --split-per-abi --no-tree-shake-icons
```

**Step 3: Install on connected devices**
```bash
/home/bc/Android/Sdk/platform-tools/adb devices
# Install on each connected device:
/home/bc/Android/Sdk/platform-tools/adb -s <DEVICE_ID> install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

**Step 4: Upload APK to R2**
```bash
AWS_ACCESS_KEY_ID=ca3c10c25e5a6389797d8b47368626d4 \
AWS_SECRET_ACCESS_KEY=9a761a36330e00d98e1faa6c588c47a76fb8f15b573c6dcf197efe10d80bba4d \
aws s3 cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  s3://beautycita-medias/apk/beautycita.apk \
  --endpoint-url https://e61486f47c2fe5a12fdce43b7a318343.r2.cloudflarestorage.com \
  --content-type "application/vnd.android.package-archive"
```

**Step 5: Upload version.json**
```bash
echo '{"version":"0.9.2","build":45012,"url":"https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk","required":false}' | \
AWS_ACCESS_KEY_ID=ca3c10c25e5a6389797d8b47368626d4 \
AWS_SECRET_ACCESS_KEY=9a761a36330e00d98e1faa6c588c47a76fb8f15b573c6dcf197efe10d80bba4d \
aws s3 cp - s3://beautycita-medias/apk/version.json \
  --endpoint-url https://e61486f47c2fe5a12fdce43b7a318343.r2.cloudflarestorage.com \
  --content-type "application/json" \
  --cache-control "max-age=60, must-revalidate"
```

**Step 6: Commit version bump**
```bash
git add pubspec.yaml lib/config/constants.dart
git commit -m "chore: bump version to 0.9.2+45012 for full APK release"
git push origin main
```

---

## Phase 2: Google One Tap Email Capture

### Task 3: Add Google One Tap After Biometric Registration

**Context:** After biometric registration succeeds, show Google One Tap to silently capture the user's email as metadata. Not for auth — just for cross-referencing and re-engagement if they abandon the app.

**Files:**
- Modify: `lib/screens/auth_screen.dart` — `_handleBiometricTap()` method (around line 402)
- Modify: `lib/providers/auth_provider.dart` — add `captureGoogleEmail()` method

**Step 1: Add `captureGoogleEmail()` to auth_provider.dart**

After the existing `register()` method, add:

```dart
/// Attempt Google One Tap to silently capture email as metadata.
/// Not used for auth — just for cross-referencing and re-engagement.
/// Returns the captured email or null if user dismissed.
Future<String?> captureGoogleEmail() async {
  try {
    final clientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ?? '';
    if (clientId.isEmpty) return null;

    final googleSignIn = GoogleSignIn(serverClientId: clientId);
    final account = await googleSignIn.signIn();
    if (account == null) return null; // User dismissed

    final email = account.email;

    // Sign out of Google immediately — we don't want the session,
    // just the email. Prevents interference with linkGoogle() later.
    await googleSignIn.signOut();

    // Store as metadata on the Supabase user
    if (SupabaseClientService.isInitialized) {
      await SupabaseClientService.client.auth.updateUser(
        UserAttributes(data: {'discovered_email': email}),
      );
    }

    return email;
  } catch (e) {
    debugPrint('captureGoogleEmail failed (non-fatal): $e');
    return null;
  }
}
```

Requires these imports at top of `auth_provider.dart`:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
```

Check which are already imported and add only missing ones.

**Step 2: Call `captureGoogleEmail()` from auth_screen.dart**

In `_handleBiometricTap()`, after `register()` succeeds (around line 402) and before the celebration/navigation block, add:

```dart
// After register() returns true:
if (success) {
  // Attempt Google One Tap for email capture (non-blocking)
  // Don't await in a way that blocks navigation — fire and forget
  // but wait briefly for the One Tap UI to appear
  final authNotifier = ref.read(authProvider.notifier);
  await authNotifier.captureGoogleEmail();

  // Continue with existing discovered_salons check and navigation...
}
```

The key: if the user dismisses Google One Tap, `captureGoogleEmail()` returns null and we proceed normally. The user never feels blocked. If they tap, we capture the email silently.

**Step 3: Verify**

- Fresh install → biometric → Google One Tap appears → tap → email stored in `user_metadata.discovered_email`
- Fresh install → biometric → dismiss One Tap → proceeds to home without email
- Check Supabase dashboard: `auth.users` → user's `raw_user_meta_data` should contain `discovered_email`

**Step 4: Commit**
```bash
git add lib/providers/auth_provider.dart lib/screens/auth_screen.dart
git commit -m "feat: Google One Tap email capture after biometric registration

Silently captures Google email as user_metadata.discovered_email
after biometric registration. Not used for auth — stored as metadata
for cross-referencing and re-engagement. User can dismiss freely."
```

---

## Phase 3: Fix Salon Invite Flow

### Current State (Broken)

Three disconnected paths:
1. **User invite** (`invite_salon_screen.dart`) sends `beautycita.com/registro?ref=<id>` → web app
2. **Automated outreach** (`outreach-discovered-salon`) sends `beautycita.com/salon/<id>` → web app
3. **salon-registro edge function** is the only complete path (creates auth, staff, schedule, role) but nothing sends traffic to it

The `salon-registro` edge function already has the "yes this is my salon" confirmation step with enriched data card. It's the right destination — we just need to route traffic there.

### Task 4: Unify Invite Links to salon-registro Edge Function

**Goal:** All invite/outreach links should point to the salon-registro edge function HTML page, which is self-contained and works in any mobile browser.

**Files:**
- Modify: `lib/screens/invite_salon_screen.dart` — change the invite URL
- Modify: `supabase/functions/outreach-discovered-salon/index.ts` — change the outreach URL

**Step 1: Determine the salon-registro URL**

The edge function URL pattern for self-hosted Supabase is:
`https://beautycita.com/supabase/functions/v1/salon-registro?ref=<discovered_salon_id>`

Read the current Supabase URL from `.env` to confirm the base URL pattern, and check how other edge functions are invoked (e.g., `client.functions.invoke('salon-registro')` — what base URL does this resolve to?).

Also check: does the nginx config on the server proxy `/supabase/functions/v1/` correctly? If not, we may need to add a cleaner URL like `beautycita.com/registro/<id>` that nginx rewrites to the edge function.

**Step 2: Update invite_salon_screen.dart**

Find the line that builds the invite URL (currently `beautycita.com/registro?ref=<id>&name=...&phone=...`) and change it to:

```dart
final inviteUrl = 'https://beautycita.com/supabase/functions/v1/salon-registro?ref=${salon.id}';
```

The edge function fetches all salon data server-side from the `ref` ID, so we don't need query params for name/phone/address.

**Step 3: Update outreach-discovered-salon/index.ts**

Find the line that builds the outreach link (currently `beautycita.com/salon/<id>`) and change it to:

```dart
const registroUrl = `https://beautycita.com/supabase/functions/v1/salon-registro?ref=${salonId}`;
```

**Step 4: Verify**

- Open the URL in a mobile browser → salon-registro HTML page loads with enriched data
- The "Es tu salon?" confirmation step shows scraped salon photo, name, rating, address
- Full OTP verification → account creation → success page works end-to-end

**Step 5: Commit**
```bash
git add lib/screens/invite_salon_screen.dart supabase/functions/outreach-discovered-salon/index.ts
git commit -m "fix: unify invite/outreach links to salon-registro edge function

Both user-sent invites and automated outreach now point to the
complete salon-registro HTML flow which handles OTP, confirmation,
account creation, staff, schedule, and role upgrade."
```

### Task 5: Fix SalonOnboardingScreen to Use register-business

**Context:** `SalonOnboardingScreen._submit()` (line 469) does a raw `businesses` insert, creating an orphaned record with no staff, no schedule, no role upgrade. It should call `register-business` edge function instead.

**Files:**
- Modify: `lib/screens/salon_onboarding_screen.dart` — `_submit()` method (around line 469-517)

**Step 1: Read current `_submit()` implementation**

Read `salon_onboarding_screen.dart` lines 460-520 to understand exactly what it does and what params it collects.

**Step 2: Read register-business edge function**

Read `supabase/functions/register-business/index.ts` to understand what params it accepts.

**Step 3: Replace raw insert with edge function call**

Replace the raw `client.from('businesses').insert(...)` with:

```dart
final res = await SupabaseClientService.client.functions.invoke(
  'register-business',
  body: {
    'business_name': _businessNameCtrl.text.trim(),
    'phone': _phoneCtrl.text.trim(),
    'address': _selectedAddress,
    'latitude': _selectedLat,
    'longitude': _selectedLng,
    'categories': _selectedCategories,
    if (_discoveredSalonId != null) 'discovered_salon_id': _discoveredSalonId,
  },
);
```

Map the field names to match what `register-business` expects. The edge function handles:
- Creating the business record
- Creating a staff entry for the owner
- Creating default schedule (Mon-Sat 9-7)
- Setting `profiles.role = 'stylist'`
- Linking discovered_salon if `discovered_salon_id` is provided

**Step 4: Verify**

- Register a salon through the in-app onboarding screen
- Check Supabase: `businesses` row exists, `staff` row exists, `staff_schedules` rows exist, `profiles.role = 'stylist'`
- If `discovered_salon_id` was provided: `discovered_salons.status = 'registered'`

**Step 5: Commit**
```bash
git add lib/screens/salon_onboarding_screen.dart
git commit -m "fix: salon onboarding uses register-business edge function

Replaces raw businesses table insert with register-business call
which creates staff, schedule, and role upgrade atomically."
```

### Task 6: Fix Deep Link Handling for /registro

**Files:**
- Modify: `lib/main.dart` — deep link handler

**Step 1: Read main.dart deep link section**

Find where `/salon/<uuid>` is intercepted (around line 248 per the exploration).

**Step 2: Add /registro handler**

Add handling for `/registro?ref=<uuid>` deep links so they redirect to `/registro` route with the ref param, same as `/salon/<uuid>` does.

```dart
// In the URI handler:
if (uri.path == '/registro' && uri.queryParameters.containsKey('ref')) {
  final ref = uri.queryParameters['ref']!;
  // Navigate to salon onboarding with ref
  router.go('/registro?ref=$ref');
}
```

**Step 3: Verify**

- Open `beautycita://registro?ref=<uuid>` deep link → lands on salon onboarding screen with prefilled data
- Open `https://beautycita.com/registro?ref=<uuid>` app link → same result

**Step 4: Commit**
```bash
git add lib/main.dart
git commit -m "fix: handle /registro?ref= deep links for salon invites"
```

---

## Phase 4: Admin Button Audit

### Task 7: Remove Buttons That Don't Belong

**Context:** Per BC's design, these buttons should NOT exist:
- Bulk cancel bookings (only clients cancel; admin can cancel individual)
- Bulk convert discovered→registered (salons convert themselves)
- Booking reassignment (user re-books if needed)
- Bulk suspend users (individual suspension exists in user_detail_panel)
- Drag reorder services (engine handles ranking)

**Files:**
- Modify: `beautycita_web/lib/pages/admin/bookings_page.dart` — remove bulk cancel (line 344-354)
- Modify: `beautycita_web/lib/pages/admin/salons_page.dart` — remove bulk convert (line 685-692)
- Modify: `beautycita_web/lib/pages/admin/booking_detail_panel.dart` — remove reassign (line 261-268)
- Modify: `beautycita_web/lib/pages/admin/users_page.dart` — remove bulk suspend (line 365-374)
- Modify: `beautycita_web/lib/pages/admin/services_page.dart` — remove drag reorder (line 302)

**Step 1: Read each file section, confirm the TODO button exists at the reported line**

**Step 2: Remove each button's entire widget block (the TextButton.icon / OutlinedButton.icon and its parent)**

**Step 3: Verify the web app compiles**
```bash
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter analyze
```

**Step 4: Commit**
```bash
git add -A
git commit -m "fix: remove admin buttons that don't fit BeautyCita's design

Removed: bulk cancel bookings (only clients cancel), bulk convert
discovered→registered (salons convert themselves), booking reassignment
(user re-books), bulk suspend users (individual exists), drag reorder
services (engine handles ranking)."
```

### Task 8: Wire Export CSV Buttons

**Context:** Export to CSV is needed for users, salons, and bookings. These are standard admin operations.

**Files:**
- Modify: `beautycita_web/lib/pages/admin/users_page.dart` — wire export (line 360)
- Modify: `beautycita_web/lib/pages/admin/salons_page.dart` — wire export (line 400)
- Modify: `beautycita_web/lib/pages/admin/bookings_page.dart` — wire export (line 339)

**Step 1: Check if the web app has an ExportService or CSV utility**

Search for existing export/CSV code in the web app codebase. The mobile app has `ExportService` — check if something similar exists for web, or if we need to create a simple CSV download utility.

For web, CSV export can use the `dart:html` `AnchorElement` to trigger a download, or the `csv` package to generate the CSV string.

**Step 2: Implement export for each page**

Each export button should:
1. Get the current filtered/selected data from the provider
2. Convert to CSV string (headers + rows)
3. Trigger browser download

**Step 3: Verify each export downloads a valid CSV**

**Step 4: Commit**
```bash
git add -A
git commit -m "feat: wire CSV export buttons in admin panel (users, salons, bookings)"
```

### Task 9: Wire Send WA From Admin (Discovered Salons)

**Context:** Two buttons: bulk WA send (salons_page.dart:680) and single salon WA invite (salon_detail_panel.dart:473). These should call the `outreach-discovered-salon` edge function.

**Files:**
- Modify: `beautycita_web/lib/pages/admin/salons_page.dart` — wire bulk WA (line 680)
- Modify: `beautycita_web/lib/pages/admin/salon_detail_panel.dart` — wire single WA (line 473)

**Step 1: Read `outreach-discovered-salon/index.ts` to understand the API**

The edge function accepts a salon ID and sends the WA invite message. Determine the exact request format.

**Step 2: Wire single salon "Enviar invitacion WA"**

```dart
onPressed: () async {
  final res = await BCSupabase.client.functions.invoke(
    'outreach-discovered-salon',
    body: {'salon_id': salon.id, 'action': 'send_invite'},
  );
  // Show success/error toast
},
```

**Step 3: Wire bulk WA send**

Loop through selected salon IDs, call the edge function for each (or batch if the function supports it).

**Step 4: Verify by sending to a test number**

**Step 5: Commit**
```bash
git add -A
git commit -m "feat: wire WA invite buttons in admin salon panel"
```

### Task 10: Wire Dispute Resolution Workflow

**Context:** Two buttons: "Marcar en revision" (line 194) and "Resolver" (line 265). These update dispute status in the database.

**Files:**
- Modify: `beautycita_web/lib/pages/admin/dispute_detail_panel.dart` — wire both buttons

**Step 1: Read the dispute_detail_panel.dart to understand the state machine**

Disputes have statuses: `open` → `reviewing` → `resolved`. The panel already has a `_resolutionDecision` dropdown.

**Step 2: Wire "Marcar en revision"**

```dart
onPressed: () async {
  await BCSupabase.client.from('disputes').update({
    'status': 'reviewing',
    'reviewed_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', dispute.id);
  // Refresh + toast
},
```

**Step 3: Wire "Resolver"**

```dart
onPressed: () async {
  await BCSupabase.client.from('disputes').update({
    'status': 'resolved',
    'resolution': _resolutionDecision,
    'resolved_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', dispute.id);
  // If resolution involves refund, call process-dispute-refund edge function
  // Refresh + toast
},
```

Check if `process-dispute-refund` should be called as part of resolution.

**Step 4: Verify**

- Open a dispute in admin → click "Marcar en revision" → status updates
- Select a resolution → click "Resolver" → dispute resolved, refund processed if applicable

**Step 5: Commit**
```bash
git add -A
git commit -m "feat: wire dispute resolution workflow in admin panel"
```

### Task 11: Wire Individual Booking Cancel + Refund

**Context:** Admin CAN cancel individual bookings (this is different from bulk cancel which was removed). When admin cancels, the client gets a full refund. The salon gets charged 3% to BC.

**Files:**
- Modify: `beautycita_web/lib/pages/admin/booking_detail_panel.dart` — wire cancel (line 231) and refund (line 250)

**Step 1: Understand the booking model**

Read the booking data structure — what statuses exist? What does cancellation look like in the DB?

**Step 2: Wire "Cancelar reserva" with confirmation dialog**

Must include a triple-check confirmation showing:
- Salon name and booking date
- Client name
- "This will notify the client and process a full refund minus 3%"
- Require typing "CANCELAR" to confirm

```dart
onPressed: () async {
  final confirmed = await _showCancelConfirmation(context, booking);
  if (!confirmed) return;

  // Update booking status
  await BCSupabase.client.from('bookings').update({
    'status': 'cancelled',
    'cancelled_at': DateTime.now().toUtc().toIso8601String(),
    'cancelled_by': 'admin',
  }).eq('id', booking.id);

  // Process refund if payment was made
  if (booking.paymentStatus == 'paid') {
    await BCSupabase.client.functions.invoke('process-dispute-refund', body: {
      'booking_id': booking.id,
      'reason': 'Admin cancellation',
    });
  }
  // Refresh + toast
},
```

**Step 3: Wire "Reembolsar" separately (for refund without cancellation)**

Similar pattern but only triggers the refund, doesn't change booking status to cancelled.

**Step 4: Verify**

- Cancel a test booking → status changes, refund processed, client notified

**Step 5: Commit**
```bash
git add -A
git commit -m "feat: wire booking cancel and refund in admin panel with confirmation"
```

### Task 12: Wire Services CRUD (Add, Delete, Save)

**Context:** The services taxonomy editor in the web admin panel has add/delete/save buttons that don't work. The service taxonomy is core to the booking engine.

**Files:**
- Modify: `beautycita_web/lib/pages/admin/services_page.dart` — wire add (line 116), delete (line 509), save (line 628)

**Step 1: Read services_page.dart to understand the data model**

How are categories, subcategories, and service items stored? What table(s) do they map to?

**Step 2: Wire "Add" (category/subcategory/item)**

Show a dialog based on the level selected (category, subcategory, item). Collect name and any required fields. Insert into the appropriate table.

**Step 3: Wire "Delete" with confirmation**

Show confirmation dialog with the service name. Delete from the appropriate table. Handle cascade (deleting a category should warn about subcategories/items underneath).

**Step 4: Wire "Save changes"**

Batch update modified fields to Supabase.

**Step 5: Verify**

- Add a test category → appears in list
- Add a subcategory under it → appears nested
- Delete the test items → removed from DB
- Edit a service name → save → persists

**Step 6: Commit**
```bash
git add -A
git commit -m "feat: wire services CRUD in admin panel (add, delete, save)"
```

### Task 13: Wire Salon Suspension Cascade

**Context:** When admin suspends a salon, existing bookings' clients should be notified. Currently it's just a DB write with no cascade.

**Files:**
- Create or modify: edge function for salon suspension cascade
- Modify: `beautycita_web/lib/pages/admin/salon_detail_panel.dart` — add suspend button for registered salons
- Modify: mobile admin `admin_salon_detail_screen.dart` — add notification cascade

**Step 1: Design the suspension cascade**

When admin suspends a salon:
1. Set `businesses.is_active = false`
2. Query all `bookings` for this business where `status IN ('pending', 'confirmed')` and `booking_date >= today`
3. For each affected booking:
   - Send push notification to client: "El salon X ha sido suspendido. Tu cita del [date] ya no tiene protecciones de BeautyCita. Un reembolso completo (-3%) esta disponible sin limite de tiempo."
   - Insert `notifications` record for in-app display
4. Do NOT cancel the bookings — client decides whether to cancel

Triple confirmation before executing:
- Show count of affected bookings
- Admin must acknowledge the impact
- Require typing salon name to confirm

**Step 2: Create `suspend-salon` edge function** (or add action to existing function)

This function:
1. Sets `businesses.is_active = false`
2. Queries affected bookings
3. Sends notifications via `send-push-notification` for each
4. Returns count of affected bookings

**Step 3: Wire the web admin panel**

Add suspend/reactivate toggle to `salon_detail_panel.dart` for registered salons (currently only exists in mobile admin).

**Step 4: Wire the mobile admin panel**

Update `admin_salon_detail_screen.dart` to call the new edge function instead of direct DB write.

**Step 5: Implement "on hold" separately**

"On hold" is lighter: `businesses.on_hold = true`. Salon disappears from search but no notifications sent. No confirmation dialog needed beyond a simple toggle.

**Step 6: Verify**

- Suspend a salon with pending bookings → clients receive push notifications
- Reactivate the salon → salon appears in search again
- Put salon on hold → disappears from search, no notifications

**Step 7: Commit**
```bash
git add -A
git commit -m "feat: salon suspension with booking notification cascade

Admin suspending a salon now notifies all clients with pending bookings
that protections are void and refund is available. Triple confirmation
required. Separate 'on hold' toggle for hiding from search without
notifications."
```

### Task 14: Convert Discovered→Registered Button Fix

**Context:** The "Convertir a registrado" button in salon_detail_panel.dart (line 462) should NOT bulk-convert. Instead, it should send a WA invite to the salon owner — the salon converts themselves. Rename the button to "Enviar invitacion" and merge it with the WA button (Task 9 covers this). Delete the convert button.

**Files:**
- Modify: `beautycita_web/lib/pages/admin/salon_detail_panel.dart` — remove "Convertir a registrado" button (line 460-467)

This is covered by Task 7 (remove wrong buttons) + Task 9 (wire WA invite).

---

## Phase 5: Deploy Web Changes

### Task 15: Build and Deploy Web App

**Step 1: Build web**
```bash
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter build web --release --no-tree-shake-icons
```

**Step 2: Deploy to server**
```bash
rsync -avz --delete /home/bc/futureBeauty/beautycita_web/build/web/ www-bc:/var/www/beautycita.com/frontend/dist/
```

**Step 3: Deploy edge function changes**
```bash
# rsync edge functions to server and restart
rsync -avz /home/bc/futureBeauty/beautycita_app/supabase/functions/ www-bc:/var/www/beautycita.com/supabase/functions/
ssh www-bc "cd /var/www/beautycita.com && docker compose restart functions"
```

**Step 4: Verify**
- Open beautycita.com → admin panel loads
- All export buttons download CSVs
- WA invite sends from admin
- Disputes can be reviewed and resolved
- Salon suspension shows confirmation with affected booking count

---

## Execution Order

| # | Task | Phase | Depends On |
|---|------|-------|------------|
| 1 | Commit Eros changes | 1 | — |
| 2 | Bump version + full APK release | 1 | Task 1 |
| 3 | Google One Tap email capture | 2 | Task 2 |
| 4 | Unify invite links to salon-registro | 3 | — |
| 5 | Fix SalonOnboardingScreen._submit() | 3 | — |
| 6 | Fix /registro deep links | 3 | — |
| 7 | Remove wrong admin buttons | 4 | — |
| 8 | Wire export CSV | 4 | Task 7 |
| 9 | Wire WA send from admin | 4 | Task 7 |
| 10 | Wire dispute resolution | 4 | — |
| 11 | Wire booking cancel + refund | 4 | — |
| 12 | Wire services CRUD | 4 | — |
| 13 | Salon suspension cascade | 4 | — |
| 14 | Convert button → delete (covered by 7+9) | 4 | Task 7 |
| 15 | Deploy web + edge functions | 5 | All Phase 4 |

Tasks 4-6 (Phase 3) and Tasks 7-14 (Phase 4) can be parallelized within their phases.

---

## Verification Checklist (End-to-End)

- [ ] Fresh app install → biometric → Google One Tap → email captured in user_metadata
- [ ] User dismisses One Tap → proceeds normally without email
- [ ] User taps "Invite" on discovered salon → WA opens with link to salon-registro
- [ ] Salon owner opens invite link → sees enriched data → "Es tu salon?" → OTP → account created with staff + schedule
- [ ] In-app salon onboarding → register-business called → staff + schedule created
- [ ] Admin export CSV → valid file downloads (users, salons, bookings)
- [ ] Admin send WA to discovered salon → message delivered
- [ ] Admin suspend salon → clients with pending bookings notified → refund available
- [ ] Admin put salon on hold → disappears from search, no notifications
- [ ] Admin review + resolve dispute → status updates, refund processed if applicable
- [ ] Admin cancel individual booking → client notified, refund processed
- [ ] No TODO buttons remain in admin panel — every button either works or was removed
- [ ] APK on R2 is version 0.9.2+45012 with Eros support + screenshot fix
