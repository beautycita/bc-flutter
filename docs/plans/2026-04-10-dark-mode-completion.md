# Dark Mode Completion Plan — Workstation Execution

**Date:** 2026-04-10
**Status:** Phases 0-4 were incomplete. This plan finishes the job.
**Palette:** Single palette only — `beautycitaPalette` (light) + `beautycitaDarkPalette` (dark). All experimental palettes have been deleted. Do NOT recreate them.

---

## Rules

1. `git pull` before starting
2. **NEVER use `Colors.white`, `Colors.black`, or hardcoded `Color(0xFF...)` in any file you touch.** Use `Theme.of(context).colorScheme` or the palette's named colors.
3. Replace `Colors.white` → `Theme.of(context).colorScheme.surface` or `.onPrimary` (context dependent)
4. Replace `Colors.black` → `Theme.of(context).colorScheme.onSurface` or `.surface` (context dependent)
5. Replace `Colors.black54` / `Colors.black38` → `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)` etc.
6. `flutter analyze` must pass after every phase
7. One commit per phase: `Dark mode fix Phase X: <description>`
8. `git push` after every commit

---

## Phase 1: Settings Toggle (CRITICAL — users can't switch modes)

**File:** `lib/screens/settings_screen.dart`

Add a dark mode toggle in the settings screen. Use the existing `ThemeNotifier.setThemeMode()`:

```dart
// In the settings list, add a section:
ListTile(
  leading: Icon(
    Theme.of(context).brightness == Brightness.dark
        ? Icons.dark_mode
        : Icons.light_mode,
  ),
  title: const Text('Modo Oscuro'),
  trailing: Switch(
    value: ref.watch(themeProvider).themeMode == ThemeMode.dark,
    onChanged: (dark) {
      ref.read(themeProvider.notifier).setThemeMode(
        dark ? ThemeMode.dark : ThemeMode.light,
      );
    },
  ),
),
```

**DONE when:** Toggle appears in settings, switching it changes the entire app theme, and the choice persists after app restart.

---

## Phase 2: Core Screens — Hardcoded Color Removal (608+ instances)

Work through these files IN ORDER. For each file, search for `Colors.white`, `Colors.black`, and any `Color(0xFF` that isn't in palettes.dart, and replace with theme-aware equivalents.

**Priority order (highest user impact first):**

### 2a. Chat screens
- `lib/screens/chat_list_screen.dart` — 10+ hardcoded
- `lib/widgets/chat_animations.dart` — 8+ hardcoded

### 2b. Help & Legal
- `lib/screens/help_screen.dart` — 12+ hardcoded (white-on-white in dark mode)
- `lib/screens/legal_screens.dart` — 8+ hardcoded

### 2c. QR Scanner
- `lib/screens/qr_scan_screen.dart` — 23+ hardcoded (completely broken)

### 2d. Salon Onboarding
- `lib/screens/salon_onboarding_screen.dart` — 55+ hardcoded

### 2e. Media & Image
- `lib/widgets/media_viewer.dart` — 15+ hardcoded
- `lib/widgets/bc_image_editor.dart` — 10+ hardcoded
- `lib/widgets/bc_image_picker_sheet.dart` — 8+ hardcoded

### 2f. Other Widgets
- `lib/widgets/outreach_contact_sheet.dart` — 95+ hardcoded (worst file)
- `lib/widgets/phone_verify_gate_sheet.dart` — 8+ hardcoded
- `lib/widgets/route_map_widget.dart` — 6+ hardcoded
- `lib/widgets/contact_salon_card.dart` — 6+ hardcoded
- `lib/widgets/save_contact_prompt.dart` — 5+ hardcoded

### 2g. Remaining Screens
- `lib/screens/about_screen.dart` — 8+ hardcoded
- `lib/screens/press_screen.dart` — 8+ hardcoded
- `lib/screens/splash_screen.dart` — verify dark gradient works correctly

**Common replacements:**

| Hardcoded | Theme-aware replacement |
|-----------|----------------------|
| `Colors.white` | `Theme.of(context).colorScheme.surface` or `.onPrimary` |
| `Colors.black` | `Theme.of(context).colorScheme.onSurface` |
| `Colors.black54` | `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)` |
| `Colors.black38` | `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)` |
| `Colors.black87` | `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87)` |
| `Colors.white70` | `Theme.of(context).colorScheme.surface.withValues(alpha: 0.70)` |
| `Color(0xFFFFFFFF)` | `Theme.of(context).colorScheme.surface` |
| `Color(0xFF000000)` | `Theme.of(context).colorScheme.onSurface` |
| `Color(0xFFF5F5F5)` | `Theme.of(context).colorScheme.surfaceContainerLowest` |
| `Color(0xFF212121)` | `Theme.of(context).colorScheme.onSurface` |
| `Color(0xFF757575)` | `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)` |

**DONE when:** `grep -rn "Colors.white\|Colors.black" lib/ --include="*.dart" | grep -v test/ | grep -v palettes.dart | wc -l` returns 0.

---

## Phase 3: Admin & Business Screens

All 40+ admin screens have hardcoded financial dashboard colors. These are lower priority since admins are internal users, but they still need to work in dark mode.

**Files:** Everything in `lib/screens/admin/` and `lib/screens/business/`

Focus on:
- Table headers and row backgrounds
- Chart colors (these can stay hardcoded if they're data visualization colors, not UI chrome)
- Card backgrounds and borders
- Text colors in data displays

**DONE when:** Admin dashboard is visually usable in dark mode (no invisible text, no white-on-white).

---

## Phase 4: Shadows & Overlays

Replace all hardcoded shadow colors:

```dart
// BAD:
BoxShadow(color: Colors.black.withValues(alpha: 0.1), ...)

// GOOD:
BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.1), ...)
```

Or for dark mode where shadows should be darker:
```dart
BoxShadow(
  color: Theme.of(context).brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.3)
      : Colors.black.withValues(alpha: 0.1),
  ...
)
```

**DONE when:** No `BoxShadow` in the codebase uses a hardcoded color.

---

## Phase 5: Loading & Shimmer States

All `CircularProgressIndicator` and loading states must use theme colors:

```dart
// BAD:
CircularProgressIndicator(color: Colors.white)

// GOOD:
CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)
```

**DONE when:** All loading indicators adapt to dark mode.

---

## Phase 6: Final Verification

1. Run `grep -rn "Colors.white\|Colors.black" lib/ --include="*.dart" | grep -v test/ | grep -v palettes.dart` — must return ZERO results
2. Run `grep -rn "Color(0xFFFFFFFF)\|Color(0xFF000000)" lib/ --include="*.dart" | grep -v test/ | grep -v palettes.dart` — must return ZERO results
3. Toggle dark mode ON, navigate through every screen: home, booking flow, results, chat, settings, help, about, legal, QR scanner, admin dashboard
4. Toggle dark mode OFF, verify nothing broke
5. `flutter analyze` — zero errors

**DONE when:** All 5 checks pass.

---

## IMPORTANT NOTES

- **Do NOT recreate experimental palettes.** They are deleted. Only `beautycitaPalette` and `beautycitaDarkPalette` exist.
- **Do NOT add a palette picker/selector.** The palette is locked to BeautyCita brand colors.
- **The dark mode toggle in settings is the ONLY user-facing theme control.**
- **Chart/data visualization colors** (financial dashboards) can stay hardcoded if they're semantic data colors (red = loss, green = profit). Only UI chrome (backgrounds, text, borders) needs theming.
- **Accessibility:** Dark mode text must have at least 4.5:1 contrast ratio against its background. Use `onSurface` for text on `surface`, `onPrimary` for text on `primary`.
