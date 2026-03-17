# Contact Salon Match — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scan user's phone contacts against MX salon database on-device, show matched salons with booking/invite actions, and register as Android contact action provider.

**Architecture:** Edge function serves a compact MX phone list (~38K entries). Flutter reads device contacts via `flutter_contacts`, matches locally in a HashMap. Matches display on home screen with Reservar (registered) or Invitar (discovered) actions. Android native Kotlin SyncAdapter writes "Book in BeautyCita" action to matched contacts in the system Contacts app.

**Tech Stack:** Flutter (Riverpod), flutter_contacts, Kotlin (Android SyncAdapter/AccountAuthenticator), Supabase Edge Functions

**Spec:** `docs/superpowers/specs/2026-03-16-contact-salon-match-design.md`
**Branch:** `feature/contact-salon-match`

---

## File Structure

### New (Flutter)
- `lib/services/contact_match_service.dart` — download phone list, read contacts, normalize phones, match, cache
- `lib/providers/contact_match_provider.dart` — state management for permission + matches
- `lib/widgets/contact_match_section.dart` — home screen section (CTA card or match carousel)
- `lib/widgets/contact_salon_card.dart` — individual match card (contact name + salon data + action)
- `test/services/contact_match_service_test.dart` — phone normalization + matching logic tests

### New (Android native)
- `android/app/src/main/kotlin/com/beautycita/beautycita/sync/AccountAuthenticator.kt`
- `android/app/src/main/kotlin/com/beautycita/beautycita/sync/SyncService.kt`
- `android/app/src/main/kotlin/com/beautycita/beautycita/sync/SyncAdapter.kt`
- `android/app/src/main/kotlin/com/beautycita/beautycita/sync/ContactActionActivity.kt`
- `android/app/src/main/res/xml/authenticator.xml`
- `android/app/src/main/res/xml/syncadapter.xml`

### Modified
- `lib/screens/home_screen.dart` — insert contact match section
- `beautycita_app/supabase/functions/outreach-discovered-salon/index.ts` — add `phone_list` action
- `android/app/src/main/AndroidManifest.xml` — register services
- `lib/providers/feature_toggle_provider.dart` — add `enable_contact_match` default
- `pubspec.yaml` — add `flutter_contacts` dependency

---

## Chunk 1: Backend + Service Layer

### Task 1: Edge function — phone_list action

**Files:**
- Modify: `beautycita_app/supabase/functions/outreach-discovered-salon/index.ts`

- [ ] **Step 1: Add phone_list action**

New action block after the existing `search` action. No auth required (phone numbers are not PII — they're business numbers scraped from Google). Returns compact JSON:

```typescript
if (action === "phone_list") {
  const { data: discovered } = await serviceClient
    .from("discovered_salons")
    .select("id, phone")
    .in("country", ["MX", "Mexico"])
    .not("phone", "is", null);

  const { data: registered } = await serviceClient
    .from("businesses")
    .select("id, phone")
    .eq("is_active", true)
    .not("phone", "is", null);

  const phones = [
    ...(discovered ?? []).map((s: any) => ({ p: s.phone, id: s.id, t: "d" })),
    ...(registered ?? []).map((b: any) => ({ p: b.phone, id: b.id, t: "r" })),
  ];

  return new Response(JSON.stringify({ phones, count: phones.length }), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=86400",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
```

- [ ] **Step 2: Deploy and test**

```bash
rsync -avz beautycita_app/supabase/functions/outreach-discovered-salon/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/outreach-discovered-salon/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 3: Commit**

```bash
git add beautycita_app/supabase/functions/outreach-discovered-salon/index.ts
git commit -m "feat: phone_list action — compact MX salon phone list for contact matching"
```

---

### Task 2: Add flutter_contacts + toggle default

**Files:**
- Modify: `beautycita_app/pubspec.yaml`
- Modify: `beautycita_app/lib/providers/feature_toggle_provider.dart`

- [ ] **Step 1: Add flutter_contacts dependency**

```yaml
# In dependencies:
flutter_contacts: ^1.1.9+2
```

Run `flutter pub get`.

- [ ] **Step 2: Add toggle default**

In `feature_toggle_provider.dart`, add to defaults map:
```dart
'enable_contact_match': true,
```

- [ ] **Step 3: Add toggle to production DB**

```bash
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres -c \"INSERT INTO app_config (key, value, data_type, group_name, description_es) VALUES ('enable_contact_match', 'true', 'bool', 'social', 'Escaneo de contactos para encontrar salones') ON CONFLICT (key) DO NOTHING;\""
```

- [ ] **Step 4: Commit**

```bash
git add beautycita_app/pubspec.yaml beautycita_app/lib/providers/feature_toggle_provider.dart
git commit -m "feat: add flutter_contacts dependency + enable_contact_match toggle"
```

---

### Task 3: ContactMatchService

**Files:**
- Create: `beautycita_app/lib/services/contact_match_service.dart`
- Create: `beautycita_app/test/services/contact_match_service_test.dart`

- [ ] **Step 1: Write tests for phone normalization**

Test cases:
- `+52 322 123 4567` → `+523221234567`
- `322-123-4567` → `+523221234567` (add +52 prefix)
- `52 322 123 4567` → `+523221234567`
- `(322) 123 4567` → `+523221234567`
- `3221234567` → `+523221234567` (10 digits = MX local)
- `+1 555 123 4567` → `+15551234567` (non-MX, kept as-is)

Test matching:
- Contact with phone matching a salon → returns match with salon_id + type
- Contact with no matching phone → not in results
- Multiple contacts matching same salon → deduplicated

- [ ] **Step 2: Implement ContactMatchService**

```dart
class ContactMatchService {
  static const _cacheKey = 'contact_match_phone_cache';
  static const _cacheTimestampKey = 'contact_match_cache_ts';
  static const _cacheDuration = Duration(hours: 24);

  /// Download MX salon phone list from edge function. Cache for 24h.
  Future<Map<String, SalonPhoneEntry>> fetchPhoneList({bool forceRefresh = false})

  /// Read device contacts and extract normalized phone numbers.
  Future<List<ContactEntry>> readContacts()

  /// Match contacts against salon phone list. Returns matched pairs.
  List<ContactMatch> matchContacts(
    List<ContactEntry> contacts,
    Map<String, SalonPhoneEntry> salonPhones,
  )

  /// Full flow: fetch list, read contacts, match, return results.
  Future<List<ContactMatch>> scanAndMatch()

  /// Normalize a phone number for comparison.
  static String normalizePhone(String phone)
}

class SalonPhoneEntry {
  final String id;
  final String phone; // normalized
  final String type;  // 'd' = discovered, 'r' = registered
}

class ContactEntry {
  final String displayName;
  final String? photoUri;
  final List<String> phones; // normalized
}

class ContactMatch {
  final String contactName;
  final String? contactPhotoUri;
  final String salonId;
  final String salonType; // 'd' or 'r'
  final String matchedPhone;
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/services/contact_match_service_test.dart -v
```

- [ ] **Step 4: Commit**

```bash
git add lib/services/contact_match_service.dart test/services/contact_match_service_test.dart
git commit -m "feat: ContactMatchService — on-device phone matching with MX salon list"
```

---

## Chunk 2: Provider + UI Widgets

### Task 4: ContactMatchProvider

**Files:**
- Create: `beautycita_app/lib/providers/contact_match_provider.dart`

- [ ] **Step 1: Implement provider**

```dart
enum ContactMatchStep { idle, requesting, scanning, loaded, denied, error }

class ContactMatchState {
  final ContactMatchStep step;
  final List<EnrichedMatch> matches; // ContactMatch + full salon data
  final String? error;
}

class EnrichedMatch {
  final String contactName;
  final String? contactPhotoUri;
  final Map<String, dynamic> salon; // full salon data from DB
  final String salonType; // 'd' or 'r'
  final String matchedPhone;
}
```

Notifier methods:
- `checkPermission()` — check if contacts permission already granted
- `requestAndScan()` — request permission, if granted run `scanAndMatch()`, then enrich matches with full salon data from Supabase
- `refresh()` — force re-scan (clear cache)

Enrichment: after matching, batch-fetch salon details:
```dart
// For discovered salons
final discoveredIds = matches.where((m) => m.salonType == 'd').map((m) => m.salonId).toSet();
final dData = await client.from('discovered_salons')
  .select('id, business_name, phone, location_city, feature_image_url, rating_average, rating_count, matched_categories, generated_bio')
  .inFilter('id', discoveredIds.toList());

// For registered salons
final registeredIds = matches.where((m) => m.salonType == 'r').map((m) => m.salonId).toSet();
final rData = await client.from('businesses')
  .select('id, name, phone, city, photo_url, average_rating, total_reviews, service_categories')
  .inFilter('id', registeredIds.toList());
```

Auto-generate bio for discovered salons that don't have one yet:
```dart
for (final match in enrichedMatches) {
  if (match.salonType == 'd' && match.salon['generated_bio'] == null) {
    // Fire and forget — generate bio via Aphrodite
    _generateBioInBackground(match.salon);
  }
}
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/providers/contact_match_provider.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/providers/contact_match_provider.dart
git commit -m "feat: ContactMatchProvider — permission + scan + enrich state machine"
```

---

### Task 5: Contact Salon Card + Match Section widgets

**Files:**
- Create: `beautycita_app/lib/widgets/contact_salon_card.dart`
- Create: `beautycita_app/lib/widgets/contact_match_section.dart`

- [ ] **Step 1: Build ContactSalonCard**

Compact horizontal card for the home screen carousel:
- Left: salon photo (48x48 circle) or contact photo fallback
- Center: contact name (bold, 14px), salon name below (muted, 12px), city + rating
- Right: action button
  - Registered: "Reservar" gradient button → `context.push('/booking', extra: salonId)`
  - Discovered: "Invitar" outlined button → navigate to invite detail with pre-written message

Card has subtle shadow, rounded corners, white background. Tap anywhere opens salon detail.

- [ ] **Step 2: Build ContactMatchSection**

Home screen section widget. Two states:

**Not yet scanned** (permission not granted or never asked):
```
┌─────────────────────────────────────────────┐
│ 📱 Encuentra salones en tus contactos       │
│ Busca tus estilistas favoritos              │
│                    [Buscar en contactos]     │
└─────────────────────────────────────────────┘
```
CTA card with gradient button. On tap: `requestAndScan()`.

**Matches found**:
```
Salones en tus contactos (3)
[Card] [Card] [Card] →  (horizontal scroll)
```
Section header + horizontal ListView of ContactSalonCard widgets.

**No matches**: Don't show anything (section disappears).

**Scanning**: Shimmer placeholder cards.

Gate entire section with `enable_contact_match` toggle.

- [ ] **Step 3: Analyze**

```bash
flutter analyze lib/widgets/contact_salon_card.dart lib/widgets/contact_match_section.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/contact_salon_card.dart lib/widgets/contact_match_section.dart
git commit -m "feat: contact match UI — salon cards + home screen section"
```

---

### Task 6: Wire to home screen

**Files:**
- Modify: `beautycita_app/lib/screens/home_screen.dart`

- [ ] **Step 1: Add ContactMatchSection below category grid**

Find the category grid in home_screen.dart. Below it (before the bottom padding), add:

```dart
const SizedBox(height: 16),
const ContactMatchSection(),
```

Import `contact_match_section.dart`.

The section self-gates with the toggle check internally.

- [ ] **Step 2: Trigger initial check on home screen load**

In the home screen's initState or build, trigger a permission check:
```dart
Future.microtask(() {
  ref.read(contactMatchProvider.notifier).checkPermission();
});
```

This doesn't request permission — just checks if already granted and loads cached matches if so.

- [ ] **Step 3: Analyze + test on device**

```bash
flutter analyze lib/screens/home_screen.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: contact match section on home screen"
```

---

## Chunk 3: Android Contact Action Provider (Level 2)

### Task 7: Android native — SyncAdapter + AccountAuthenticator

**Files:**
- Create: `android/app/src/main/kotlin/com/beautycita/beautycita/sync/AccountAuthenticator.kt`
- Create: `android/app/src/main/kotlin/com/beautycita/beautycita/sync/SyncService.kt`
- Create: `android/app/src/main/kotlin/com/beautycita/beautycita/sync/SyncAdapter.kt`
- Create: `android/app/src/main/res/xml/authenticator.xml`
- Create: `android/app/src/main/res/xml/syncadapter.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Create authenticator.xml**

```xml
<?xml version="1.0" encoding="utf-8"?>
<account-authenticator xmlns:android="http://schemas.android.com/apk/res/android"
    android:accountType="com.beautycita.sync"
    android:icon="@mipmap/ic_launcher"
    android:label="@string/app_name"
    android:smallIcon="@mipmap/ic_launcher" />
```

- [ ] **Step 2: Create syncadapter.xml**

```xml
<?xml version="1.0" encoding="utf-8"?>
<sync-adapter xmlns:android="http://schemas.android.com/apk/res/android"
    android:accountType="com.beautycita.sync"
    android:contentAuthority="com.android.contacts"
    android:supportsUploading="false"
    android:userVisible="false" />
```

- [ ] **Step 3: Implement AccountAuthenticator (stub)**

Minimal authenticator that satisfies Android's requirement. All methods return null/empty — we don't do actual account sync.

- [ ] **Step 4: Implement SyncService**

Service that hosts the authenticator for the system.

- [ ] **Step 5: Implement SyncAdapter**

The core: receives a list of matched contacts (via SharedPreferences or a JSON file written by Flutter), then for each match:
1. Find the existing contact by phone number
2. Create a BeautyCita RawContact linked to it
3. Insert a Data row with custom MIME type `vnd.android.cursor.item/com.beautycita.book`
4. The Data row's `DATA1` = salon_id, `DATA2` = salon_name, `DATA3` = "d" or "r"

- [ ] **Step 6: Register in AndroidManifest.xml**

Add services, permissions, and the authenticator/sync-adapter meta-data.

```xml
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.WRITE_CONTACTS" />
<uses-permission android:name="android.permission.GET_ACCOUNTS" />

<service android:name=".sync.SyncService" android:exported="false">
    <intent-filter>
        <action android:name="android.content.SyncAdapter" />
    </intent-filter>
    <meta-data android:name="android.content.SyncAdapter" android:resource="@xml/syncadapter" />
    <meta-data android:name="android.provider.CONTACTS_STRUCTURE" android:resource="@xml/contacts" />
</service>
```

- [ ] **Step 7: Commit**

```bash
git add android/
git commit -m "feat(android): SyncAdapter + AccountAuthenticator for contact action provider"
```

---

### Task 8: ContactActionActivity + Flutter MethodChannel bridge

**Files:**
- Create: `android/app/src/main/kotlin/com/beautycita/beautycita/sync/ContactActionActivity.kt`
- Modify: `beautycita_app/lib/services/contact_match_service.dart` — add MethodChannel call

- [ ] **Step 1: Implement ContactActionActivity**

Activity launched when user taps "Book in BeautyCita" in native contacts. Reads salon_id from intent data, launches Flutter app with deep link to booking or invite flow.

```kotlin
class ContactActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val data = intent.data
        val salonId = data?.getQueryParameter("salon_id") ?: ""
        val salonType = data?.getQueryParameter("type") ?: "d"

        // Launch main Flutter activity with deep link
        val intent = Intent(this, MainActivity::class.java)
        intent.putExtra("route", if (salonType == "r") "/booking/$salonId" else "/invite/detail/$salonId")
        startActivity(intent)
        finish()
    }
}
```

Register in manifest with the custom MIME type intent filter.

- [ ] **Step 2: Add MethodChannel to trigger sync from Flutter**

In `contact_match_service.dart`, add:
```dart
static const _channel = MethodChannel('com.beautycita/contact_sync');

/// Trigger Android SyncAdapter to write BeautyCita actions to matched contacts.
/// Only works on Android. No-op on iOS.
Future<void> syncContactActions(List<ContactMatch> matches) async {
  if (!Platform.isAndroid) return;
  try {
    final matchJson = matches.map((m) => {
      'phone': m.matchedPhone,
      'salon_id': m.salonId,
      'salon_type': m.salonType,
      'salon_name': m.contactName,
    }).toList();
    await _channel.invokeMethod('syncContacts', {'matches': matchJson});
  } catch (e) {
    debugPrint('[ContactMatch] Android sync failed: $e');
  }
}
```

- [ ] **Step 3: Wire MethodChannel in MainActivity.kt**

Handle `syncContacts` method call — write matches to SharedPreferences, then trigger SyncAdapter.

- [ ] **Step 4: Commit**

```bash
git add android/ lib/services/contact_match_service.dart
git commit -m "feat(android): ContactActionActivity + MethodChannel bridge for contact sync"
```

---

## Chunk 4: Integration + Deploy

### Task 9: Auto-generate bios for matched discovered salons

**Files:**
- Modify: `beautycita_app/lib/providers/contact_match_provider.dart`

- [ ] **Step 1: Add background bio generation**

After enrichment, for each discovered salon match without a `generated_bio`, fire a background call to Aphrodite:

```dart
for (final match in enrichedMatches.where((m) => m.salonType == 'd')) {
  if (match.salon['generated_bio'] == null) {
    // Generate bio + invite message in background
    unawaited(_preGenerateContent(match));
  }
}

Future<void> _preGenerateContent(EnrichedMatch match) async {
  try {
    final salon = match.salon;
    await SupabaseClientService.client.functions.invoke('aphrodite-chat', body: {
      'action': 'generate_salon_bio',
      'salon_name': salon['business_name'],
      'salon_category': (salon['matched_categories'] as List?)?.firstOrNull ?? '',
      'salon_city': salon['location_city'] ?? '',
      'salon_rating': salon['rating_average'],
      'salon_review_count': salon['rating_count'],
      'discovered_salon_id': salon['id'],
    });
  } catch (e) {
    debugPrint('[ContactMatch] Bio pre-gen failed: $e');
  }
}
```

This means when the user taps a discovered match, the bio is already cached and the invite detail screen loads instantly with content.

- [ ] **Step 2: Pre-generate invite message**

When user taps a discovered match → navigate to invite detail. The invite screen already auto-generates the message on load. But we can pre-generate it here too so it's instant:

Actually, the invite detail screen handles this. No extra work needed — just navigate to `/invite/detail` with the salon data.

- [ ] **Step 3: Commit**

```bash
git add lib/providers/contact_match_provider.dart
git commit -m "feat: auto-generate Aphrodite bios for matched discovered salons"
```

---

### Task 10: Tests + Deploy

**Files:**
- All test files from previous tasks

- [ ] **Step 1: Run all tests**

```bash
cd beautycita_app && flutter test test/services/contact_match_service_test.dart -v
flutter analyze lib/services/contact_match_service.dart lib/providers/contact_match_provider.dart lib/widgets/contact_salon_card.dart lib/widgets/contact_match_section.dart lib/screens/home_screen.dart
```

- [ ] **Step 2: Deploy edge function**

```bash
rsync -avz beautycita_app/supabase/functions/outreach-discovered-salon/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/outreach-discovered-salon/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 3: Build APK for testing**

```bash
cd beautycita_app && export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
flutter build apk --split-per-abi \
  --dart-define=SUPABASE_URL=https://beautycita.com/supabase \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjE4OTM0NTYwMDB9.rz0oLwpK6HMsRI3PStAW3K1gl79d6z1PqqW8lvCtF9Q
```

- [ ] **Step 4: Manual test on Android device**

1. Install APK on test device
2. Grant contacts permission
3. Verify salon matches appear on home screen
4. Tap discovered match → invite detail with bio + pre-written message
5. Tap registered match → booking flow
6. Open native Contacts app → find a matched contact → verify "Book in BeautyCita" action appears
7. Tap the action → app opens to correct screen

- [ ] **Step 5: Trigger IPA build**

Push to feature branch, trigger GitHub Actions. Note: Level 2 (contact actions) is Android-only. iOS only gets Level 1.

- [ ] **Step 6: Merge to main + final deploy**

```bash
git checkout main
git merge feature/contact-salon-match --no-ff
git push origin main
```

Upload APK + IPA to R2, update version.json.
