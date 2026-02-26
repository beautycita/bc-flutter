# BeautyCita Web App Rebuild — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild the BeautyCita web app as an independent desktop-first Flutter Web (WASM) application sharing only a minimal Dart package with the mobile app.

**Architecture:** Hybrid approach — static HTML/CSS for SEO pages + Flutter Web WASM for the authenticated app. A shared local Dart package (`beautycita_core`) holds models, theme constants, and Supabase config. Web and mobile are siblings: same family, independent lives.

**Tech Stack:** Flutter Web 3.38.x (WASM), Riverpod 2.6.x, GoRouter 14.8.x, Supabase (self-hosted), Stripe Web SDK, Mapbox GL JS, fl_chart

**Design Spec:** `docs/plans/2026-02-25-beautycita-webapp-rebuild-design.md`

---

## ABSOLUTE RULES (read before every task)

1. NEVER import, copy, adapt, or reference any file from `beautycita_app/lib/screens/` into the web project.
2. NEVER put widgets, screens, pages, or ANY UI component in `beautycita_core`.
3. The web app is PC/Mac desktop-first. Every page starts as a desktop layout.
4. "Looks like the app" means same design language (colors, fonts, spacing), NOT same layouts or widget trees.
5. When building a web page, do NOT open the equivalent mobile screen for reference.
6. If the thought "I can reuse this screen from mobile" appears — STOP. Build it fresh.

---

## Phase 0: Foundation (Monorepo + Shared Package)

**Outcome:** A shared `beautycita_core` package with models, theme constants, and Supabase config. Mobile app still builds. Fresh web project scaffold that compiles to WASM.

---

### Task 0.1: Restructure git as monorepo

The git repo currently lives at `beautycita_app/`. We need it at the `futureBeauty/` monorepo root so it can track `packages/`, `beautycita_web/`, and `docs/`.

**Step 1: Move .git up to monorepo root**

```bash
cd /home/bc/futureBeauty
mv beautycita_app/.git .
```

**Step 2: Create monorepo .gitignore**

Create `/home/bc/futureBeauty/.gitignore`:

```gitignore
# Flutter / Dart
**/build/
**/.dart_tool/
**/.packages
**/.flutter-plugins
**/.flutter-plugins-dependencies
**/.pub-cache/
**/.pub/
**/pubspec.lock

# IDE
**/.idea/
**/.vscode/
*.iml

# Environment
**/.env
**/.env.*

# OS
.DS_Store
Thumbs.db

# Artifacts
*.apk
*.aab
*.ipa

# Old worktrees
.worktrees/
```

**Step 3: Stage everything and commit**

```bash
cd /home/bc/futureBeauty
git add .gitignore beautycita_app/ docs/ packages/
git status  # Should show beautycita_app/ files as renamed (same content)
git commit -m "Restructure as monorepo: beautycita_app + docs + packages at root"
```

**Step 4: Verify remote still works**

```bash
git remote -v   # Should still point to github.com/beautycita/bc-flutter.git
git push origin main
```

**Step 5: Commit**

Already done in Step 3.

---

### Task 0.2: Create beautycita_core package scaffold

**Files:**
- Create: `packages/beautycita_core/pubspec.yaml`
- Create: `packages/beautycita_core/lib/beautycita_core.dart`
- Create: `packages/beautycita_core/lib/models.dart`
- Create: `packages/beautycita_core/lib/theme.dart`
- Create: `packages/beautycita_core/lib/supabase.dart`

**Step 1: Create directory structure**

```bash
mkdir -p /home/bc/futureBeauty/packages/beautycita_core/lib/src/{models,theme,supabase}
```

**Step 2: Create pubspec.yaml**

Create `packages/beautycita_core/pubspec.yaml`:

```yaml
name: beautycita_core
description: Shared models, theme constants, and Supabase config for BeautyCita apps.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.10.0
  flutter: '>=3.38.0'

dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.8.0
  flutter_dotenv: ^5.2.1
```

**Step 3: Create barrel exports**

Create `packages/beautycita_core/lib/beautycita_core.dart`:

```dart
/// BeautyCita shared core: models, theme constants, Supabase config.
///
/// HARD RULE: No widgets, screens, pages, or UI components belong here.
library beautycita_core;

export 'models.dart';
export 'theme.dart';
export 'supabase.dart';
```

Create `packages/beautycita_core/lib/models.dart`:

```dart
// Data models — fromJson/toJson only, no UI
```

Create `packages/beautycita_core/lib/theme.dart`:

```dart
// Theme constants — colors, typography names, spacing values
// NOT ThemeData. Each app builds its own ThemeData from these constants.
```

Create `packages/beautycita_core/lib/supabase.dart`:

```dart
// Supabase client init, table name constants, shared query helpers
```

**Step 4: Verify package resolves**

```bash
cd /home/bc/futureBeauty/packages/beautycita_core
/home/bc/flutter/bin/flutter pub get
```

Expected: `Got dependencies!`

**Step 5: Commit**

```bash
cd /home/bc/futureBeauty
git add packages/beautycita_core/
git commit -m "feat: scaffold beautycita_core shared package"
```

---

### Task 0.3: Extract models to shared package

Copy all 8 model files from mobile app into the shared package. Strip any Flutter UI imports (only `category.dart` uses `Color` from `dart:ui`, which is fine — Flutter is a dependency).

**Files to copy:**
- `beautycita_app/lib/models/booking.dart` → `packages/beautycita_core/lib/src/models/booking.dart`
- `beautycita_app/lib/models/provider.dart` → `packages/beautycita_core/lib/src/models/provider.dart`
- `beautycita_app/lib/models/category.dart` → `packages/beautycita_core/lib/src/models/category.dart`
- `beautycita_app/lib/models/curate_result.dart` → `packages/beautycita_core/lib/src/models/curate_result.dart`
- `beautycita_app/lib/models/follow_up_question.dart` → `packages/beautycita_core/lib/src/models/follow_up_question.dart`
- `beautycita_app/lib/models/uber_ride.dart` → `packages/beautycita_core/lib/src/models/uber_ride.dart`
- `beautycita_app/lib/models/chat_message.dart` → `packages/beautycita_core/lib/src/models/chat_message.dart`
- `beautycita_app/lib/models/chat_thread.dart` → `packages/beautycita_core/lib/src/models/chat_thread.dart`

**Step 1: Copy model files**

```bash
cp /home/bc/futureBeauty/beautycita_app/lib/models/*.dart \
   /home/bc/futureBeauty/packages/beautycita_core/lib/src/models/
```

**Step 2: Audit imports in each file**

Read each copied file. Remove any imports that reference:
- `package:beautycita_app/` (any app-specific import)
- `package:flutter/material.dart` (if present — use `dart:ui` for Color instead)
- Any screen/widget/provider imports

`category.dart` uses `Color` — ensure it imports `dart:ui` (not `package:flutter/material.dart`). If it imports material, change to:
```dart
import 'dart:ui' show Color;
```

**Step 3: Add dependency imports**

If any model uses `LatLng` from `latlong2`, add `latlong2` to the shared package pubspec. Check `curate_result.dart` — if it uses `LatLng`, add:

```yaml
# In packages/beautycita_core/pubspec.yaml dependencies:
  latlong2: ^0.9.1
```

**Step 4: Update barrel export**

Update `packages/beautycita_core/lib/models.dart`:

```dart
export 'src/models/booking.dart';
export 'src/models/provider.dart';
export 'src/models/category.dart';
export 'src/models/curate_result.dart';
export 'src/models/follow_up_question.dart';
export 'src/models/uber_ride.dart';
export 'src/models/chat_message.dart';
export 'src/models/chat_thread.dart';
```

**Step 5: Verify package compiles**

```bash
cd /home/bc/futureBeauty/packages/beautycita_core
/home/bc/flutter/bin/flutter pub get
/home/bc/flutter/bin/dart analyze lib/
```

Expected: No errors. Fix any import issues found.

**Step 6: Commit**

```bash
cd /home/bc/futureBeauty
git add packages/beautycita_core/
git commit -m "feat: extract data models to beautycita_core"
```

---

### Task 0.4: Extract theme constants to shared package

Extract palette color values, spacing constants, typography font names, and gradient definitions. NOT ThemeData — each app builds its own.

**Files:**
- Create: `packages/beautycita_core/lib/src/theme/bc_palette.dart`
- Create: `packages/beautycita_core/lib/src/theme/palettes.dart`
- Create: `packages/beautycita_core/lib/src/theme/spacing.dart`
- Create: `packages/beautycita_core/lib/src/theme/typography.dart`

**Step 1: Create BCPalette data class**

Create `packages/beautycita_core/lib/src/theme/bc_palette.dart`:

Copy the `BCPalette` class from `beautycita_app/lib/config/palettes.dart`. This is the immutable palette definition class with all color fields, gradient stops, font names, spacing scale, etc. Remove any imports that reference app-specific code. Keep `dart:ui` for `Color` and `Brightness`.

Key fields to include:
- All ColorScheme fields (primary, onPrimary, secondary, etc.)
- Extended colors (cardColor, cardBorderColor, divider, text colors, shimmer)
- Status colors (success, warning, info)
- Gradients (primaryGradient, accentGradient, goldGradientStops + positions)
- Category colors (List<Color>)
- Typography (headingFont, bodyFont)
- Spacing/radius scales
- Glass morphism (blurSigma, glassTint, glassBorderOpacity)
- Cinematic colors
- System UI (statusBarColor, etc.)

**Step 2: Create all 7 palette definitions**

Create `packages/beautycita_core/lib/src/theme/palettes.dart`:

Copy the 7 palette `const` definitions from `beautycita_app/lib/config/palettes.dart`:
- `kPaletteRoseGold`
- `kPaletteBlackGold`
- `kPaletteGlass`
- `kPaletteMidnightOrchid`
- `kPaletteOceanNoir`
- `kPaletteCherryBlossom`
- `kPaletteEmeraldLuxe`

Also copy:
- `kGoldStops` (13-color metallic gold array)
- `kGoldPositions` (gradient stop positions)
- `kWhatsAppGreen`
- `kAllPalettes` list

**Step 3: Create spacing constants**

Create `packages/beautycita_core/lib/src/theme/spacing.dart`:

Copy relevant constants from `beautycita_app/lib/config/constants.dart`:

```dart
/// Spacing and geometry constants shared across BeautyCita apps.
/// Each app adapts these to its platform (mobile touch targets vs desktop click targets).
abstract final class BCSpacing {
  // Padding
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Radius
  static const double radiusXs = 8.0;
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusFull = 999.0;

  // Elevation
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // Avatar sizes
  static const double avatarSm = 32.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;
  static const double avatarXl = 96.0;
}
```

**Step 4: Create typography constants**

Create `packages/beautycita_core/lib/src/theme/typography.dart`:

```dart
/// Font family names and base sizing shared across BeautyCita apps.
/// Each app uses these with GoogleFonts to build its own TextTheme.
abstract final class BCTypography {
  // Default fonts (Rose & Gold palette)
  static const String defaultHeadingFont = 'Cormorant Garamond';
  static const String defaultBodyFont = 'Nunito';

  // Animation durations (shared for consistent feel)
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 350);
}
```

**Step 5: Update barrel export**

Update `packages/beautycita_core/lib/theme.dart`:

```dart
export 'src/theme/bc_palette.dart';
export 'src/theme/palettes.dart';
export 'src/theme/spacing.dart';
export 'src/theme/typography.dart';
```

**Step 6: Verify**

```bash
cd /home/bc/futureBeauty/packages/beautycita_core
/home/bc/flutter/bin/flutter pub get
/home/bc/flutter/bin/dart analyze lib/
```

**Step 7: Commit**

```bash
cd /home/bc/futureBeauty
git add packages/beautycita_core/
git commit -m "feat: extract theme constants to beautycita_core"
```

---

### Task 0.5: Extract Supabase config to shared package

**Files:**
- Create: `packages/beautycita_core/lib/src/supabase/client.dart`
- Create: `packages/beautycita_core/lib/src/supabase/tables.dart`

**Step 1: Create Supabase client wrapper**

Create `packages/beautycita_core/lib/src/supabase/client.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase client initialization.
/// Both mobile and web apps call this during startup.
class BCSupabase {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase not initialized. Call BCSupabase.initialize() first.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || anonKey.isEmpty || url.contains('PLACEHOLDER')) {
      // Offline / dev mode — skip initialization
      return;
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    _initialized = true;
  }

  static String? get currentUserId =>
      _initialized ? Supabase.instance.client.auth.currentUser?.id : null;

  static bool get isAuthenticated =>
      _initialized && Supabase.instance.client.auth.currentUser != null;
}
```

**Step 2: Create table name constants**

Create `packages/beautycita_core/lib/src/supabase/tables.dart`:

```dart
/// Supabase table name constants.
/// Single source of truth for all table references across both apps.
abstract final class BCTables {
  static const String profiles = 'profiles';
  static const String businesses = 'businesses';
  static const String services = 'services';
  static const String appointments = 'appointments';
  static const String staff = 'staff';
  static const String staffServices = 'staff_services';
  static const String staffSchedules = 'staff_schedules';
  static const String payments = 'payments';
  static const String reviews = 'reviews';
  static const String reviewTags = 'review_tags';
  static const String favorites = 'favorites';
  static const String chatThreads = 'chat_threads';
  static const String chatMessages = 'chat_messages';
  static const String discoveredSalons = 'discovered_salons';
  static const String salonOutreachLog = 'salon_outreach_log';
  static const String salonInterestSignals = 'salon_interest_signals';
  static const String serviceCategoriesTree = 'service_categories_tree';
  static const String serviceProfiles = 'service_profiles';
  static const String serviceFollowUpQuestions = 'service_follow_up_questions';
  static const String timeInferenceRules = 'time_inference_rules';
  static const String timeInferenceCorrections = 'time_inference_corrections';
  static const String engineSettings = 'engine_settings';
  static const String engineAnalyticsEvents = 'engine_analytics_events';
  static const String notificationTemplates = 'notification_templates';
  static const String notifications = 'notifications';
  static const String disputes = 'disputes';
  static const String userMedia = 'user_media';
  static const String appConfig = 'app_config';
  static const String auditLog = 'audit_log';
  static const String qrAuthSessions = 'qr_auth_sessions';
  static const String stylistApplications = 'stylist_applications';
  static const String userBookingPatterns = 'user_booking_patterns';
  static const String calendarConnections = 'calendar_connections';
  static const String externalAppointments = 'external_appointments';
  static const String staffAvailabilityOverrides = 'staff_availability_overrides';
}
```

**Step 3: Update barrel export**

Update `packages/beautycita_core/lib/supabase.dart`:

```dart
export 'src/supabase/client.dart';
export 'src/supabase/tables.dart';
```

**Step 4: Verify**

```bash
cd /home/bc/futureBeauty/packages/beautycita_core
/home/bc/flutter/bin/flutter pub get
/home/bc/flutter/bin/dart analyze lib/
```

**Step 5: Commit**

```bash
cd /home/bc/futureBeauty
git add packages/beautycita_core/
git commit -m "feat: extract Supabase config and table constants to beautycita_core"
```

---

### Task 0.6: Update mobile app to use shared package

**Files:**
- Modify: `beautycita_app/pubspec.yaml` — add path dependency
- Modify: All files that import `package:beautycita_app/models/` — change to `package:beautycita_core/models.dart`
- Modify: `beautycita_app/lib/services/supabase_client.dart` — delegate to shared BCSupabase
- Modify: `beautycita_app/lib/config/palettes.dart` — re-export from shared package

**Step 1: Add shared package dependency**

In `beautycita_app/pubspec.yaml`, add under `dependencies:`:

```yaml
  beautycita_core:
    path: ../packages/beautycita_core
```

Run:
```bash
cd /home/bc/futureBeauty/beautycita_app
/home/bc/flutter/bin/flutter pub get
```

**Step 2: Update model imports**

Find all files importing models from the app package:

```bash
cd /home/bc/futureBeauty/beautycita_app
grep -rl "package:beautycita_app/models/" lib/ | head -50
```

For each file, replace:
```dart
import 'package:beautycita_app/models/booking.dart';
```
with:
```dart
import 'package:beautycita_core/models.dart';
```

Or if they import specific models, change the package prefix. The barrel export `models.dart` re-exports all model files, so a single import covers everything.

**Alternative approach** (less disruptive): Keep the original model files in `beautycita_app/lib/models/` but make them re-export from the shared package:

```dart
// beautycita_app/lib/models/booking.dart
export 'package:beautycita_core/src/models/booking.dart';
```

This way, no other file in the mobile app needs to change its imports. The models are now sourced from the shared package but the app's internal import paths stay the same.

**Use the re-export approach** — it's safer and faster.

**Step 3: Update each model file to re-export**

For each file in `beautycita_app/lib/models/`:
```dart
// booking.dart — now delegates to shared package
export 'package:beautycita_core/src/models/booking.dart';
```

Repeat for all 8 model files.

**Step 4: Do the same for palette/theme constants**

In `beautycita_app/lib/config/palettes.dart`, add at the top:
```dart
export 'package:beautycita_core/theme.dart';
```

Keep the existing file content for now — it already defines the palettes. The shared package has a copy. Once we verify everything works, the app's palettes.dart can become a pure re-export. But for safety, we'll do this in a follow-up task after verifying.

**Step 5: Verify nothing is broken**

```bash
cd /home/bc/futureBeauty/beautycita_app
/home/bc/flutter/bin/flutter pub get
/home/bc/flutter/bin/dart analyze lib/
```

Expected: No errors or only pre-existing warnings.

**Step 6: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/
git commit -m "refactor: mobile app models now source from beautycita_core"
```

---

### Task 0.7: Verify mobile app builds

**Step 1: Build release APK**

```bash
cd /home/bc/futureBeauty/beautycita_app
/home/bc/flutter/bin/flutter build apk --release --no-tree-shake-icons --target-platform android-arm64
```

Expected: `Built build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

**Step 2: If build fails**

Fix import issues. Common problems:
- Duplicate class definitions (shared package + app both define same class)
- Missing transitive dependencies (shared package needs a dep the app had)
- Type conflicts from re-exports

**Step 3: Install on phone and smoke test**

```bash
/home/bc/Android/Sdk/platform-tools/adb devices
/home/bc/Android/Sdk/platform-tools/adb -s <DEVICE_ID> install -r \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Verify: App launches, can log in, can browse categories, can see bookings.

**Step 4: Commit if any fixes were needed**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/ packages/
git commit -m "fix: resolve shared package integration issues"
```

---

### Task 0.8: Trash old beautycita_web and create fresh project

**Step 1: Backup .env from old web project**

```bash
cp /home/bc/futureBeauty/beautycita_web/.env /tmp/beautycita_web_env_backup
```

**Step 2: Delete old web project**

```bash
rm -rf /home/bc/futureBeauty/beautycita_web
```

**Step 3: Create fresh Flutter web project**

```bash
cd /home/bc/futureBeauty
/home/bc/flutter/bin/flutter create --project-name beautycita_web \
  --org com.beautycita \
  --platforms web \
  beautycita_web
```

**Step 4: Restore .env**

```bash
cp /tmp/beautycita_web_env_backup /home/bc/futureBeauty/beautycita_web/.env
```

**Step 5: Clean up scaffold files we don't need**

```bash
rm -rf /home/bc/futureBeauty/beautycita_web/test/
rm /home/bc/futureBeauty/beautycita_web/lib/main.dart
```

We'll write our own main.dart, app.dart, etc.

**Step 6: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_web/
git commit -m "feat: fresh Flutter web project scaffold (old webapp deleted)"
```

---

### Task 0.9: Configure web project with shared package and WASM

**Files:**
- Modify: `beautycita_web/pubspec.yaml`
- Create: `beautycita_web/lib/main.dart`
- Create: `beautycita_web/lib/app.dart`
- Modify: `beautycita_web/web/index.html`

**Step 1: Set up pubspec.yaml**

Replace `beautycita_web/pubspec.yaml`:

```yaml
name: beautycita_web
description: BeautyCita web app — desktop-first, built from scratch for web.
publish_to: none
version: 1.0.0+1

environment:
  sdk: ^3.10.0
  flutter: '>=3.38.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_web_plugins:
    sdk: flutter

  # Shared package
  beautycita_core:
    path: ../packages/beautycita_core

  # State management
  flutter_riverpod: ^2.6.1

  # Routing
  go_router: ^14.8.1

  # Backend
  supabase_flutter: ^2.8.0
  flutter_dotenv: ^5.2.1
  http: ^1.2.0

  # UI
  google_fonts: ^6.2.1
  flutter_animate: ^4.5.2
  fl_chart: ^0.70.0
  data_table_2: ^2.5.0

  # Utilities
  intl: ^0.20.2
  url_launcher: ^6.3.1
  shared_preferences: ^2.5.3
  image_picker: ^1.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

**Step 2: Create minimal main.dart**

Create `beautycita_web/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Spanish locale for date formatting
  await initializeDateFormatting('es');

  // Bundled fonts only — no runtime fetching
  GoogleFonts.config.allowRuntimeFetching = false;

  // Load .env
  await dotenv.load(fileName: '.env');

  // Initialize Supabase (shared)
  await BCSupabase.initialize();

  runApp(const ProviderScope(child: BeautyCitaWebApp()));
}
```

**Step 3: Create minimal app.dart**

Create `beautycita_web/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/theme.dart';

class BeautyCitaWebApp extends ConsumerWidget {
  const BeautyCitaWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BeautyCita',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPaletteRoseGold.primary,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('BeautyCita Web — Phase 0 Complete'),
        ),
      ),
    );
  }
}
```

**Step 4: Set up index.html for WASM**

Replace `beautycita_web/web/index.html`:

```html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>BeautyCita</title>
  <style>
    body { margin: 0; background: #FFF8F0; }
  </style>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
```

**Step 5: Verify WASM build**

```bash
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter pub get
/home/bc/flutter/bin/flutter build web --wasm --release --no-tree-shake-icons
```

Expected: `Built build/web/` with WASM output.

If WASM fails due to package incompatibility, fall back to:
```bash
/home/bc/flutter/bin/flutter build web --release --no-tree-shake-icons
```
And investigate which package blocks WASM.

**Step 6: Verify local dev server**

```bash
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter run -d chrome --web-port=8080
```

Expected: Chrome opens, shows "BeautyCita Web — Phase 0 Complete".

**Step 7: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_web/
git commit -m "feat: web project configured with shared package and WASM build"
```

---

### Task 0.10: Push Phase 0 and verify CI

```bash
cd /home/bc/futureBeauty
git push origin main
```

**Phase 0 checklist:**
- [ ] Monorepo git structure at futureBeauty/
- [ ] beautycita_core package with models, theme, supabase
- [ ] Mobile app builds and runs with shared package
- [ ] Fresh web project builds to WASM
- [ ] All committed and pushed

---

## Phase 1: Auth + Admin Panel

**Outcome:** Full authentication system and the admin panel — BC's daily driver for managing the platform from desktop.

---

### Task 1.1: Web app directory structure and router

**Files:**
- Create: `beautycita_web/lib/config/router.dart`
- Create: `beautycita_web/lib/config/web_theme.dart`
- Create: `beautycita_web/lib/config/breakpoints.dart`
- Create: `beautycita_web/lib/shells/admin_shell.dart` (placeholder)
- Create: `beautycita_web/lib/shells/business_shell.dart` (placeholder)
- Create: `beautycita_web/lib/shells/client_shell.dart` (placeholder)
- Create: `beautycita_web/lib/pages/auth/login_page.dart` (placeholder)
- Create: `beautycita_web/lib/pages/error/not_found_page.dart`

**Step 1: Create directory tree**

```bash
cd /home/bc/futureBeauty/beautycita_web
mkdir -p lib/{config,shells,providers,services,repositories,widgets}
mkdir -p lib/pages/{auth,admin,business,client,error}
```

**Step 2: Create responsive breakpoints**

Create `beautycita_web/lib/config/breakpoints.dart`:

```dart
/// Responsive breakpoints for the web app.
/// Desktop-first: design for >1200px, then adapt down.
abstract final class WebBreakpoints {
  /// Full three-column layout (sidebar + content + detail panel)
  static const double desktop = 1200;

  /// Collapsed sidebar, content + detail overlay
  static const double tablet = 800;

  /// Hamburger menu, single column
  static const double mobile = 800;

  /// Helper to check current width category
  static bool isDesktop(double width) => width >= desktop;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isMobile(double width) => width < tablet;
}
```

**Step 3: Create web theme builder**

Create `beautycita_web/lib/config/web_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beautycita_core/theme.dart';

/// Builds ThemeData from a BCPalette for the web app.
/// Desktop-first: larger text, more spacious padding, hover states.
ThemeData buildWebTheme(BCPalette palette, {Brightness brightness = Brightness.light}) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
    surface: palette.surface,
    onSurface: palette.onSurface,
    error: palette.error,
    onError: palette.onError,
  );

  final headingFont = palette.headingFont;
  final bodyFont = palette.bodyFont;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.scaffoldBackground,
    textTheme: TextTheme(
      displayLarge: GoogleFonts.getFont(headingFont, fontSize: 48, fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.getFont(headingFont, fontSize: 36, fontWeight: FontWeight.w600),
      displaySmall: GoogleFonts.getFont(headingFont, fontSize: 28, fontWeight: FontWeight.w600),
      headlineLarge: GoogleFonts.getFont(headingFont, fontSize: 24, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.getFont(headingFont, fontSize: 20, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.getFont(headingFont, fontSize: 18, fontWeight: FontWeight.w500),
      titleLarge: GoogleFonts.getFont(bodyFont, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.getFont(bodyFont, fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.getFont(bodyFont, fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.getFont(bodyFont, fontSize: 16),
      bodyMedium: GoogleFonts.getFont(bodyFont, fontSize: 14),
      bodySmall: GoogleFonts.getFont(bodyFont, fontSize: 12),
      labelLarge: GoogleFonts.getFont(bodyFont, fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.getFont(bodyFont, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.getFont(bodyFont, fontSize: 11, fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
        side: BorderSide(color: palette.cardBorderColor),
      ),
      color: palette.cardColor,
    ),
    dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
        borderSide: BorderSide(color: palette.cardBorderColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}
```

**Step 4: Create GoRouter config**

Create `beautycita_web/lib/config/router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

import '../shells/admin_shell.dart';
import '../shells/business_shell.dart';
import '../shells/client_shell.dart';
import '../pages/auth/login_page.dart';
import '../pages/error/not_found_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/app/auth',
    debugLogDiagnostics: true,
    errorBuilder: (context, state) => const NotFoundPage(),

    redirect: (context, state) {
      final isAuthenticated = BCSupabase.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/app/auth');

      // Not authenticated and not on auth page → go to login
      if (!isAuthenticated && !isAuthRoute) {
        return '/app/auth';
      }

      // Authenticated and on auth page → redirect by role
      if (isAuthenticated && isAuthRoute && state.matchedLocation == '/app/auth') {
        // TODO: Check user role from profile and redirect accordingly
        // admin/superadmin → /app/admin
        // stylist/salon_owner → /app/negocio
        // client → /app/reservar
        return '/app/admin'; // Default to admin for Phase 1
      }

      return null;
    },

    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: '/app/auth',
        builder: (context, state) => const LoginPage(),
        routes: [
          GoRoute(path: 'register', builder: (context, state) => const Placeholder()),
          GoRoute(path: 'verify', builder: (context, state) => const Placeholder()),
          GoRoute(path: 'callback', builder: (context, state) => const Placeholder()),
          GoRoute(path: 'forgot', builder: (context, state) => const Placeholder()),
          GoRoute(path: 'qr', builder: (context, state) => const Placeholder()),
        ],
      ),

      // Admin shell
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/app/admin', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/users', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/salons', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/bookings', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/services', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/disputes', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/finance', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/analytics', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/engine', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/engine/profiles', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/engine/categories', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/engine/time', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/outreach', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/config', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/admin/toggles', builder: (context, state) => const Placeholder()),
        ],
      ),

      // Business shell (Phase 2 — placeholder)
      ShellRoute(
        builder: (context, state, child) => BusinessShell(child: child),
        routes: [
          GoRoute(path: '/app/negocio', builder: (context, state) => const Placeholder()),
        ],
      ),

      // Client routes (Phase 3 — placeholder)
      ShellRoute(
        builder: (context, state, child) => ClientShell(child: child),
        routes: [
          GoRoute(path: '/app/reservar', builder: (context, state) => const Placeholder()),
          GoRoute(path: '/app/mis-citas', builder: (context, state) => const Placeholder()),
        ],
      ),
    ],
  );
});

/// Placeholder widget for routes not yet implemented.
class Placeholder extends StatelessWidget {
  const Placeholder({super.key});

  @override
  Widget build(BuildContext context) {
    final route = GoRouterState.of(context).matchedLocation;
    return Center(
      child: Text(
        'Coming soon: $route',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }
}
```

**Step 5: Create placeholder shells**

Create `beautycita_web/lib/shells/admin_shell.dart`:

```dart
import 'package:flutter/material.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar placeholder — built in Task 1.3
          Container(
            width: 240,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: const Center(child: Text('Admin Sidebar')),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```

Create `beautycita_web/lib/shells/business_shell.dart`:

```dart
import 'package:flutter/material.dart';

class BusinessShell extends StatelessWidget {
  final Widget child;
  const BusinessShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}
```

Create `beautycita_web/lib/shells/client_shell.dart`:

```dart
import 'package:flutter/material.dart';

class ClientShell extends StatelessWidget {
  final Widget child;
  const ClientShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}
```

**Step 6: Create error page**

Create `beautycita_web/lib/pages/error/not_found_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('404', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 16),
            Text('Página no encontrada',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.go('/app/auth'),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 7: Create login page placeholder**

Create `beautycita_web/lib/pages/auth/login_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:beautycita_core/theme.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Brand panel (left half)
          Expanded(
            child: Container(
              color: kPaletteRoseGold.primary,
              child: Center(
                child: Text(
                  'BeautyCita',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Login form (right half)
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Login form coming in Task 1.2'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 8: Update app.dart to use router**

Update `beautycita_web/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/theme.dart';
import 'config/router.dart';
import 'config/web_theme.dart';

class BeautyCitaWebApp extends ConsumerWidget {
  const BeautyCitaWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BeautyCita',
      debugShowCheckedModeBanner: false,
      theme: buildWebTheme(kPaletteRoseGold),
      routerConfig: router,
    );
  }
}
```

**Step 9: Verify build**

```bash
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter pub get
/home/bc/flutter/bin/flutter build web --wasm --release --no-tree-shake-icons
```

**Step 10: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_web/
git commit -m "feat: web app router, shells, theme, and auth page scaffolding"
```

---

### Task 1.2: Build auth pages

Build all 6 auth pages with desktop split-panel layout (brand left, form right).

**Pages to build:**
- `pages/auth/login_page.dart` — Email/password + OAuth (Google/Apple)
- `pages/auth/register_page.dart` — Name, email, password or OAuth
- `pages/auth/verify_page.dart` — Phone OTP verification
- `pages/auth/callback_page.dart` — OAuth redirect handler
- `pages/auth/forgot_page.dart` — Password reset via magic link
- `pages/auth/qr_page.dart` — QR scan from mobile to auth web session

**Shared auth layout pattern:**

```dart
/// Desktop: brand panel left, form right (50/50).
/// Tablet: brand panel 40%, form 60%.
/// Mobile: form only, brand as header strip.
class AuthLayout extends StatelessWidget {
  final Widget formContent;
  // ...
}
```

**Auth provider:**

Create `beautycita_web/lib/providers/auth_provider.dart` — manages login state, role detection, OAuth flow, error handling. Uses `BCSupabase.client.auth`.

**Post-auth redirect logic** (in router):
- Query `profiles` table for user role
- `admin` / `superadmin` → `/app/admin`
- `stylist` / `salon_owner` → `/app/negocio`
- `client` → `/app/reservar` (or `/app/mis-citas` if returning)

**Key implementation details:**
- Google OAuth: Use Supabase `signInWithOAuth(OAuthProvider.google)` with redirect URL
- Apple OAuth: Same pattern with `OAuthProvider.apple`
- Email/password: `signInWithPassword(email, password)`
- Phone OTP: Call `phone-verify` edge function (send-code action), then verify-code
- QR auth: Call `qr-auth` edge function (create action), display QR, poll for authorization
- Password reset: `resetPasswordForEmail(email, redirectTo: '/app/auth/callback')`

**Commit after each page is functional.**

---

### Task 1.3: Build admin shell with responsive sidebar

The admin shell is the persistent layout wrapper for all `/app/admin/*` routes.

**Files:**
- Rewrite: `beautycita_web/lib/shells/admin_shell.dart`
- Create: `beautycita_web/lib/widgets/admin_sidebar.dart`
- Create: `beautycita_web/lib/widgets/admin_topbar.dart`

**Layout behavior:**

| Width | Sidebar | Content | Detail Panel |
|-------|---------|---------|-------------|
| >1200px | Full (240px) | Expanded | Right panel (400px) if open |
| 800-1200px | Icons only (64px) | Expanded | Overlay/modal |
| <800px | Hidden (hamburger) | Full width | Full screen modal |

**Sidebar content:**
- BC logo/avatar at top
- Navigation items with icons + labels:
  - Dashboard, Users, Salons, Bookings, Services, Disputes, Finance, Analytics, Engine, Outreach, Config, Toggles
- Active route highlighted
- Collapse/expand button
- User info + logout at bottom

**Keyboard shortcuts foundation:**
- `/` → focus search
- `Esc` → close detail panel
- Arrow keys → navigate tables (implemented per-page)

**Implementation pattern:**
- `AdminShell` is a `StatefulWidget` that tracks sidebar state (expanded/collapsed/hidden)
- Uses `LayoutBuilder` to detect breakpoint
- `Scaffold` with no AppBar — custom topbar widget
- `Row` layout: sidebar + content + optional detail panel
- Sidebar state persisted in `SharedPreferences`

---

### Task 1.4: Build admin dashboard page

**Route:** `/app/admin`

**Files:**
- Create: `beautycita_web/lib/pages/admin/dashboard_page.dart`
- Create: `beautycita_web/lib/providers/admin_dashboard_provider.dart`

**Layout:**
- Top row: 4 KPI cards (revenue, active users, bookings today, registered salons)
- Middle: Activity feed (realtime) + Alerts panel
- Bottom: Quick charts (bookings this week, revenue trend)

**Data sources:**
- KPI cards: Supabase queries against `appointments`, `profiles`, `businesses`
- Activity feed: Supabase realtime subscription on `appointments`, `profiles` (new signups)
- Alerts: Pending disputes, unverified salons, failed payments

**Realtime:**
```dart
BCSupabase.client
  .from(BCTables.appointments)
  .stream(primaryKey: ['id'])
  .listen((data) { /* update feed */ });
```

---

### Task 1.5: Build admin master-detail pattern (reusable)

Before building individual admin pages, create the reusable master-detail layout pattern that all data pages share.

**Files:**
- Create: `beautycita_web/lib/widgets/master_detail_layout.dart`
- Create: `beautycita_web/lib/widgets/data_table_page.dart`
- Create: `beautycita_web/lib/widgets/detail_panel.dart`
- Create: `beautycita_web/lib/widgets/filter_bar.dart`
- Create: `beautycita_web/lib/widgets/bulk_action_bar.dart`

**Pattern:**
```
┌──────────┬──────────────────────┬─────────────┐
│ Sidebar  │  Filter bar          │             │
│          ├──────────────────────┤ Detail      │
│          │  Data table          │ Panel       │
│          │  (selectable rows)   │ (selected   │
│          │  ☐ Row 1             │  item info) │
│          │  ☑ Row 2             │             │
│          │  ☐ Row 3             │             │
│          ├──────────────────────┤             │
│          │  Bulk action bar     │             │
│          │  (when items checked)│             │
└──────────┴──────────────────────┴─────────────┘
```

**Features:**
- Sortable columns (click header)
- Search/filter bar at top
- Checkbox select for bulk actions
- Click row → detail panel slides in from right
- Pagination (cursor-based, not offset)
- Loading skeletons while fetching
- Empty state illustrations (from graphics assets)

---

### Task 1.6: Build admin users page

**Route:** `/app/admin/users`

**Files:**
- Create: `beautycita_web/lib/pages/admin/users_page.dart`
- Create: `beautycita_web/lib/pages/admin/user_detail_panel.dart`
- Create: `beautycita_web/lib/providers/admin_users_provider.dart`

**Table columns:** Username, Email, Role, Phone (verified?), Created, Last Active, Status

**Filters:** Role dropdown, search by name/email, date range, status (active/inactive)

**Detail panel:** Full profile, booking history, linked accounts, admin notes, role change, suspend/activate actions

**Data:** `BCTables.profiles` with joins

---

### Task 1.7: Build admin salons page

**Route:** `/app/admin/salons`

**Files:**
- Create: `beautycita_web/lib/pages/admin/salons_page.dart`
- Create: `beautycita_web/lib/pages/admin/salon_detail_panel.dart`
- Create: `beautycita_web/lib/providers/admin_salons_provider.dart`

**Two tabs:** Registered salons (`businesses`) + Discovered salons (`discovered_salons`)

**Registered table columns:** Name, City, Services, Rating, Bookings, Revenue, Stripe Status, Verified

**Discovered table columns:** Name, Source, Phone, City, WA Status, Last Contact, Interest Signals

**Detail panel:** Full business profile, services list, staff, recent bookings, revenue chart, verification status, Stripe Connect link

---

### Task 1.8: Build admin bookings page

**Route:** `/app/admin/bookings`

**Files:**
- Create: `beautycita_web/lib/pages/admin/bookings_page.dart`
- Create: `beautycita_web/lib/pages/admin/booking_detail_panel.dart`
- Create: `beautycita_web/lib/providers/admin_bookings_provider.dart`

**Table columns:** ID, Client, Salon, Service, Date/Time, Status, Amount, Payment

**Filters:** Date range, status (pending/confirmed/cancelled/completed/no-show), salon, client search

**Detail panel:** Full appointment info, client + salon links, payment details, timeline (created → confirmed → completed), admin actions (cancel, refund, reassign)

---

### Task 1.9: Build remaining admin data pages

Following the same master-detail pattern from Task 1.5:

**Services page** (`/app/admin/services`):
- Service catalog tree view (categories → subcategories → items)
- Inline editing of names, prices, durations
- Drag-to-reorder within categories

**Disputes page** (`/app/admin/disputes`):
- Table: ID, Client, Salon, Booking, Type, Amount, Status, Filed Date
- Detail: Full dispute info, booking link, resolution workflow (review → decide → execute → close)

**Finance page** (`/app/admin/finance`):
- Revenue overview charts (fl_chart)
- Payout history table
- Stripe Connect aggregate stats
- BTCPay Server stats
- Platform fee collection summary

**Analytics page** (`/app/admin/analytics`):
- Bookings over time (line chart)
- User growth (area chart)
- Revenue by service category (bar chart)
- Geographic heatmap of bookings
- Peak hours heatmap
- Retention metrics

---

### Task 1.10: Build admin engine tuning pages

**Routes:**
- `/app/admin/engine` — Overview of engine performance metrics
- `/app/admin/engine/profiles` — Per-service weights, radius, thresholds with live preview
- `/app/admin/engine/categories` — Service hierarchy editor (tree view, drag-to-reorder)
- `/app/admin/engine/time` — Time inference rules per service type

**Engine profiles page:**
- Table of service types with their current weights
- Click → edit panel with sliders for: quality weight, distance weight, price weight, availability weight, search radius, max results
- Live preview: shows what results would look like with current weights
- Save → updates `service_profiles` table

**Category tree page:**
- Nested tree view: Category → Subcategory → Service Item
- Drag-to-reorder
- Inline add/edit/delete
- Saves to `service_categories_tree`

**Time rules page:**
- Matrix view: service type × day-of-week × hour-range → booking window
- Edit rules that control time inference
- Saves to `time_inference_rules`

---

### Task 1.11: Build admin outreach, config, and toggles pages

**Outreach page** (`/app/admin/outreach`):
- Kanban-style pipeline: New → Contacted → Responded → Interested → Onboarded
- Cards show discovered salon info with WA message history
- Action buttons: Send WA, Mark interested, Import to platform
- Data from `discovered_salons` + `salon_outreach_log`

**Config page** (`/app/admin/config`):
- Key-value settings from `app_config` table
- API key status indicators (Stripe, Mapbox, Google, BTCPay, OpenAI)
- System health checks

**Feature toggles page** (`/app/admin/toggles`):
- Toggle switches for features: Bitcoin payments, Uber integration, Virtual studio, Aphrodite AI, etc.
- Saves to `app_config` table
- Realtime effect (both apps read these on startup)

---

### Task 1.12: Deploy Phase 1 to server

**Step 1: Build WASM**

```bash
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter build web --wasm --release --no-tree-shake-icons
```

**Step 2: Deploy to server**

```bash
rsync -avz --delete build/web/ www-bc:/var/www/beautycita.com/webapp/dist/
```

**Step 3: Update nginx** (if needed)

Add location block for `/app/` to serve Flutter web app:
```nginx
location /app/ {
    alias /var/www/beautycita.com/webapp/dist/;
    try_files $uri $uri/ /app/index.html;
}
```

**Step 4: Smoke test**

Visit `https://beautycita.com/app/auth` — should show login page.
Log in as admin → should redirect to `/app/admin` with full dashboard.

**Step 5: Commit and push**

```bash
cd /home/bc/futureBeauty
git add .
git commit -m "feat: Phase 1 complete — auth system + admin panel"
git push origin main
```

---

## Phase 2: Business Dashboard (Outline)

**Outcome:** Salon owners and stylists can manage their entire operation from desktop.

### Tasks:

**Task 2.1:** Build business shell with sidebar (same responsive pattern as admin)

**Task 2.2:** Build business dashboard page — today's schedule, quick stats, pending actions, recent reviews

**Task 2.3:** Build calendar page — full-width interactive week view using `table_calendar` or custom grid, drag-to-create appointments, drag-to-reschedule, staff color coding, hover for details

**Task 2.4:** Build bookings page — all appointments with date/status/staff filters, confirm/cancel/no-show actions

**Task 2.5:** Build clients page — client list with visit history, spend totals, notes, click → full profile with booking timeline

**Task 2.6:** Build services page — add/edit/remove services, inline price/duration editing, staff assignments, drag-to-reorder

**Task 2.7:** Build staff management pages — team list, per-staff schedules (weekly availability), vacation/day-off management, service assignments, color coding

**Task 2.8:** Build finance page — revenue charts, payout history, Stripe Connect dashboard, tips, commissions

**Task 2.9:** Build marketing hub — QR codes (custom branded), business cards, social cards, embeddable booking widget with code snippet

**Task 2.10:** Build portfolio page — photo gallery with upload, tag, reorder, set featured

**Task 2.11:** Build analytics page — trends, peak hours heatmap, service popularity, retention, revenue per service

**Task 2.12:** Build reviews page — all reviews with response capability, flag, average rating over time

**Task 2.13:** Build settings page — business info, location, hours, payment setup (Stripe Connect onboarding), notification preferences

**Task 2.14:** Deploy Phase 2

---

## Phase 3: Client Experience (Outline)

**Outcome:** Clients can book with confidence from desktop — more information, more control than mobile.

### Tasks:

**Task 3.1:** Build client shell with top navbar and account dropdown (NOT sidebar — clients don't need sidebar)

**Task 3.2:** Build booking flow — 4-step progressive flow:
1. Service selection (category grid + subcategory chips, context panel with service info)
2. Follow-up details (multi-column, larger image options)
3. Results (top 3 curated side-by-side, galleries, prices, schedules, map)
4. Confirm (split view: booking summary left, payment right)

**Task 3.3:** Build my bookings page — table of past/upcoming, filter by status/date, click → detail with receipt/review/dispute options

**Task 3.4:** Build favorites page — saved salons grid with quick-book button

**Task 3.5:** Build messages page — split-pane chat (thread list left, conversation right), Aphrodite AI chat

**Task 3.6:** Build settings page — profile, phone, payment methods, notifications, linked accounts

**Task 3.7:** Build notifications page — full history with type filters

**Task 3.8:** Deploy Phase 3

---

## Phase 4: Static SEO Pages (Outline)

**Outcome:** Google-indexable public pages for the marketing site.

### Tasks:

**Task 4.1:** Create shared HTML/CSS framework — header, footer, responsive grid, brand styles (Rose #660033, Gold #FFB300, Cream #FFF8F0)

**Task 4.2:** Build landing page (`public/index.html`) — hero section, how it works, for clients, for salons, download CTA

**Task 4.3:** Build registration page (`public/registro/`) — salon registration form that links to Flutter app

**Task 4.4:** Build pricing page (`public/precios/`) — feature/price comparison vs competitors (Vagaro, Fresha, etc.)

**Task 4.5:** Build info pages — `contacto/`, `nosotros/`, `prensa/`, `empleo/`

**Task 4.6:** Build legal pages — `cookies/`, `privacidad/`, `terminos/`

**Task 4.7:** SEO optimization — meta tags, Open Graph, structured data (LD+JSON), sitemap.xml, robots.txt

**Task 4.8:** Deploy static pages and configure nginx routing

---

## Phase 5: Graphics Integration (Outline)

**Outcome:** 64 custom illustrations deployed throughout both web and mobile apps.

### Tasks:

**Task 5.1:** Receive graphics zip from BC, unzip on server

**Task 5.2:** Generate WebP variants (quality 85) for web

**Task 5.3:** Generate @2x and @1x sizes for mobile

**Task 5.4:** Upload all variants to Supabase Storage `brand-assets` bucket

**Task 5.5:** Create Dart constants file mapping asset names to URLs (in `beautycita_core`)

**Task 5.6:** Integrate category icons throughout booking flow (both apps)

**Task 5.7:** Integrate empty state illustrations (both apps)

**Task 5.8:** Integrate status/feedback illustrations

**Task 5.9:** Integrate landing page hero illustrations (static pages)

**Task 5.10:** Integrate dashboard decorative elements

---

## Phase 6: Legacy Cleanup (Outline)

**Outcome:** Old webapp code deleted, server cleaned up, nginx updated.

### Tasks:

**Task 6.1:** Verify all functionality works on new webapp

**Task 6.2:** Remove `/var/www/beautycita.com/frontend/dist/` from server

**Task 6.3:** Update nginx to remove old frontend location block

**Task 6.4:** Clean up any old references in CLAUDE.md, memory files, deploy scripts

**Task 6.5:** Final deployment verification

---

## Execution Notes

**Build commands (reference):**

```bash
# Flutter web (WASM)
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter build web --wasm --release --no-tree-shake-icons

# Deploy Flutter app
rsync -avz --delete build/web/ www-bc:/var/www/beautycita.com/webapp/dist/

# Deploy static pages
rsync -avz --delete /home/bc/futureBeauty/public/ www-bc:/var/www/beautycita.com/public/

# Mobile app (unchanged)
cd /home/bc/futureBeauty/beautycita_app
/home/bc/flutter/bin/flutter build apk --release --no-tree-shake-icons --target-platform android-arm64
```

**Testing approach:**
- Unit tests for shared package models (fromJson/toJson roundtrip)
- Widget tests for key web components (admin shell responsive behavior, auth flow)
- Manual smoke tests after each deployment
- BC tests admin panel as daily driver

**Commit frequency:** After every completed task. Small, focused commits.
