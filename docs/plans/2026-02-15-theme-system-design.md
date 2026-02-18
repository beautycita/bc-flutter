# BeautyCita Theme System Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a 7-theme system with palette-driven ThemeData factory, theme persistence, and visual theme picker. Convert all ~47 files with hardcoded colors to use theme tokens.

**Architecture:** Single `BCPalette` class defines all color/gradient/typography/spacing/radius tokens. A factory function `buildTheme(BCPalette)` generates complete `ThemeData`. A Riverpod `themeProvider` persists selection to SharedPreferences and drives `MaterialApp.router`'s `theme`/`darkTheme`/`themeMode`.

**Tech Stack:** Flutter Material 3, Riverpod, SharedPreferences, Google Fonts (Poppins/Nunito bundled)

---

## 1. Themes

Seven themes, each with a distinct personality:

### 1.1 Rose & Gold (Current - UNTOUCHED palette values)
- Primary: `#C2185B` (rose), Secondary: `#FFB300` (gold), Surface: `#FFF8F0` (cream)
- Light mode only. Warm, feminine luxury. The original.
- **Palette hex values are frozen** - this is the baseline reference.

### 1.2 Black & Gold
- Background: `#0A0A0F`, Surface: `#1A1A2E`, Primary: `#FFB300` (gold), Accent: `#D4AF37`
- Gold metallic gradient on dark surfaces. Premium masculine elegance.
- Cards: frosted dark glass (`#1A1A2E` at 80% opacity + subtle gold border)

### 1.3 Glassmorphism
- Background: `#0A0A1A` with animated gradient mesh, Surface: frosted glass (`rgba(255,255,255,0.08)`)
- Primary: `#EC4899` (pink) -> `#9333EA` (purple) -> `#3B82F6` (blue) gradient
- All cards/sheets use `BackdropFilter` with `ImageFilter.blur(sigmaX: 20, sigmaY: 20)`
- Borders: 1px `rgba(255,255,255,0.15)`. Glow effects on interactive elements.

### 1.4 Midnight Orchid
- Background: `#0D0015`, Primary: `#B388FF` (soft lavender), Accent: `#E040FB` (electric orchid)
- Surface: `#1A0A2E`. Bioluminescent glow effects on buttons/highlights.
- Gradient: purple -> magenta. Dreamy, ethereal.

### 1.5 Ocean Noir
- Background: `#0A1628`, Primary: `#00E5FF` (cyan), Accent: `#1DE9B6` (seafoam)
- Surface: `#0D2137`. Fluid teal-to-cyan gradients.
- Neon glow on CTAs. Deep sea luxury.

### 1.6 Cherry Blossom
- Background: `#FFF5F7`, Primary: `#FF6B9D` (sakura pink), Accent: `#C084FC` (wisteria)
- Surface: `#FFFFFF`. Soft pastel gradients pink -> lavender.
- Light mode. Gentle, modern, Instagram-friendly.

### 1.7 Emerald Luxe
- Background: `#0A1F0A`, Primary: `#00E676` (emerald), Accent: `#FFD700` (gold)
- Surface: `#0F2A0F`. Rich green-gold combination.
- Old money aesthetic. Green marble textures optional.

---

## 2. Architecture

### 2.1 BCPalette (Color Token System)

```dart
class BCPalette {
  // Core
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color surface;
  final Color onSurface;
  final Color background;
  final Color onBackground;
  final Color error;
  final Color onError;

  // Extended
  final Color cardColor;
  final Color cardBorder;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color shimmer;
  final Color scaffoldBackground;

  // Status
  final Color success;
  final Color warning;
  final Color info;

  // Gradients
  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final List<Color> goldGradientStops; // 13-stop metallic gold

  // Category colors (8 colors for service categories)
  final List<Color> categoryColors;

  // Typography
  final String headingFont;      // default: 'Poppins'
  final String bodyFont;         // default: 'Nunito'
  final Color headingColor;
  final Color bodyColor;

  // Spacing & Radius scale factors (1.0 = current defaults)
  final double spacingScale;     // multiplier on AppConstants spacing
  final double radiusScale;      // multiplier on AppConstants radii

  // Glass morphism properties (null = no glass effect)
  final double? blurSigma;       // null for non-glass themes
  final Color? glassTint;
  final double? glassBorderOpacity;

  // Brightness
  final Brightness brightness;

  // CinematicQuestionText overrides
  final Color cinematicPrimary;
  final Color cinematicAccent;
  final List<Color>? cinematicGradient; // null = use goldGradientStops

  // System UI
  final Color statusBarColor;
  final Brightness statusBarIconBrightness;
  final Color navigationBarColor;
  final Brightness navigationBarIconBrightness;
}
```

### 2.2 Theme Factory

```dart
ThemeData buildThemeFromPalette(BCPalette palette) {
  // Returns complete ThemeData with:
  // - ColorScheme from palette
  // - TextTheme using palette fonts + colors
  // - All component themes (card, button, input, chip, sheet, etc.)
  // - Applies spacingScale and radiusScale to all dimensions
}
```

One function, zero duplication. Every theme is just a `BCPalette` instance.

### 2.3 Theme Provider (Riverpod)

```dart
// theme_provider.dart
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) => ...);

class ThemeState {
  final String themeId;     // 'rose_gold', 'black_gold', 'glass', etc.
  final ThemeData themeData;
  final BCPalette palette;
}
```

- Persists `themeId` to SharedPreferences key `'selected_theme'`
- Loads on app start, defaults to `'rose_gold'`
- Exposes `palette` for widgets needing extended tokens beyond ThemeData

### 2.4 BCThemeExtension

For tokens that don't fit in standard ThemeData, use `ThemeExtension<BCThemeExtension>`:

```dart
class BCThemeExtension extends ThemeExtension<BCThemeExtension> {
  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final List<Color> goldGradientStops;
  final List<Color> categoryColors;
  final double? blurSigma;
  final Color? glassTint;
  final Color cinematicPrimary;
  final Color cinematicAccent;
  final List<Color>? cinematicGradient;
  final double spacingScale;
  final double radiusScale;
}
```

Access: `Theme.of(context).extension<BCThemeExtension>()!`

---

## 3. Theme Picker UI

### 3.1 Settings Integration

Current settings screen at `settings_screen.dart` has navigation tiles. Add a new tile:

```
Preferencias
Mis citas
Metodos de pago
Apariencia        <-- NEW (between Metodos de pago and Seguridad)
Seguridad y cuenta
```

### 3.2 Apariencia Screen

- **Header**: "Elige tu estilo" with CinematicQuestionText (themed)
- **Grid**: 2-column grid of theme preview cards
- **Each card**:
  - Mini phone mockup showing theme colors (gradient header, card samples, button)
  - Theme name below
  - Gold checkmark on selected theme
  - Tap = instant preview (theme applies immediately)
- **Bottom**: "Restablecer" link to reset to Rose & Gold

---

## 4. Scope: Files to Modify

### 4.1 Untouched (NEVER modify)
- `invite_salon_screen.dart` — WhatsApp themed, stays WhatsApp green
- Rose & Gold palette hex values — frozen as-is

### 4.2 WhatsApp Contact Buttons (keep green, but from palette)
- `provider_detail_screen.dart:390` — WhatsApp button stays `#25D366`
- `provider_list_screen.dart:332` — WhatsApp button stays `#25D366`
- These are WhatsApp brand colors, not our theme. Keep as constants.

### 4.3 Files Getting Hardcoded Colors Replaced (~47 files)

**Screens (30 files):**
- home_screen, auth_screen, splash_screen, settings_screen, profile_screen
- preferences_screen, security_screen, booking_flow_screen, booking_screen
- booking_detail_screen, my_bookings_screen, follow_up_question_screen
- result_cards_screen, confirmation_screen, transport_selection
- time_override_sheet, subcategory_sheet, provider_list_screen
- provider_detail_screen, discovered_salon_detail_screen, salon_onboarding_screen
- chat_list_screen, chat_router_screen, chat_conversation_screen
- device_manager_screen, qr_scan_screen, payment_methods_screen
- media_manager_screen, virtual_studio_screen

**Admin screens (8 files):**
- admin_shell_screen, salon_management_screen, service_profile_editor_screen
- engine_settings_editor_screen, category_tree_screen, time_rules_screen
- analytics_screen, notification_templates_screen

**Widgets (7 files):**
- cinematic_question_text, bc_button, bc_loading, settings_widgets
- location_picker_sheet, bc_image_picker_sheet, media_viewer

**Config/Data (3 files):**
- theme.dart (rewrite), constants.dart (add scale support), categories.dart (colors to palette)

**Providers (2 files):**
- booking_flow_provider, payment_methods_provider

**Services (1 file):**
- toast_service

**Entry (2 files):**
- main.dart (wire themeProvider), routes.dart

### 4.4 New Files to Create
- `lib/config/palettes.dart` — All 7 BCPalette definitions
- `lib/config/theme_extension.dart` — BCThemeExtension class
- `lib/providers/theme_provider.dart` — Riverpod theme state
- `lib/screens/appearance_screen.dart` — Theme picker UI

### 4.5 Gold Gradient Consolidation

The 13-stop gold gradient is duplicated in 8+ files. It moves into `BCPalette.goldGradientStops` and `BCThemeExtension`. All duplicates get replaced with:

```dart
final ext = Theme.of(context).extension<BCThemeExtension>()!;
final gradient = LinearGradient(colors: ext.goldGradientStops);
```

### 4.6 CinematicQuestionText

Currently hardcoded to rose + gold. Will read from `BCThemeExtension.cinematicPrimary`, `.cinematicAccent`, and `.cinematicGradient`. Each theme defines its own cinematic colors — Glassmorphism gets neon glow, Ocean Noir gets cyan pulse, etc.

### 4.7 Category Colors

Currently 8 hardcoded colors in `categories.dart`. Moves to `BCPalette.categoryColors`. Each theme can have its own category color palette that harmonizes with its aesthetic.

---

## 5. Conversion Strategy

### Pattern: Replace Hardcoded -> Theme Token

**Before:**
```dart
color: Color(0xFFC2185B)
color: BeautyCitaTheme.primaryRose
```

**After:**
```dart
color: Theme.of(context).colorScheme.primary
```

**Before (gradient):**
```dart
final _goldGradient = LinearGradient(colors: [Color(0xFF8B6914), ...]);
```

**After:**
```dart
final ext = Theme.of(context).extension<BCThemeExtension>()!;
final goldGradient = LinearGradient(colors: ext.goldGradientStops);
```

**Before (spacing):**
```dart
padding: EdgeInsets.all(16)
```

**After (scaled):**
```dart
padding: EdgeInsets.all(AppConstants.paddingMD * ext.spacingScale)
```

### SystemChrome Updates

`main.dart` currently hardcodes light system UI. After theme system:
```dart
SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
  statusBarColor: palette.statusBarColor,
  statusBarIconBrightness: palette.statusBarIconBrightness,
  systemNavigationBarColor: palette.navigationBarColor,
  systemNavigationBarIconBrightness: palette.navigationBarIconBrightness,
));
```

This updates reactively when theme changes.

---

## 6. Theme Personality Details

Each theme isn't just a color swap. They have distinct character:

| Theme | Gradients | Card Style | Button Style | Animations |
|-------|-----------|-----------|-------------|------------|
| Rose & Gold | Rose→deep rose, gold shimmer | Cream cards, gold border | Rose filled, gold accent | Gold shimmer |
| Black & Gold | Gold metallic | Dark glass, gold border | Gold filled on dark | Gold particle sparkle |
| Glassmorphism | Pink→purple→blue mesh | Frosted glass + blur | Gradient border, glass fill | Neon pulse glow |
| Midnight Orchid | Purple→magenta | Dark purple glass | Lavender glow | Bioluminescent pulse |
| Ocean Noir | Teal→cyan | Deep blue glass | Cyan neon border | Wave ripple |
| Cherry Blossom | Pink→lavender soft | White cards, pink border | Sakura pink filled | Petal float |
| Emerald Luxe | Green→gold | Dark emerald, gold trim | Emerald filled | Gold-green shimmer |

---

## 7. Migration Safety

- Rose & Gold theme must produce **identical** output to current `BeautyCitaTheme.lightTheme`
- All other themes are additive — no existing behavior changes
- Theme defaults to `rose_gold` on first launch (exact same as today)
- If theme loading fails, falls back to Rose & Gold
- WhatsApp brand colors (`#25D366`, `#075E54`) stay as app-level constants, never themed

---

## Verification

1. Build APK with all 7 themes
2. Screenshot each theme on: home, booking flow, settings, confirmation
3. Verify Rose & Gold is pixel-identical to current build
4. Verify WhatsApp screens unchanged
5. Verify theme persists across app restart
6. Verify SystemChrome updates (status bar, nav bar) per theme
