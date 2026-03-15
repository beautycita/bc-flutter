# iOS Build + AltStore Distribution — Design Spec
**Date:** 2026-03-15
**Status:** Approved by BC

---

## Goal

Produce a production-quality iOS IPA for BeautyCita, distribute it to 3-4 testers via AltStore on beautypi, and completely eliminate Shorebird from the codebase. Push notifications are replaced with WhatsApp message fallback since free Apple ID sideloading has no APNs access.

---

## Scope

### In Scope
1. **Shorebird removal** — delete all traces from pubspec.yaml, shorebird.yaml, updater_service.dart, and any imports
2. **iOS build adaptations** — platform guards for Android-only features, WA fallback for push notifications, signing config for free Apple ID
3. **GitHub Actions CI** — macOS runner workflow to build unsigned IPA (`flutter build ipa --no-codesign`)
4. **AltStore on beautypi** — AltServer-Linux (aarch64), anisette-server Docker container, netmuxd for USB-over-network, systemd services
5. **IPA distribution** — source JSON hosted on beautypi or R2 for AltStore to pull

### Out of Scope
- App Store / TestFlight (requires paid Apple Developer Program, pending S.A. de C.V.)
- Push notifications via APNs (no certificate without paid account)
- iOS-specific UI redesign (Flutter handles platform adaptation)

---

## Architecture

### 1. Shorebird Removal

**Files to modify:**
- `beautycita_app/pubspec.yaml` — remove `shorebird_code_push: ^2.0.5` dependency
- `beautycita_app/shorebird.yaml` — DELETE entirely
- `beautycita_app/lib/services/updater_service.dart` — remove Shorebird Tier 1, keep R2 version.json Tier 2 with `Platform.isAndroid` guard
- Any file importing `shorebird_code_push` — find and remove

**updater_service.dart rewrite:** The service currently has two tiers:
- Tier 1: Shorebird OTA check (REMOVE)
- Tier 2: R2 version.json check (KEEP, add Platform.isAndroid guard since iOS won't use R2 APK updates)

The rewritten service checks version.json on R2, compares build numbers (stripping ABI offset via `baseBuildNumber`), and shows update dialog linking to the R2 APK download. On iOS, this check is skipped entirely (AltStore handles updates).

### 2. iOS Build Adaptations

**Push notification WA fallback:**
- Wherever `FirebaseMessaging` sends a push notification, add a parallel WA message with the same content
- This happens in edge functions (server-side), not client-side — the edge function that triggers push also triggers WA
- Edge functions affected: any that call the FCM/push endpoint (booking confirmations, reminders, salon notifications)
- Client-side: disable FCM token registration on iOS (no APNs = FCM won't work). Guard with `Platform.isIOS`.

**Platform guards needed:**
- `updater_service.dart`: Skip R2 update check on iOS
- FCM token registration: Skip on iOS (free sideload = no APNs)
- Any Android-specific intent/deep-link handling: guard with Platform checks

**iOS signing:**
- Bundle ID: `com.beautycita.beautycita` (already in Info.plist)
- For CI: `--no-codesign` builds unsigned IPA. AltStore re-signs with the user's Apple ID on-device.
- Xcode project must have `CODE_SIGNING_ALLOWED=NO` for CI builds

### 3. GitHub Actions CI

**Workflow:** `.github/workflows/build-ios.yml`
- Trigger: manual (`workflow_dispatch`) with optional version input
- Runner: `macos-latest` (Apple Silicon)
- Steps:
  1. Checkout code
  2. Setup Flutter (v3.38.9 stable)
  3. `flutter pub get`
  4. `flutter build ipa --no-codesign --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
  5. Upload `.xcarchive` or `.ipa` as GitHub Actions artifact
- Secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY` stored as GitHub repository secrets
- No signing, no provisioning profile — AltStore handles signing on-device

### 4. AltStore on beautypi

**Components:**
1. **AltServer-Linux** — aarch64 binary from GitHub releases (runs on beautypi's ARM64 Debian)
2. **anisette-server** — Docker container providing Apple auth tokens (required by AltServer)
3. **netmuxd** — USB multiplexer replacement that enables device discovery over network (Tailscale)
4. **systemd services** — auto-start all components on boot

**Network topology:**
```
[BC's iPhone] <-- Tailscale --> [beautypi: AltServer-Linux + anisette + netmuxd]
[Tester iPhones] <-- same WiFi or Tailscale --> [beautypi]
```

**IPA delivery:**
- Option A: Host IPA on R2 (`s3://beautycita-medias/ipa/beautycita.ipa`), AltStore source JSON points to R2 URL
- Option B: Host IPA directly on beautypi via simple HTTP server
- **Recommendation: Option A (R2)** — same infrastructure as APK, CDN-backed, no port exposure on beautypi

**AltStore Source JSON** (hosted on R2):
```json
{
  "name": "BeautyCita",
  "identifier": "com.beautycita.beautycita",
  "apps": [{
    "name": "BeautyCita",
    "bundleIdentifier": "com.beautycita.beautycita",
    "developerName": "BeautyCita",
    "version": "1.0.6",
    "versionDate": "2026-03-15",
    "downloadURL": "https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/ipa/beautycita.ipa",
    "localizedDescription": "Tu agente inteligente de belleza",
    "iconURL": "https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/ipa/icon.png",
    "size": 0
  }]
}
```

### 5. Constraints

- **7-day refresh:** Free Apple ID sideloading expires apps after 7 days. AltServer auto-refreshes if the device is reachable (Tailscale keeps it reachable).
- **3-app limit:** Only 3 sideloaded apps per free Apple ID. BeautyCita will be one of them.
- **No push notifications:** Free sideloading has no APNs access. All notifications go via WhatsApp.
- **Testers:** 3-4 people including BC. Each needs AltStore installed (one-time setup).

---

## Testing Strategy

1. **Shorebird removal:** Build Android APK with `--split-per-abi` after removal — verify no Shorebird imports, clean build, ~57MB arm64
2. **iOS build:** `flutter build ipa --no-codesign` locally (if macOS available) or via GitHub Actions — verify .ipa artifact produced
3. **AltStore install:** Install IPA on BC's iPhone via AltStore — verify app launches, all screens render, booking flow works
4. **WA fallback:** Trigger a booking → verify WA message arrives instead of push notification
5. **Platform guards:** Verify updater_service doesn't check R2 on iOS, FCM doesn't register on iOS

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| AltServer-Linux aarch64 binary not available | Build from source on beautypi (Rust project, compiles on ARM64) |
| anisette-server Docker image not available for ARM64 | Use Sideloadly alternative, or build anisette from source |
| GitHub Actions macOS runner too slow/expensive | Free tier: 2,000 min/month macOS. Manual trigger only = ~10 builds/month max |
| Tester iPhone not reachable for 7-day refresh | Tailscale keeps devices connected. Fallback: manual refresh via USB |
| Flutter iOS build fails (untested target) | Run `flutter doctor` for iOS, fix any missing dependencies. Cocoapods may need install. |

---

## Success Criteria

1. Shorebird completely removed — zero references in codebase
2. Android APK still builds with `--split-per-abi` (~57MB arm64)
3. iOS IPA builds via GitHub Actions (unsigned)
4. AltStore running on beautypi as systemd service
5. BC can install BeautyCita on iPhone via AltStore
6. All app features work on iOS (booking, WA verification, salon browsing)
7. WA messages arrive wherever push notifications would have fired
