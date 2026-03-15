# iOS Build + AltStore Distribution Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate Shorebird, build a production iOS IPA via GitHub Actions, distribute via AltStore on beautypi, and add WA fallback for push notifications on iOS.

**Architecture:** Remove Shorebird dependency entirely, rewrite updater_service.dart to Android-only R2 version check, add WA message alongside every FCM push in send-push-notification edge function, set up GitHub Actions for unsigned IPA builds, and configure AltStore on beautypi (ARM64 Debian) for sideloading to 3-4 testers via Tailscale.

**Tech Stack:** Flutter 3.38.9, GitHub Actions (macOS runner), AltServer-Linux (aarch64), anisette-server (Docker), netmuxd, Cloudflare R2, Deno edge functions

---

## Chunk 1: Shorebird Removal + Updater Rewrite

### Task 1: Remove Shorebird from pubspec.yaml and assets

**Files:**
- Modify: `beautycita_app/pubspec.yaml:51` (remove shorebird_code_push dep)
- Modify: `beautycita_app/pubspec.yaml:69` (remove shorebird.yaml asset)
- Delete: `beautycita_app/shorebird.yaml`

- [ ] **Step 1: Remove shorebird_code_push dependency from pubspec.yaml**

In `beautycita_app/pubspec.yaml`, remove line 51:
```yaml
  shorebird_code_push: ^2.0.5
```

- [ ] **Step 2: Remove shorebird.yaml from flutter assets**

In `beautycita_app/pubspec.yaml`, remove line 69:
```yaml
    - shorebird.yaml
```

- [ ] **Step 3: Delete shorebird.yaml**

```bash
rm /home/bc/futureBeauty/beautycita_app/shorebird.yaml
```

- [ ] **Step 4: Run flutter pub get to regenerate lock file**

```bash
cd /home/bc/futureBeauty/beautycita_app && flutter pub get
```
Expected: No errors. `shorebird_code_push` removed from pubspec.lock.

- [ ] **Step 5: Verify shorebird is gone from pubspec.lock**

```bash
grep -i shorebird /home/bc/futureBeauty/beautycita_app/pubspec.lock
```
Expected: No output (no matches).

- [ ] **Step 6: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/pubspec.yaml beautycita_app/pubspec.lock
git rm beautycita_app/shorebird.yaml
git commit -m "chore: remove Shorebird dependency — eliminated from project

Shorebird doesn't support --split-per-abi, making it useless for
self-distributed APKs. Using plain flutter build + R2 version.json."
```

---

### Task 2: Rewrite updater_service.dart (remove Shorebird, add Platform guard)

**Files:**
- Modify: `beautycita_app/lib/services/updater_service.dart`

- [ ] **Step 1: Rewrite updater_service.dart**

Replace the entire contents of `beautycita_app/lib/services/updater_service.dart` with:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// OTA updater — checks R2 version.json for newer APK builds.
/// Android only. iOS uses AltStore for updates.
class UpdaterService {
  static final UpdaterService _instance = UpdaterService._();
  static UpdaterService get instance => _instance;
  UpdaterService._();

  // ── APK update state ──
  bool _apkUpdateAvailable = false;
  bool _apkUpdateRequired = false;
  String _apkUpdateUrl = '';
  String _apkUpdateVersion = '';
  int _remoteBuildNumber = 0;

  bool get apkUpdateAvailable => _apkUpdateAvailable;
  bool get apkUpdateRequired => _apkUpdateRequired;
  String get apkUpdateUrl => _apkUpdateUrl;
  String get apkUpdateVersion => _apkUpdateVersion;
  int get apkRemoteBuild => _remoteBuildNumber;

  /// Check R2 for a newer APK version. Non-blocking, fail-silent.
  /// Skipped on iOS — AltStore handles updates there.
  Future<void> checkForApkUpdate() async {
    // iOS uses AltStore for updates, not R2
    if (!Platform.isAndroid) {
      debugPrint('[Updater] Skipping APK check (not Android)');
      return;
    }

    try {
      final response = await http
          .get(Uri.parse(AppConstants.versionCheckUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint('[Updater] version.json fetch failed: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteBuild = data['build'] as int? ?? 0;
      final remoteVersion = data['version'] as String? ?? '';
      final url = data['url'] as String? ?? '';
      final required = data['required'] as bool? ?? true;

      final localBase = AppConstants.baseBuildNumber;
      if (remoteBuild <= localBase) {
        debugPrint('[Updater] APK is current (local=$localBase [raw=${AppConstants.buildNumber}], remote=$remoteBuild)');
        return;
      }

      // Skip if user dismissed this build recently (unless required)
      if (!required && await _isDismissedRecently(remoteBuild)) {
        debugPrint('[Updater] APK update $remoteBuild dismissed recently, skipping');
        return;
      }

      _apkUpdateAvailable = true;
      _apkUpdateRequired = required;
      _apkUpdateUrl = url;
      _apkUpdateVersion = remoteVersion;
      _remoteBuildNumber = remoteBuild;
      debugPrint('[Updater] APK update available: $remoteVersion (build $remoteBuild), required=$required');
    } catch (e) {
      debugPrint('[Updater] APK version check failed: $e');
    }
  }

  /// Record that the user dismissed the update dialog for this build.
  Future<void> dismissApkUpdate() async {
    _apkUpdateAvailable = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyUpdateDismissedBuild, _remoteBuildNumber);
      await prefs.setString(
          AppConstants.keyUpdateDismissedAt, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[Updater] Failed to save dismissal: $e');
    }
  }

  Future<bool> _isDismissedRecently(int remoteBuild) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedBuild =
          prefs.getInt(AppConstants.keyUpdateDismissedBuild) ?? 0;
      if (dismissedBuild != remoteBuild) return false;

      final dismissedAtStr =
          prefs.getString(AppConstants.keyUpdateDismissedAt);
      if (dismissedAtStr == null) return false;

      final dismissedAt = DateTime.tryParse(dismissedAtStr);
      if (dismissedAt == null) return false;

      return DateTime.now().difference(dismissedAt) <
          AppConstants.updateDismissCooldown;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 2: Update splash_screen.dart — remove Shorebird checkAndUpdate call**

In `beautycita_app/lib/screens/splash_screen.dart`, find lines 80-83:
```dart
    // OTA update check (silent, non-blocking — downloads patch in background)
    UpdaterService.instance.checkAndUpdate();
    // APK version check (result checked after home screen loads)
    UpdaterService.instance.checkForApkUpdate();
```

Replace with:
```dart
    // APK version check (result checked after home screen loads)
    // Skipped on iOS — AltStore handles updates there.
    UpdaterService.instance.checkForApkUpdate();
```

- [ ] **Step 3: Verify no remaining shorebird imports**

```bash
grep -rn "shorebird" /home/bc/futureBeauty/beautycita_app/lib/
```
Expected: No output.

- [ ] **Step 4: Run analyzer**

```bash
cd /home/bc/futureBeauty/beautycita_app && flutter analyze
```
Expected: No errors. (Warnings OK.)

- [ ] **Step 5: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/lib/services/updater_service.dart beautycita_app/lib/screens/splash_screen.dart
git commit -m "refactor: rewrite updater service — remove Shorebird, add Platform.isAndroid guard

Tier 1 (Shorebird OTA) removed entirely. Tier 2 (R2 version.json)
kept with Platform.isAndroid guard so iOS skips APK update checks."
```

---

### Task 3: Update updater_service_test.dart

**Files:**
- Modify: `beautycita_app/test/services/updater_service_test.dart`

- [ ] **Step 1: Remove Shorebird reference from test file comment**

In `beautycita_app/test/services/updater_service_test.dart`, replace line 9:
```dart
// rather than mocking the full UpdaterService (which wraps Shorebird).
```
with:
```dart
// rather than mocking the full UpdaterService singleton.
```

- [ ] **Step 2: Run tests**

```bash
cd /home/bc/futureBeauty/beautycita_app && flutter test test/services/updater_service_test.dart
```
Expected: All 8 tests pass.

- [ ] **Step 3: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/test/services/updater_service_test.dart
git commit -m "test: update updater_service_test — remove Shorebird reference"
```

---

### Task 4: Verify Android build still works

- [ ] **Step 1: Build Android APK with split-per-abi**

```bash
cd /home/bc/futureBeauty/beautycita_app
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
flutter build apk --split-per-abi \
  --dart-define=SUPABASE_URL=https://beautycita.com/supabase \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjE4OTM0NTYwMDB9.rz0oLwpK6HMsRI3PStAW3K1gl79d6z1PqqW8lvCtF9Q
```
Expected: Build succeeds. `app-arm64-v8a-release.apk` ~57MB.

- [ ] **Step 2: Verify APK size**

```bash
ls -lh /home/bc/futureBeauty/beautycita_app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
Expected: ~55-60MB (NOT 138MB).

---

## Chunk 2: WA Fallback for Push Notifications

### Task 5: Add WA fallback to send-push-notification edge function

**Files:**
- Modify: `beautycita_app/supabase/functions/send-push-notification/index.ts`

The `send-push-notification` function already handles FCM pushes. We add a WA message as fallback — sent alongside every FCM push. If FCM fails (no token, iOS sideload, etc.), the user still gets notified via WhatsApp.

**Prerequisite check:** Verify `BEAUTYPI_WA_URL` and `BEAUTYPI_WA_TOKEN` are set in production:
```bash
ssh www-bc "grep BEAUTYPI /var/www/beautycita.com/bc-flutter/supabase-docker/.env"
```
Expected: Both vars present with non-empty values.

- [ ] **Step 1: Add WA env vars and helper function**

In `beautycita_app/supabase/functions/send-push-notification/index.ts`, after line 21 (`const supabase = ...`), add:

```typescript
const BEAUTYPI_WA_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const BEAUTYPI_WA_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";

/** Send a WhatsApp message as push notification fallback */
async function sendWhatsAppFallback(
  phone: string,
  title: string,
  body: string
): Promise<boolean> {
  if (!BEAUTYPI_WA_URL || !phone) return false;
  try {
    const message = `*${title}*\n${body}`;
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 5000);
    const res = await fetch(`${BEAUTYPI_WA_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${BEAUTYPI_WA_TOKEN}`,
      },
      body: JSON.stringify({ phone, message }),
      signal: ac.signal,
    });
    clearTimeout(t);
    const ok = res.ok;
    console.log(`[WA-FALLBACK] ${ok ? "Sent" : "Failed"} to ${phone}`);
    return ok;
  } catch (e) {
    console.error("[WA-FALLBACK] Error:", e);
    return false;
  }
}
```

- [ ] **Step 2: Add phone fields to getBookingContext and custom notification path**

In `beautycita_app/supabase/functions/send-push-notification/index.ts`:

**2a.** In `getBookingContext`, update the profile select (around line 282):
```typescript
// BEFORE:
    .select("id, full_name, fcm_token")
// AFTER:
    .select("id, full_name, fcm_token, phone")
```

**2b.** Update the business select (around line 288):
```typescript
// BEFORE:
    .select("id, name, fcm_token")
// AFTER:
    .select("id, name, fcm_token, phone")
```

**2c.** Add phone fields to the return object (around line 301):
```typescript
  return {
    booking_id: booking.id,
    client_id: profile?.id,
    client_name: profile?.full_name || "Cliente",
    client_fcm_token: profile?.fcm_token,
    client_phone: profile?.phone || null,
    business_id: business?.id,
    business_name: business?.name || "Salón",
    business_fcm_token: business?.fcm_token,
    business_phone: business?.phone || null,
    service_name: booking.service_name || "servicio",
    staff_name: booking.staff_name || "",
    formatted_time: formattedTime,
    start_time: startTime,
  };
```

**2d.** In the custom notification path (around line 410), update variable declarations:
```typescript
    let fcmToken: string | null = null;
    let recipientPhone: string | null = null;
    let notificationContent: NotificationContent;
```

**2e.** Update the custom notification profile select (around line 418) to also fetch phone:
```typescript
// BEFORE:
        const { data: profile } = await supabase
          .from("profiles")
          .select("fcm_token")
          .eq("id", user_id)
          .single();
        fcmToken = profile?.fcm_token;
// AFTER:
        const { data: profile } = await supabase
          .from("profiles")
          .select("fcm_token, phone")
          .eq("id", user_id)
          .single();
        fcmToken = profile?.fcm_token;
        recipientPhone = profile?.phone || null;
```

**2f.** Similarly for the business custom notification select (around line 426):
```typescript
// BEFORE:
        const { data: business } = await supabase
          .from("businesses")
          .select("fcm_token")
          .eq("id", business_id)
          .single();
        fcmToken = business?.fcm_token;
// AFTER:
        const { data: business } = await supabase
          .from("businesses")
          .select("fcm_token, phone")
          .eq("id", business_id)
          .single();
        fcmToken = business?.fcm_token;
        recipientPhone = business?.phone || null;
```

- [ ] **Step 3: Add recipientPhone extraction to template notification switch block**

In the booking-based notification switch (around line 447), add `recipientPhone` alongside `fcmToken`. Replace the entire switch block:

```typescript
      let recipientPhone: string | null = null;

      switch (notification_type) {
        case "new_booking":
          fcmToken = ctx.business_fcm_token;
          recipientPhone = ctx.business_phone;
          break;
        case "booking_confirmed":
        case "booking_reminder":
          fcmToken = ctx.client_fcm_token;
          recipientPhone = ctx.client_phone;
          ctx.time_until = getTimeUntil(ctx.start_time);
          break;
        case "booking_cancelled":
          ctx.is_provider = !!business_id;
          fcmToken = ctx.is_provider
            ? ctx.business_fcm_token
            : ctx.client_fcm_token;
          recipientPhone = ctx.is_provider
            ? ctx.business_phone
            : ctx.client_phone;
          break;
      }
```

- [ ] **Step 4: Replace FCM-only send block with FCM + WA fallback**

Replace lines 480-500 (the `if (!fcmToken)` block through the final response) with:

```typescript
    let fcmSent = false;
    if (fcmToken) {
      fcmSent = await sendFcmNotification(fcmToken, notificationContent);
    } else {
      console.log("[FCM] No FCM token for recipient, skipping push");
    }

    // WA fallback — covers iOS sideload (no APNs) and FCM failures
    let waSent = false;
    if (recipientPhone) {
      waSent = await sendWhatsAppFallback(
        recipientPhone,
        notificationContent.title,
        notificationContent.body
      );
    }

    return new Response(
      JSON.stringify({
        success: fcmSent || waSent,
        fcm: fcmSent ? "sent" : (fcmToken ? "failed" : "no_token"),
        whatsapp: waSent ? "sent" : (recipientPhone ? "failed" : "no_phone"),
        notification_type,
        title: notificationContent.title,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
```

- [ ] **Step 5: Deploy edge function to production**

```bash
rsync -avz /home/bc/futureBeauty/beautycita_app/supabase/functions/send-push-notification/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/send-push-notification/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 6: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/supabase/functions/send-push-notification/index.ts
git commit -m "feat: add WhatsApp fallback to push notifications

Every FCM push now also sends a WhatsApp message to the recipient.
Covers iOS sideload (no APNs) and FCM failures. Uses existing
BEAUTYPI_WA_URL infrastructure."
```

---

### Task 6: Guard FCM initialization on iOS

**Files:**
- Modify: `beautycita_app/lib/services/notification_service.dart`

On iOS with free sideloading, there's no APNs certificate so FCM can't register a device token. The entire FCM initialization (token registration, foreground handlers, background handlers) is pointless on iOS — all notifications come via WhatsApp instead. This early return is intentional.

- [ ] **Step 1: Add Platform guard to NotificationService.initialize()**

In `beautycita_app/lib/services/notification_service.dart`, add `import 'dart:io';` at the top (after `import 'dart:async';`).

Then in the `initialize()` method, after the feature toggle check (after line 67), add:

```dart
    // iOS sideload (free Apple ID) has no APNs certificate.
    // Skip ALL FCM initialization — no token registration, no foreground
    // handlers, no background handlers. All notifications come via WhatsApp.
    // This early return is intentional — not just token registration.
    if (Platform.isIOS) {
      debugPrint('[Notifications] iOS sideload — skipping FCM entirely (no APNs)');
      return;
    }
```

- [ ] **Step 2: Run analyzer**

```bash
cd /home/bc/futureBeauty/beautycita_app && flutter analyze
```
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/lib/services/notification_service.dart
git commit -m "fix: skip FCM initialization on iOS sideload (no APNs)

Free Apple ID sideloading has no APNs certificate. FCM would fail
noisily trying to register. All notifications go via WhatsApp on iOS.
Intentionally skips entire FCM init, not just token registration."
```

---

### Task 6b: Add persistent "Report Screenshot" button for iOS testers

**Files:**
- Modify: `beautycita_app/lib/main.dart` (add global overlay)
- Create: `beautycita_app/lib/widgets/screenshot_report_button.dart`

On Android, `ScreenshotDetectorService` auto-detects screenshots via ContentObserver. On iOS there's no equivalent API. Instead, we add a persistent floating button that opens the photo picker → user selects screenshot → editor opens. This button should be the first thing visible — showing even during splash/loading — and remain accessible on every screen.

- [ ] **Step 1: Create screenshot_report_button.dart**

Create `beautycita_app/lib/widgets/screenshot_report_button.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/screenshot_editor_screen.dart';

/// Persistent floating button for iOS testers to report screenshots.
/// On Android, screenshots are auto-detected — this button is iOS-only.
/// Positioned as a small draggable FAB so it doesn't obstruct the UI.
class ScreenshotReportButton extends StatefulWidget {
  const ScreenshotReportButton({super.key});

  @override
  State<ScreenshotReportButton> createState() => _ScreenshotReportButtonState();
}

class _ScreenshotReportButtonState extends State<ScreenshotReportButton> {
  // Draggable position — starts bottom-right
  Offset _position = const Offset(-1, -1); // sentinel for "not initialized"
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    // Only show on iOS
    if (!Platform.isIOS) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    // Initialize position on first build: bottom-right with padding
    if (_position.dx < 0) {
      _position = Offset(
        mq.size.width - 64,
        mq.size.height - mq.padding.bottom - 120,
      );
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
            // Clamp to screen bounds
            _position = Offset(
              _position.dx.clamp(0, mq.size.width - 48),
              _position.dy.clamp(mq.padding.top, mq.size.height - 48),
            );
          });
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _picking ? null : _pickAndReport,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _picking
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndReport() async {
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScreenshotEditorScreen(screenshotBytes: bytes),
        ),
      );
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }
}
```

- [ ] **Step 2: Add the overlay to the app's root widget**

In `beautycita_app/lib/main.dart`, wrap the `MaterialApp.router` (or equivalent root widget) with an `Overlay` or `Stack` that includes the `ScreenshotReportButton`. The simplest approach:

Find the `MaterialApp.router(` widget in `main.dart` and wrap its `builder` parameter to add the overlay:

```dart
builder: (context, child) {
  return Stack(
    children: [
      child ?? const SizedBox.shrink(),
      const ScreenshotReportButton(),
    ],
  );
},
```

Add the import at the top of `main.dart`:
```dart
import 'widgets/screenshot_report_button.dart';
```

This ensures the button is present on every screen, including splash, because it's above the router in the widget tree.

- [ ] **Step 3: Run analyzer**

```bash
cd /home/bc/futureBeauty/beautycita_app && flutter analyze
```
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/lib/widgets/screenshot_report_button.dart beautycita_app/lib/main.dart
git commit -m "feat: persistent screenshot report button for iOS testers

Floating draggable FAB on iOS — picks photo from gallery, opens
screenshot editor, sends to BC via WhatsApp. Visible on every screen
including splash. Android uses auto-detection instead."
```

---

## Chunk 3: GitHub Actions CI for iOS IPA Build

### Task 7: Create GitHub Actions workflow for iOS builds

**Files:**
- Create: `.github/workflows/build-ios.yml`

**Note:** `flutter build ipa --no-codesign` produces an `.xcarchive` in `build/ios/archive/`. To get a distributable `.ipa` from the unsigned archive, we create it manually by packaging the `.app` from the archive. AltStore needs the `.ipa` file, not the `.xcarchive`.

- [ ] **Step 1: Create .github/workflows directory**

```bash
mkdir -p /home/bc/futureBeauty/.github/workflows
```

- [ ] **Step 2: Create build-ios.yml workflow**

Create `.github/workflows/build-ios.yml`:

```yaml
name: Build iOS IPA

on:
  workflow_dispatch:
    inputs:
      build_note:
        description: 'Build note (optional)'
        required: false
        default: ''

jobs:
  build:
    runs-on: macos-latest
    timeout-minutes: 30

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.9'
          channel: 'stable'
          cache: true

      - name: Install dependencies
        working-directory: beautycita_app
        run: flutter pub get

      - name: Run analyzer
        working-directory: beautycita_app
        run: flutter analyze --no-fatal-infos

      - name: Build unsigned xcarchive
        working-directory: beautycita_app
        run: |
          flutter build ipa --no-codesign \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}

      - name: Package xcarchive into IPA
        working-directory: beautycita_app
        run: |
          # Find the .app inside the xcarchive
          ARCHIVE_PATH=$(find build/ios/archive -name "*.xcarchive" -maxdepth 1 | head -1)
          if [ -z "$ARCHIVE_PATH" ]; then
            echo "ERROR: No xcarchive found"
            exit 1
          fi
          echo "Found archive: $ARCHIVE_PATH"

          # Create IPA structure: Payload/Runner.app
          mkdir -p /tmp/ipa-payload/Payload
          cp -r "$ARCHIVE_PATH/Products/Applications/"*.app /tmp/ipa-payload/Payload/

          # Zip into .ipa
          mkdir -p build/ios/ipa
          cd /tmp/ipa-payload
          zip -r "$GITHUB_WORKSPACE/beautycita_app/build/ios/ipa/beautycita.ipa" Payload
          echo "IPA created at build/ios/ipa/beautycita.ipa"
          ls -lh "$GITHUB_WORKSPACE/beautycita_app/build/ios/ipa/beautycita.ipa"

      - name: Upload IPA artifact
        uses: actions/upload-artifact@v4
        with:
          name: beautycita-ios-${{ github.run_number }}
          path: beautycita_app/build/ios/ipa/beautycita.ipa
          retention-days: 30
          if-no-files-found: error
```

- [ ] **Step 3: Commit**

```bash
cd /home/bc/futureBeauty
git add .github/workflows/build-ios.yml
git commit -m "ci: add GitHub Actions workflow for unsigned iOS IPA builds

Manual trigger, macOS runner, flutter build ipa --no-codesign.
Packages xcarchive into IPA for AltStore distribution.
Secrets: SUPABASE_URL, SUPABASE_ANON_KEY."
```

- [ ] **Step 4: Set up GitHub repository secrets**

```bash
cd /home/bc/futureBeauty
gh secret set SUPABASE_URL --body "https://beautycita.com/supabase"
gh secret set SUPABASE_ANON_KEY --body "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjE4OTM0NTYwMDB9.rz0oLwpK6HMsRI3PStAW3K1gl79d6z1PqqW8lvCtF9Q"
```

- [ ] **Step 5: Push and trigger first build**

```bash
cd /home/bc/futureBeauty
git push origin main
gh workflow run build-ios.yml
```

Monitor:
```bash
gh run list --workflow=build-ios.yml --limit 1
gh run watch  # watch the latest run
```

---

## Chunk 4: AltStore on beautypi

### Task 8: Install AltServer-Linux on beautypi

**Prerequisites:** beautypi (100.93.1.103) must be reachable via Tailscale.

- [ ] **Step 1: SSH into beautypi and check architecture**

```bash
ssh dmyl@100.93.1.103 "uname -m && cat /etc/os-release | head -3"
```
Expected: `aarch64`, Debian Bookworm.

- [ ] **Step 2: Install AltServer-Linux dependencies**

```bash
ssh dmyl@100.93.1.103 "sudo apt update && sudo apt install -y libavahi-client3 usbmuxd avahi-daemon"
```

- [ ] **Step 3: Download and install AltServer-Linux for ARM64**

```bash
ssh dmyl@100.93.1.103 << 'REMOTE'
mkdir -p ~/altstore
cd ~/altstore

# Try downloading pre-built aarch64 binary
curl -L -o altserver https://github.com/NyaMisty/AltServer-Linux/releases/latest/download/AltServer-aarch64 2>/dev/null

# Verify the binary actually runs (not a 404 HTML page)
if ./altserver --version 2>/dev/null; then
  echo "Pre-built binary works"
else
  echo "Pre-built binary not available or incompatible, building from source..."
  rm -f altserver
  sudo apt install -y cargo pkg-config libssl-dev libavahi-client-dev
  git clone https://github.com/NyaMisty/AltServer-Linux.git src 2>/dev/null || (cd src && git pull)
  cd src
  cargo build --release
  cp target/release/AltServer ../altserver
  cd ..
  ./altserver --version
fi
REMOTE
```

- [ ] **Step 4: Set up anisette-server (Docker)**

```bash
ssh dmyl@100.93.1.103 << 'REMOTE'
# Pull and run anisette-server (provides Apple auth tokens)
# Pin to specific tag to avoid breakage
docker pull dadoum/anisette-v3-server:latest
docker run -d \
  --name anisette \
  --restart unless-stopped \
  -p 6969:6969 \
  -v anisette-data:/home/Alcoholic/.config/anisette-v3/lib \
  dadoum/anisette-v3-server:latest

# Verify it responds
sleep 3
curl -s http://localhost:6969 | head -5
REMOTE
```
Expected: JSON response with anisette data.

- [ ] **Step 5: Install netmuxd for network device discovery**

```bash
ssh dmyl@100.93.1.103 << 'REMOTE'
cd ~/altstore

# Try downloading pre-built aarch64 binary
curl -L -o netmuxd https://github.com/jkcoxson/netmuxd/releases/latest/download/netmuxd-aarch64-linux 2>/dev/null

# Verify the binary actually runs (not a 404 HTML page)
if ./netmuxd --help 2>/dev/null; then
  echo "Pre-built netmuxd binary works"
else
  echo "Pre-built binary not available, building from source..."
  rm -f netmuxd
  sudo apt install -y cargo
  git clone https://github.com/jkcoxson/netmuxd.git src-netmuxd 2>/dev/null || (cd src-netmuxd && git pull)
  cd src-netmuxd
  cargo build --release
  cp target/release/netmuxd ../netmuxd
  cd ..
  chmod +x netmuxd
fi

# Verify supported flags
./netmuxd --help 2>&1 | head -20
REMOTE
```

- [ ] **Step 6: Verify all components**

```bash
ssh dmyl@100.93.1.103 << 'REMOTE'
echo "=== AltServer ==="
~/altstore/altserver --version 2>&1 || echo "FAILED"
echo "=== anisette ==="
curl -s http://localhost:6969 | head -3 || echo "FAILED"
echo "=== netmuxd ==="
~/altstore/netmuxd --help 2>&1 | head -3 || echo "FAILED"
REMOTE
```

---

### Task 9: Create systemd services for AltStore components

- [ ] **Step 1: Verify anisette is running as Docker container**

Already running with `--restart unless-stopped`. Verify:
```bash
ssh dmyl@100.93.1.103 "docker ps --filter name=anisette --format '{{.Status}}'"
```
Expected: "Up X minutes/hours"

- [ ] **Step 2: Create netmuxd systemd service**

First check what flags netmuxd actually supports:
```bash
ssh dmyl@100.93.1.103 "~/altstore/netmuxd --help 2>&1"
```

Then create the service with the correct flags:
```bash
ssh dmyl@100.93.1.103 << 'REMOTE'
# Use flags confirmed from --help output
sudo tee /etc/systemd/system/netmuxd.service > /dev/null << 'EOF'
[Unit]
Description=netmuxd - Network USB Muxer
After=network-online.target avahi-daemon.service
Wants=network-online.target

[Service]
Type=simple
User=dmyl
ExecStart=/home/dmyl/altstore/netmuxd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable netmuxd
sudo systemctl start netmuxd
sudo systemctl status netmuxd
REMOTE
```

Note: The ExecStart command may need flags like `--disable-unix` or `--mdns-timeout 30` depending on the version. Check `--help` output and adjust before creating the service.

- [ ] **Step 3: Create AltServer systemd service**

```bash
ssh dmyl@100.93.1.103 << 'REMOTE'
sudo tee /etc/systemd/system/altserver.service > /dev/null << 'EOF'
[Unit]
Description=AltServer-Linux
After=network-online.target netmuxd.service
Wants=network-online.target
Requires=netmuxd.service

[Service]
Type=simple
User=dmyl
Environment=ALTSERVER_ANISETTE_URL=http://localhost:6969
ExecStart=/home/dmyl/altstore/altserver
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable altserver
sudo systemctl start altserver
sudo systemctl status altserver
REMOTE
```

---

### Task 10: Install AltStore on test devices and configure IPA distribution

**Prerequisite:** AltStore must be installed on each test iPhone FIRST, before any app can be sideloaded. AltServer handles this.

- [ ] **Step 1: Install AltStore on BC's iPhone via AltServer**

Connect BC's iPhone to the same Tailscale network as beautypi, then:
```bash
ssh dmyl@100.93.1.103 << 'REMOTE'
# Pair the device first (may need to trust the computer on the phone)
~/altstore/altserver --apple-id beautycita@icloud.com --password "Dv4801431a." --install-altstore
REMOTE
```

On the iPhone: Settings → General → Device Management → trust the profile.

- [ ] **Step 2: Download IPA from GitHub Actions artifact**

After the GitHub Actions build completes:
```bash
cd /home/bc/futureBeauty
# Use the artifact name from the workflow run
RUN_NUM=$(gh run list --workflow=build-ios.yml --limit 1 --json databaseId -q '.[0].databaseId')
gh run download $RUN_NUM --name "beautycita-ios-*" --dir /tmp/ios-build/ 2>/dev/null || \
gh run download $RUN_NUM --dir /tmp/ios-build/
ls -lh /tmp/ios-build/
```

- [ ] **Step 3: Upload IPA to R2**

```bash
# Get actual file size for source JSON
IPA_PATH=$(find /tmp/ios-build/ -name "*.ipa" | head -1)
IPA_SIZE=$(stat -c%s "$IPA_PATH")
echo "IPA size: $IPA_SIZE bytes"

aws s3 cp "$IPA_PATH" \
  s3://beautycita-medias/ipa/beautycita.ipa --profile r2 \
  --content-type application/octet-stream
```

- [ ] **Step 4: Upload app icon for AltStore source**

```bash
aws s3 cp /home/bc/futureBeauty/beautycita_app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png \
  s3://beautycita-medias/ipa/icon.png --profile r2 \
  --content-type image/png
```

- [ ] **Step 5: Create and upload AltStore source JSON (with actual IPA size)**

```bash
IPA_PATH=$(find /tmp/ios-build/ -name "*.ipa" | head -1)
IPA_SIZE=$(stat -c%s "$IPA_PATH")

cat > /tmp/altstore-source.json << EOF
{
  "name": "BeautyCita",
  "identifier": "com.beautycita.apps",
  "sourceURL": "https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/ipa/altstore-source.json",
  "apps": [
    {
      "name": "BeautyCita",
      "bundleIdentifier": "com.beautycita.beautycita",
      "developerName": "BeautyCita S.A. de C.V.",
      "version": "1.0.6",
      "versionDate": "2026-03-15",
      "downloadURL": "https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/ipa/beautycita.ipa",
      "localizedDescription": "Tu agente inteligente de belleza — reserva en 30 segundos.",
      "iconURL": "https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/ipa/icon.png",
      "size": $IPA_SIZE
    }
  ]
}
EOF

aws s3 cp /tmp/altstore-source.json \
  s3://beautycita-medias/ipa/altstore-source.json --profile r2 \
  --content-type application/json
```

The AltStore source URL for testers to add:
`https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/ipa/altstore-source.json`

- [ ] **Step 6: Install BeautyCita via AltStore on BC's iPhone**

1. On BC's iPhone, open AltStore (installed in Step 1)
2. Go to Sources → Add Source
3. Enter: `https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/ipa/altstore-source.json`
4. Find BeautyCita in the source → Install
5. AltStore re-signs with beautycita@icloud.com Apple ID
6. App should launch and work normally

- [ ] **Step 7: Smoke-check AltServer auto-refresh**

AltServer on beautypi should auto-refresh the app before the 7-day signing expires. This is a smoke check — real verification happens after 6+ days:
```bash
ssh dmyl@100.93.1.103 "journalctl -u altserver --since '1 hour ago' | tail -20"
```
Expected: logs showing AltServer is running and aware of connected devices.

---

## Post-Implementation Checklist

After all tasks are complete:

- [ ] `grep -rn shorebird /home/bc/futureBeauty/beautycita_app/` → zero results
- [ ] Android APK builds with `--split-per-abi` → ~57MB arm64
- [ ] iOS IPA builds via GitHub Actions → artifact downloadable
- [ ] `send-push-notification` sends both FCM + WA → verify in edge function logs
- [ ] NotificationService skips FCM on iOS → verify with `debugPrint` output
- [ ] AltStore source URL returns valid JSON with correct IPA size
- [ ] AltStore installed on BC's iPhone
- [ ] IPA installable via AltStore source
- [ ] App launches and all screens render on iOS
- [ ] Booking flow works on iOS (WA notifications arrive)
- [ ] AltServer auto-refreshes app within 7-day window (verify after ~6 days)
