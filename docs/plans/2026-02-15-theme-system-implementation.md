# BeautyCita Theme System Implementation Plan

> **For Claude (Loki mode):** Execute this plan autonomously, task by task, in order.
> Do NOT ask questions. Do NOT pause for review between tasks. Just execute all 14 tasks end-to-end.
> After each task, run the verification step. If it fails, fix it before moving to the next task.
> When all 14 tasks are done, build the release APK and report the result.
>
> **CRITICAL RULES:**
> - Project root: `/home/bc/futureBeauty/beautycita_app`
> - Flutter: `/home/bc/flutter/bin/flutter`
> - Branch: `feature/loki-web-rebuild` (already checked out)
> - The `invite_salon_screen.dart` is UNTOUCHED — do NOT modify it
> - WhatsApp colors (`#25D366`, `#075E54`) use `kWhatsAppGreen`/`kWhatsAppDarkGreen` constants, NEVER themed
> - Rose & Gold palette hex values are FROZEN — identical to current `BeautyCitaTheme` statics
> - Google Fonts are BUNDLED (no runtime fetching) — `GoogleFonts.config.allowRuntimeFetching = false` is in main.dart
> - Commit after each task with the message provided
> - If `flutter analyze` shows pre-existing warnings that are NOT from your changes, ignore them and proceed

**Goal:** Build a 7-theme palette system with visual theme picker, converting all ~47 files with hardcoded colors to use theme tokens.

**Architecture:** `BCPalette` defines all color/gradient/typography tokens per theme. `buildThemeFromPalette()` factory generates `ThemeData` + `BCThemeExtension`. Riverpod `themeProvider` persists selection to SharedPreferences and drives `MaterialApp.router`.

**Tech Stack:** Flutter 3.38, Material 3, Riverpod, SharedPreferences, Google Fonts (Poppins/Nunito bundled), GoRouter

---

## Task 1: Create BCPalette and BCThemeExtension classes

**Files:**
- Create: `lib/config/palettes.dart`
- Create: `lib/config/theme_extension.dart`

**Step 1: Create `lib/config/theme_extension.dart`**

```dart
import 'package:flutter/material.dart';

/// Extended theme tokens that don't fit in standard ThemeData.
/// Access via: Theme.of(context).extension<BCThemeExtension>()!
class BCThemeExtension extends ThemeExtension<BCThemeExtension> {
  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final List<Color> goldGradientStops;
  final List<double> goldGradientPositions;
  final List<Color> categoryColors;

  // Glass morphism (null = no glass effect)
  final double? blurSigma;
  final Color? glassTint;
  final double? glassBorderOpacity;

  // CinematicQuestionText
  final Color cinematicPrimary;
  final Color cinematicAccent;
  final List<Color>? cinematicGradient;

  // Scale factors
  final double spacingScale;
  final double radiusScale;

  // System UI
  final Color statusBarColor;
  final Brightness statusBarIconBrightness;
  final Color navigationBarColor;
  final Brightness navigationBarIconBrightness;

  // Extra palette colors not in ColorScheme
  final Color cardBorderColor;
  final Color shimmerColor;
  final Color successColor;
  final Color warningColor;
  final Color infoColor;

  const BCThemeExtension({
    required this.primaryGradient,
    required this.accentGradient,
    required this.goldGradientStops,
    required this.goldGradientPositions,
    required this.categoryColors,
    this.blurSigma,
    this.glassTint,
    this.glassBorderOpacity,
    required this.cinematicPrimary,
    required this.cinematicAccent,
    this.cinematicGradient,
    this.spacingScale = 1.0,
    this.radiusScale = 1.0,
    required this.statusBarColor,
    required this.statusBarIconBrightness,
    required this.navigationBarColor,
    required this.navigationBarIconBrightness,
    required this.cardBorderColor,
    required this.shimmerColor,
    required this.successColor,
    required this.warningColor,
    required this.infoColor,
  });

  /// Convenience: build a LinearGradient from the gold stops.
  LinearGradient get goldGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: goldGradientStops,
        stops: goldGradientPositions,
      );

  /// Convenience: build a gold gradient in any direction.
  LinearGradient goldGradientDirectional({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) =>
      LinearGradient(
        begin: begin,
        end: end,
        colors: goldGradientStops,
        stops: goldGradientPositions,
      );

  @override
  BCThemeExtension copyWith({
    LinearGradient? primaryGradient,
    LinearGradient? accentGradient,
    List<Color>? goldGradientStops,
    List<double>? goldGradientPositions,
    List<Color>? categoryColors,
    double? blurSigma,
    Color? glassTint,
    double? glassBorderOpacity,
    Color? cinematicPrimary,
    Color? cinematicAccent,
    List<Color>? cinematicGradient,
    double? spacingScale,
    double? radiusScale,
    Color? statusBarColor,
    Brightness? statusBarIconBrightness,
    Color? navigationBarColor,
    Brightness? navigationBarIconBrightness,
    Color? cardBorderColor,
    Color? shimmerColor,
    Color? successColor,
    Color? warningColor,
    Color? infoColor,
  }) {
    return BCThemeExtension(
      primaryGradient: primaryGradient ?? this.primaryGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      goldGradientStops: goldGradientStops ?? this.goldGradientStops,
      goldGradientPositions: goldGradientPositions ?? this.goldGradientPositions,
      categoryColors: categoryColors ?? this.categoryColors,
      blurSigma: blurSigma ?? this.blurSigma,
      glassTint: glassTint ?? this.glassTint,
      glassBorderOpacity: glassBorderOpacity ?? this.glassBorderOpacity,
      cinematicPrimary: cinematicPrimary ?? this.cinematicPrimary,
      cinematicAccent: cinematicAccent ?? this.cinematicAccent,
      cinematicGradient: cinematicGradient ?? this.cinematicGradient,
      spacingScale: spacingScale ?? this.spacingScale,
      radiusScale: radiusScale ?? this.radiusScale,
      statusBarColor: statusBarColor ?? this.statusBarColor,
      statusBarIconBrightness: statusBarIconBrightness ?? this.statusBarIconBrightness,
      navigationBarColor: navigationBarColor ?? this.navigationBarColor,
      navigationBarIconBrightness: navigationBarIconBrightness ?? this.navigationBarIconBrightness,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      shimmerColor: shimmerColor ?? this.shimmerColor,
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      infoColor: infoColor ?? this.infoColor,
    );
  }

  @override
  BCThemeExtension lerp(covariant BCThemeExtension? other, double t) {
    if (other == null) return this;
    return BCThemeExtension(
      primaryGradient: t < 0.5 ? primaryGradient : other.primaryGradient,
      accentGradient: t < 0.5 ? accentGradient : other.accentGradient,
      goldGradientStops: t < 0.5 ? goldGradientStops : other.goldGradientStops,
      goldGradientPositions: t < 0.5 ? goldGradientPositions : other.goldGradientPositions,
      categoryColors: t < 0.5 ? categoryColors : other.categoryColors,
      blurSigma: t < 0.5 ? blurSigma : other.blurSigma,
      glassTint: Color.lerp(glassTint, other.glassTint, t),
      glassBorderOpacity: t < 0.5 ? glassBorderOpacity : other.glassBorderOpacity,
      cinematicPrimary: Color.lerp(cinematicPrimary, other.cinematicPrimary, t)!,
      cinematicAccent: Color.lerp(cinematicAccent, other.cinematicAccent, t)!,
      cinematicGradient: t < 0.5 ? cinematicGradient : other.cinematicGradient,
      spacingScale: spacingScale + (other.spacingScale - spacingScale) * t,
      radiusScale: radiusScale + (other.radiusScale - radiusScale) * t,
      statusBarColor: Color.lerp(statusBarColor, other.statusBarColor, t)!,
      statusBarIconBrightness: t < 0.5 ? statusBarIconBrightness : other.statusBarIconBrightness,
      navigationBarColor: Color.lerp(navigationBarColor, other.navigationBarColor, t)!,
      navigationBarIconBrightness: t < 0.5 ? navigationBarIconBrightness : other.navigationBarIconBrightness,
      cardBorderColor: Color.lerp(cardBorderColor, other.cardBorderColor, t)!,
      shimmerColor: Color.lerp(shimmerColor, other.shimmerColor, t)!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
    );
  }
}
```

**Step 2: Create `lib/config/palettes.dart` with the BCPalette class and Rose & Gold definition**

This file defines the `BCPalette` data class and all 7 palette instances. Start with Rose & Gold only — other palettes added in Task 5.

```dart
import 'package:flutter/material.dart';

/// Immutable color palette definition for a theme.
class BCPalette {
  final String id;
  final String nameEs;
  final String nameEn;
  final Brightness brightness;

  // Core ColorScheme
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color surface;
  final Color onSurface;
  final Color scaffoldBackground;
  final Color error;
  final Color onError;

  // Extended
  final Color cardColor;
  final Color cardBorderColor;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color shimmerColor;

  // Status
  final Color success;
  final Color warning;
  final Color info;

  // Gradients
  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final List<Color> goldGradientStops;
  final List<double> goldGradientPositions;

  // Category colors (8 entries matching allCategories order)
  final List<Color> categoryColors;

  // Typography
  final String headingFont;
  final String bodyFont;

  // Scale factors
  final double spacingScale;
  final double radiusScale;

  // Glass morphism
  final double? blurSigma;
  final Color? glassTint;
  final double? glassBorderOpacity;

  // CinematicQuestionText
  final Color cinematicPrimary;
  final Color cinematicAccent;
  final List<Color>? cinematicGradient;

  // System UI
  final Color statusBarColor;
  final Brightness statusBarIconBrightness;
  final Color navigationBarColor;
  final Brightness navigationBarIconBrightness;

  const BCPalette({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.surface,
    required this.onSurface,
    required this.scaffoldBackground,
    required this.error,
    required this.onError,
    required this.cardColor,
    required this.cardBorderColor,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.shimmerColor,
    required this.success,
    required this.warning,
    required this.info,
    required this.primaryGradient,
    required this.accentGradient,
    required this.goldGradientStops,
    required this.goldGradientPositions,
    required this.categoryColors,
    this.headingFont = 'Poppins',
    this.bodyFont = 'Nunito',
    this.spacingScale = 1.0,
    this.radiusScale = 1.0,
    this.blurSigma,
    this.glassTint,
    this.glassBorderOpacity,
    required this.cinematicPrimary,
    required this.cinematicAccent,
    this.cinematicGradient,
    required this.statusBarColor,
    required this.statusBarIconBrightness,
    required this.navigationBarColor,
    required this.navigationBarIconBrightness,
  });
}

// ─── Shared constants ──────────────────────────────────────────────────────

/// The canonical 13-stop metallic gold gradient.
const kGoldStops = [
  Color(0xFF8B6914),
  Color(0xFFD4AF37),
  Color(0xFFFFF8DC),
  Color(0xFFFFD700),
  Color(0xFFC19A26),
  Color(0xFFF5D547),
  Color(0xFFFFFFE0),
  Color(0xFFD4AF37),
  Color(0xFFA67C00),
  Color(0xFFCDAD38),
  Color(0xFFFFF8DC),
  Color(0xFFB8860B),
  Color(0xFF8B6914),
];

const kGoldPositions = [
  0.0, 0.08, 0.15, 0.25, 0.35, 0.45, 0.50, 0.58, 0.68, 0.78, 0.85, 0.93, 1.0
];

/// WhatsApp brand colors — NOT themed, used as app-level constants.
const kWhatsAppGreen = Color(0xFF25D366);
const kWhatsAppDarkGreen = Color(0xFF075E54);

// ─── Palettes ──────────────────────────────────────────────────────────────

/// 1. Rose & Gold — FROZEN palette values. Do not change hex codes.
const roseGoldPalette = BCPalette(
  id: 'rose_gold',
  nameEs: 'Rosa y Oro',
  nameEn: 'Rose & Gold',
  brightness: Brightness.light,
  primary: Color(0xFFC2185B),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFFFFB300),
  onSecondary: Color(0xFF212121),
  surface: Color(0xFFFFF8F0),
  onSurface: Color(0xFF212121),
  scaffoldBackground: Color(0xFFFFFFFF),
  error: Color(0xFFD32F2F),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0xFFFFF8F0),
  cardBorderColor: Color(0xFFEEEEEE),
  divider: Color(0xFFEEEEEE),
  textPrimary: Color(0xFF212121),
  textSecondary: Color(0xFF757575),
  textHint: Color(0xFF9E9E9E),
  shimmerColor: Color(0xFFFFB300),
  success: Color(0xFF4CAF50),
  warning: Color(0xFFFFA000),
  info: Color(0xFF2196F3),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFC2185B), Color(0xFFD81B60)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFFFC107)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: kGoldStops,
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFE91E63), // nails
    Color(0xFF8D6E63), // hair
    Color(0xFF9C27B0), // lashes_brows
    Color(0xFFFF5252), // makeup
    Color(0xFF26A69A), // facial
    Color(0xFF5C6BC0), // body_spa
    Color(0xFFFFA726), // specialized
    Color(0xFF37474F), // barberia
  ],
  cinematicPrimary: Color(0xFFC2185B),
  cinematicAccent: Color(0xFFFFB300),
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  navigationBarColor: Color(0xFFFFFFFF),
  navigationBarIconBrightness: Brightness.dark,
);

// Palettes 2-7 will be added in Task 5.
// For now, export a map for the provider to use:
final allPalettes = <String, BCPalette>{
  roseGoldPalette.id: roseGoldPalette,
};
```

**Step 3: Verify it compiles**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/config/palettes.dart lib/config/theme_extension.dart`
Expected: No errors

**Step 4: Commit**

```bash
git add lib/config/palettes.dart lib/config/theme_extension.dart
git commit -m "feat(theme): add BCPalette class and BCThemeExtension with Rose & Gold palette"
```

---

## Task 2: Create theme factory — buildThemeFromPalette()

**Files:**
- Modify: `lib/config/theme.dart` (rewrite entirely)

**Step 1: Rewrite `lib/config/theme.dart`**

Replace the entire file. The factory function must produce **identical** ThemeData to the current `BeautyCitaTheme.lightTheme` when given `roseGoldPalette`.

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';
import 'palettes.dart';
import 'theme_extension.dart';

/// Builds a complete ThemeData from a BCPalette.
/// This is the SINGLE source of truth for all theme generation.
ThemeData buildThemeFromPalette(BCPalette palette) {
  final isLight = palette.brightness == Brightness.light;
  final base = isLight ? ThemeData.light() : ThemeData.dark();

  final colorScheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
    surface: palette.surface,
    onSurface: palette.onSurface,
    error: palette.error,
    onError: palette.onError,
  );

  // Scaled dimensions
  final s = palette.spacingScale;
  final r = palette.radiusScale;

  final headingColor = palette.textPrimary;
  final bodyColor = palette.textPrimary;
  final hintColor = palette.textSecondary;

  final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
    displayLarge: GoogleFonts.poppins(
      fontSize: 32, fontWeight: FontWeight.bold, color: headingColor, height: 1.2,
    ),
    displayMedium: GoogleFonts.poppins(
      fontSize: 28, fontWeight: FontWeight.bold, color: headingColor, height: 1.2,
    ),
    displaySmall: GoogleFonts.poppins(
      fontSize: 24, fontWeight: FontWeight.w600, color: headingColor, height: 1.3,
    ),
    headlineLarge: GoogleFonts.poppins(
      fontSize: 22, fontWeight: FontWeight.w600, color: headingColor, height: 1.3,
    ),
    headlineMedium: GoogleFonts.poppins(
      fontSize: 20, fontWeight: FontWeight.w600, color: headingColor, height: 1.3,
    ),
    headlineSmall: GoogleFonts.poppins(
      fontSize: 18, fontWeight: FontWeight.w600, color: headingColor, height: 1.4,
    ),
    titleLarge: GoogleFonts.nunito(
      fontSize: 18, fontWeight: FontWeight.w600, color: bodyColor, height: 1.4,
    ),
    titleMedium: GoogleFonts.nunito(
      fontSize: 16, fontWeight: FontWeight.w600, color: bodyColor, height: 1.4,
    ),
    titleSmall: GoogleFonts.nunito(
      fontSize: 14, fontWeight: FontWeight.w600, color: bodyColor, height: 1.4,
    ),
    bodyLarge: GoogleFonts.nunito(
      fontSize: 16, fontWeight: FontWeight.w400, color: bodyColor, height: 1.5,
    ),
    bodyMedium: GoogleFonts.nunito(
      fontSize: 14, fontWeight: FontWeight.w400, color: bodyColor, height: 1.5,
    ),
    bodySmall: GoogleFonts.nunito(
      fontSize: 12, fontWeight: FontWeight.w400, color: hintColor, height: 1.5,
    ),
    labelLarge: GoogleFonts.nunito(
      fontSize: 16, fontWeight: FontWeight.w600, color: bodyColor, height: 1.2,
    ),
    labelMedium: GoogleFonts.nunito(
      fontSize: 14, fontWeight: FontWeight.w500, color: bodyColor, height: 1.2,
    ),
    labelSmall: GoogleFonts.nunito(
      fontSize: 12, fontWeight: FontWeight.w500, color: hintColor, height: 1.2,
    ),
  );

  final rMD = AppConstants.radiusMD * r;
  final rLG = AppConstants.radiusLG * r;
  final rXL = AppConstants.radiusXL * r;

  final ext = BCThemeExtension(
    primaryGradient: palette.primaryGradient,
    accentGradient: palette.accentGradient,
    goldGradientStops: palette.goldGradientStops,
    goldGradientPositions: palette.goldGradientPositions,
    categoryColors: palette.categoryColors,
    blurSigma: palette.blurSigma,
    glassTint: palette.glassTint,
    glassBorderOpacity: palette.glassBorderOpacity,
    cinematicPrimary: palette.cinematicPrimary,
    cinematicAccent: palette.cinematicAccent,
    cinematicGradient: palette.cinematicGradient,
    spacingScale: palette.spacingScale,
    radiusScale: palette.radiusScale,
    statusBarColor: palette.statusBarColor,
    statusBarIconBrightness: palette.statusBarIconBrightness,
    navigationBarColor: palette.navigationBarColor,
    navigationBarIconBrightness: palette.navigationBarIconBrightness,
    cardBorderColor: palette.cardBorderColor,
    shimmerColor: palette.shimmerColor,
    successColor: palette.success,
    warningColor: palette.warning,
    infoColor: palette.info,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.scaffoldBackground,
    extensions: [ext],

    textTheme: textTheme,

    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: palette.scaffoldBackground,
      foregroundColor: palette.textPrimary,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20, fontWeight: FontWeight.w600, color: palette.textPrimary,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary, size: 24),
    ),

    cardTheme: CardThemeData(
      elevation: AppConstants.elevationLow,
      color: palette.cardColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rMD),
      ),
      margin: EdgeInsets.all(AppConstants.paddingMD * s),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: AppConstants.elevationMedium,
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        minimumSize: const Size(double.infinity, AppConstants.minTouchHeight),
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.paddingXL * s,
          vertical: AppConstants.paddingMD * s,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLG),
        ),
        textStyle: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primary,
        minimumSize: const Size(double.infinity, AppConstants.minTouchHeight),
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.paddingXL * s,
          vertical: AppConstants.paddingMD * s,
        ),
        side: BorderSide(color: palette.primary, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLG),
        ),
        textStyle: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        minimumSize: const Size(AppConstants.minTouchHeight, AppConstants.minTouchHeight),
        padding: EdgeInsets.symmetric(
          horizontal: AppConstants.paddingLG * s,
          vertical: AppConstants.paddingMD * s,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rMD),
        ),
        textStyle: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w600,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLG * s,
        vertical: AppConstants.paddingMD * s,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide(color: palette.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide(color: palette.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rMD),
        borderSide: BorderSide(color: palette.error, width: 2),
      ),
      labelStyle: GoogleFonts.nunito(fontSize: 16, color: palette.textSecondary),
      hintStyle: GoogleFonts.nunito(fontSize: 16, color: palette.textSecondary),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      elevation: AppConstants.elevationHigh,
      backgroundColor: palette.scaffoldBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(rXL)),
      ),
      modalBackgroundColor: palette.scaffoldBackground,
      modalElevation: AppConstants.elevationHigh,
    ),

    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: AppConstants.paddingMD * s,
    ),

    iconTheme: IconThemeData(color: palette.textPrimary, size: 24),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: AppConstants.elevationMedium,
      backgroundColor: palette.secondary,
      foregroundColor: palette.onSecondary,
      shape: const CircleBorder(),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: palette.surface,
      deleteIconColor: palette.textPrimary,
      disabledColor: palette.divider,
      selectedColor: palette.primary,
      secondarySelectedColor: palette.secondary,
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD * s,
        vertical: AppConstants.paddingSM * s,
      ),
      labelStyle: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary,
      ),
      secondaryLabelStyle: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rMD),
      ),
    ),
  );
}

// ─── Legacy static access (for migration period) ─────────────────────────
// After all files are converted, this class can be deleted.
// During migration, screens can use EITHER the old statics OR Theme.of(context).
class BeautyCitaTheme {
  // Brand Colors — point at Rose & Gold palette
  static const Color primaryRose = Color(0xFFC2185B);
  static const Color secondaryGold = Color(0xFFFFB300);
  static const Color surfaceCream = Color(0xFFFFF8F0);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
  static const Color dividerLight = Color(0xFFEEEEEE);

  static const Color primaryRoseLight = Color(0xFFFCE4EC);
  static const Color secondaryGoldLight = Color(0xFFFFF8E1);
  static const Color accentTeal = Color(0xFF00897B);
  static const Color accentTealLight = Color(0xFFE0F2F1);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRose, Color(0xFFD81B60)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondaryGold, Color(0xFFFFC107)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Spacing/radius/elevation — still delegate to AppConstants
  static const double radiusSmall = AppConstants.radiusSM;
  static const double radiusMedium = AppConstants.radiusMD;
  static const double radiusLarge = AppConstants.radiusLG;
  static const double radiusXL = AppConstants.radiusXL;
  static const double spaceXS = AppConstants.paddingXS;
  static const double spaceSM = AppConstants.paddingSM;
  static const double spaceMD = AppConstants.paddingMD;
  static const double spaceLG = AppConstants.paddingLG;
  static const double spaceXL = AppConstants.paddingXL;
  static const double spaceXXL = AppConstants.paddingXXL;
  static const double minTouchTarget = AppConstants.minTouchHeight;
  static const double largeTouchTarget = AppConstants.largeTouchHeight;
  static const double elevationCard = AppConstants.elevationLow;
  static const double elevationButton = AppConstants.elevationMedium;
  static const double elevationSheet = AppConstants.elevationHigh;

  /// Legacy getter — returns Rose & Gold theme.
  /// New code should use buildThemeFromPalette() via themeProvider.
  static ThemeData get lightTheme => buildThemeFromPalette(roseGoldPalette);
}
```

**Step 2: Verify it compiles and the app builds**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/config/theme.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/config/theme.dart
git commit -m "feat(theme): rewrite theme.dart with buildThemeFromPalette() factory"
```

---

## Task 3: Create theme provider (Riverpod + SharedPreferences)

**Files:**
- Create: `lib/providers/theme_provider.dart`

**Step 1: Create `lib/providers/theme_provider.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/palettes.dart';
import '../config/theme.dart';
import '../config/theme_extension.dart';

const _prefKey = 'selected_theme';

class ThemeState {
  final String themeId;
  final ThemeData themeData;
  final BCPalette palette;

  const ThemeState({
    required this.themeId,
    required this.themeData,
    required this.palette,
  });
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier()
      : super(ThemeState(
          themeId: roseGoldPalette.id,
          themeData: buildThemeFromPalette(roseGoldPalette),
          palette: roseGoldPalette,
        )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefKey);
    if (savedId != null && allPalettes.containsKey(savedId)) {
      _applyPalette(allPalettes[savedId]!);
    }
  }

  Future<void> setTheme(String themeId) async {
    final palette = allPalettes[themeId];
    if (palette == null) return;
    _applyPalette(palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, themeId);
  }

  void _applyPalette(BCPalette palette) {
    final themeData = buildThemeFromPalette(palette);
    state = ThemeState(
      themeId: palette.id,
      themeData: themeData,
      palette: palette,
    );
    // Update system UI chrome
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: palette.statusBarColor,
      statusBarIconBrightness: palette.statusBarIconBrightness,
      statusBarBrightness: palette.brightness == Brightness.light
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: palette.navigationBarColor,
      systemNavigationBarIconBrightness: palette.navigationBarIconBrightness,
    ));
  }

  Future<void> resetToDefault() async {
    await setTheme(roseGoldPalette.id);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

/// Convenience: access current palette from anywhere.
final paletteProvider = Provider<BCPalette>((ref) {
  return ref.watch(themeProvider).palette;
});

/// Convenience: access BCThemeExtension directly.
final themeExtProvider = Provider<BCThemeExtension>((ref) {
  return ref.watch(themeProvider).themeData.extension<BCThemeExtension>()!;
});
```

**Step 2: Verify it compiles**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/providers/theme_provider.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/providers/theme_provider.dart
git commit -m "feat(theme): add ThemeNotifier provider with SharedPreferences persistence"
```

---

## Task 4: Wire theme provider into main.dart

**Files:**
- Modify: `lib/main.dart`

**Step 1: Update `main.dart` to use themeProvider**

Changes needed:
1. Import theme_provider
2. Make `BeautyCitaApp.build()` use `ref.watch(themeProvider)` for `theme` and `darkTheme`
3. Remove hardcoded `SystemChrome.setSystemUIOverlayStyle` (now handled by ThemeNotifier)
4. Remove `BeautyCitaTheme.lightTheme` import usage

In `main()`, remove the hardcoded `SystemChrome.setSystemUIOverlayStyle(...)` block (lines 40-48 of current main.dart). The ThemeNotifier sets this reactively.

In `_BeautyCitaAppState.build()`, change:

```dart
// OLD:
theme: BeautyCitaTheme.lightTheme,

// NEW:
final themeState = ref.watch(themeProvider);
// ...
theme: themeState.themeData,
darkTheme: themeState.palette.brightness == Brightness.dark ? themeState.themeData : null,
themeMode: themeState.palette.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
```

Add import: `import 'package:beautycita/providers/theme_provider.dart';`

**Step 2: Verify app builds and launches**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter build apk --release --no-tree-shake-icons --target-platform android-arm64`
Expected: BUILD SUCCESSFUL. App should look identical (Rose & Gold is default).

**Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat(theme): wire themeProvider into MaterialApp"
```

---

## Task 5: Define all 7 palettes

**Files:**
- Modify: `lib/config/palettes.dart` (add 6 more palettes to the file)

**Step 1: Add Black & Gold palette**

After `roseGoldPalette`, add:

```dart
const blackGoldPalette = BCPalette(
  id: 'black_gold',
  nameEs: 'Negro y Oro',
  nameEn: 'Black & Gold',
  brightness: Brightness.dark,
  primary: Color(0xFFFFB300),
  onPrimary: Color(0xFF0A0A0F),
  secondary: Color(0xFFD4AF37),
  onSecondary: Color(0xFF0A0A0F),
  surface: Color(0xFF1A1A2E),
  onSurface: Color(0xFFF5F5F5),
  scaffoldBackground: Color(0xFF0A0A0F),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFF0A0A0F),
  cardColor: Color(0xFF1A1A2E),
  cardBorderColor: Color(0xFF3D3522),
  divider: Color(0xFF2A2A3E),
  textPrimary: Color(0xFFF5F5F5),
  textSecondary: Color(0xFFB0B0B0),
  textHint: Color(0xFF808080),
  shimmerColor: Color(0xFFFFD700),
  success: Color(0xFF69F0AE),
  warning: Color(0xFFFFD740),
  info: Color(0xFF40C4FF),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFD4AF37)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFF8B6914)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: kGoldStops,
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFFF6B9D), Color(0xFFC19A6B), Color(0xFFCE93D8),
    Color(0xFFFF8A80), Color(0xFF80CBC4), Color(0xFF9FA8DA),
    Color(0xFFFFCC80), Color(0xFF90A4AE),
  ],
  cinematicPrimary: Color(0xFFFFB300),
  cinematicAccent: Color(0xFFD4AF37),
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  navigationBarColor: Color(0xFF0A0A0F),
  navigationBarIconBrightness: Brightness.light,
);
```

**Step 2: Add Glassmorphism palette**

```dart
const glassmorphismPalette = BCPalette(
  id: 'glass',
  nameEs: 'Cristal',
  nameEn: 'Glassmorphism',
  brightness: Brightness.dark,
  primary: Color(0xFFEC4899),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF9333EA),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFF1A1A2E),
  onSurface: Color(0xFFFFFFFF),
  scaffoldBackground: Color(0xFF0A0A1A),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0x14FFFFFF), // 8% white
  cardBorderColor: Color(0x26FFFFFF), // 15% white
  divider: Color(0x1AFFFFFF), // 10% white
  textPrimary: Color(0xFFFFFFFF),
  textSecondary: Color(0xB3FFFFFF), // 70% white
  textHint: Color(0x80FFFFFF), // 50% white
  shimmerColor: Color(0xFFEC4899),
  success: Color(0xFF34D399),
  warning: Color(0xFFFBBF24),
  info: Color(0xFF60A5FA),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFF9333EA), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: kGoldStops,
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFEC4899), Color(0xFFA78BFA), Color(0xFF818CF8),
    Color(0xFFF472B6), Color(0xFF34D399), Color(0xFF60A5FA),
    Color(0xFFFBBF24), Color(0xFF94A3B8),
  ],
  blurSigma: 20,
  glassTint: Color(0x14FFFFFF),
  glassBorderOpacity: 0.15,
  cinematicPrimary: Color(0xFFEC4899),
  cinematicAccent: Color(0xFF9333EA),
  cinematicGradient: [Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF3B82F6)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  navigationBarColor: Color(0xFF0A0A1A),
  navigationBarIconBrightness: Brightness.light,
);
```

**Step 3: Add Midnight Orchid palette**

```dart
const midnightOrchidPalette = BCPalette(
  id: 'midnight_orchid',
  nameEs: 'Orquidea Nocturna',
  nameEn: 'Midnight Orchid',
  brightness: Brightness.dark,
  primary: Color(0xFFB388FF),
  onPrimary: Color(0xFF0D0015),
  secondary: Color(0xFFE040FB),
  onSecondary: Color(0xFF0D0015),
  surface: Color(0xFF1A0A2E),
  onSurface: Color(0xFFF3E5F5),
  scaffoldBackground: Color(0xFF0D0015),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFF0D0015),
  cardColor: Color(0xFF1A0A2E),
  cardBorderColor: Color(0xFF3D1A6E),
  divider: Color(0xFF2A1545),
  textPrimary: Color(0xFFF3E5F5),
  textSecondary: Color(0xFFCE93D8),
  textHint: Color(0xFF9C27B0),
  shimmerColor: Color(0xFFE040FB),
  success: Color(0xFF69F0AE),
  warning: Color(0xFFFFD740),
  info: Color(0xFFB388FF),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFB388FF), Color(0xFFE040FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFE040FB), Color(0xFFFF80AB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: [
    Color(0xFF4A148C), Color(0xFFB388FF), Color(0xFFF3E5F5),
    Color(0xFFE040FB), Color(0xFF9C27B0), Color(0xFFCE93D8),
    Color(0xFFF3E5F5), Color(0xFFB388FF), Color(0xFF7B1FA2),
    Color(0xFFBA68C8), Color(0xFFF3E5F5), Color(0xFF8E24AA),
    Color(0xFF4A148C),
  ],
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFE040FB), Color(0xFFB388FF), Color(0xFFCE93D8),
    Color(0xFFFF80AB), Color(0xFF69F0AE), Color(0xFF82B1FF),
    Color(0xFFFFD740), Color(0xFF90A4AE),
  ],
  cinematicPrimary: Color(0xFFB388FF),
  cinematicAccent: Color(0xFFE040FB),
  cinematicGradient: [Color(0xFF7B1FA2), Color(0xFFB388FF), Color(0xFFE040FB), Color(0xFFFF80AB)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  navigationBarColor: Color(0xFF0D0015),
  navigationBarIconBrightness: Brightness.light,
);
```

**Step 4: Add Ocean Noir palette**

```dart
const oceanNoirPalette = BCPalette(
  id: 'ocean_noir',
  nameEs: 'Oceano Oscuro',
  nameEn: 'Ocean Noir',
  brightness: Brightness.dark,
  primary: Color(0xFF00E5FF),
  onPrimary: Color(0xFF0A1628),
  secondary: Color(0xFF1DE9B6),
  onSecondary: Color(0xFF0A1628),
  surface: Color(0xFF0D2137),
  onSurface: Color(0xFFE0F7FA),
  scaffoldBackground: Color(0xFF0A1628),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFF0A1628),
  cardColor: Color(0xFF0D2137),
  cardBorderColor: Color(0xFF0D3B54),
  divider: Color(0xFF163650),
  textPrimary: Color(0xFFE0F7FA),
  textSecondary: Color(0xFF80DEEA),
  textHint: Color(0xFF4DD0E1),
  shimmerColor: Color(0xFF00E5FF),
  success: Color(0xFF1DE9B6),
  warning: Color(0xFFFFD740),
  info: Color(0xFF00E5FF),
  primaryGradient: LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF1DE9B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFF1DE9B6), Color(0xFF00B8D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: [
    Color(0xFF004D6E), Color(0xFF00ACC1), Color(0xFFE0F7FA),
    Color(0xFF00E5FF), Color(0xFF0097A7), Color(0xFF4DD0E1),
    Color(0xFFE0F7FA), Color(0xFF00ACC1), Color(0xFF006978),
    Color(0xFF26C6DA), Color(0xFFE0F7FA), Color(0xFF00838F),
    Color(0xFF004D6E),
  ],
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFFF6B9D), Color(0xFF4DD0E1), Color(0xFFCE93D8),
    Color(0xFFFF8A80), Color(0xFF1DE9B6), Color(0xFF448AFF),
    Color(0xFFFFD740), Color(0xFF90A4AE),
  ],
  cinematicPrimary: Color(0xFF00E5FF),
  cinematicAccent: Color(0xFF1DE9B6),
  cinematicGradient: [Color(0xFF006978), Color(0xFF00E5FF), Color(0xFF1DE9B6), Color(0xFFE0F7FA)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  navigationBarColor: Color(0xFF0A1628),
  navigationBarIconBrightness: Brightness.light,
);
```

**Step 5: Add Cherry Blossom palette**

```dart
const cherryBlossomPalette = BCPalette(
  id: 'cherry_blossom',
  nameEs: 'Flor de Cerezo',
  nameEn: 'Cherry Blossom',
  brightness: Brightness.light,
  primary: Color(0xFFFF6B9D),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFFC084FC),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF2D1B36),
  scaffoldBackground: Color(0xFFFFF5F7),
  error: Color(0xFFE53E3E),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0xFFFFFFFF),
  cardBorderColor: Color(0xFFFCE4EC),
  divider: Color(0xFFF8BBD0),
  textPrimary: Color(0xFF2D1B36),
  textSecondary: Color(0xFF7C5295),
  textHint: Color(0xFFB39DDB),
  shimmerColor: Color(0xFFC084FC),
  success: Color(0xFF34D399),
  warning: Color(0xFFFBBF24),
  info: Color(0xFF818CF8),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFC084FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFC084FC), Color(0xFF818CF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: [
    Color(0xFFA64D79), Color(0xFFFF6B9D), Color(0xFFFFF5F7),
    Color(0xFFC084FC), Color(0xFFD946EF), Color(0xFFF0ABFC),
    Color(0xFFFFF5F7), Color(0xFFFF6B9D), Color(0xFFA855F7),
    Color(0xFFE879F9), Color(0xFFFFF5F7), Color(0xFFBE185D),
    Color(0xFFA64D79),
  ],
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFFF6B9D), Color(0xFFD946EF), Color(0xFFC084FC),
    Color(0xFFFB7185), Color(0xFF34D399), Color(0xFF818CF8),
    Color(0xFFFBBF24), Color(0xFF94A3B8),
  ],
  cinematicPrimary: Color(0xFFFF6B9D),
  cinematicAccent: Color(0xFFC084FC),
  cinematicGradient: [Color(0xFFBE185D), Color(0xFFFF6B9D), Color(0xFFC084FC), Color(0xFFFFF5F7)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  navigationBarColor: Color(0xFFFFF5F7),
  navigationBarIconBrightness: Brightness.dark,
);
```

**Step 6: Add Emerald Luxe palette**

```dart
const emeraldLuxePalette = BCPalette(
  id: 'emerald_luxe',
  nameEs: 'Esmeralda Lujosa',
  nameEn: 'Emerald Luxe',
  brightness: Brightness.dark,
  primary: Color(0xFF00E676),
  onPrimary: Color(0xFF0A1F0A),
  secondary: Color(0xFFFFD700),
  onSecondary: Color(0xFF0A1F0A),
  surface: Color(0xFF0F2A0F),
  onSurface: Color(0xFFE8F5E9),
  scaffoldBackground: Color(0xFF0A1F0A),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFF0A1F0A),
  cardColor: Color(0xFF0F2A0F),
  cardBorderColor: Color(0xFF1B5E20),
  divider: Color(0xFF1B3A1B),
  textPrimary: Color(0xFFE8F5E9),
  textSecondary: Color(0xFFA5D6A7),
  textHint: Color(0xFF66BB6A),
  shimmerColor: Color(0xFFFFD700),
  success: Color(0xFF00E676),
  warning: Color(0xFFFFD740),
  info: Color(0xFF40C4FF),
  primaryGradient: LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: kGoldStops, // Real gold gradient — emerald meets gold
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFFF6B9D), Color(0xFFA5D6A7), Color(0xFFCE93D8),
    Color(0xFFFF8A80), Color(0xFF00E676), Color(0xFF40C4FF),
    Color(0xFFFFD740), Color(0xFF90A4AE),
  ],
  cinematicPrimary: Color(0xFF00E676),
  cinematicAccent: Color(0xFFFFD700),
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  navigationBarColor: Color(0xFF0A1F0A),
  navigationBarIconBrightness: Brightness.light,
);
```

**Step 7: Update allPalettes map**

```dart
final allPalettes = <String, BCPalette>{
  roseGoldPalette.id: roseGoldPalette,
  blackGoldPalette.id: blackGoldPalette,
  glassmorphismPalette.id: glassmorphismPalette,
  midnightOrchidPalette.id: midnightOrchidPalette,
  oceanNoirPalette.id: oceanNoirPalette,
  cherryBlossomPalette.id: cherryBlossomPalette,
  emeraldLuxePalette.id: emeraldLuxePalette,
};
```

**Step 8: Verify it compiles**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/config/palettes.dart`
Expected: No errors

**Step 9: Commit**

```bash
git add lib/config/palettes.dart
git commit -m "feat(theme): define all 7 theme palettes"
```

---

## Task 6: Create Appearance screen and add route

**Files:**
- Create: `lib/screens/appearance_screen.dart`
- Modify: `lib/screens/settings_screen.dart` (add Apariencia tile)
- Modify: `lib/config/routes.dart` (add route)

**Step 1: Create `lib/screens/appearance_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/palettes.dart';
import '../config/theme_extension.dart';
import '../providers/theme_provider.dart';
import '../config/constants.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeId = ref.watch(themeProvider).themeId;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          Text(
            'Elige tu estilo',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppConstants.paddingMD),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: allPalettes.length,
            itemBuilder: (context, index) {
              final palette = allPalettes.values.elementAt(index);
              final isSelected = palette.id == currentThemeId;
              return _ThemePreviewCard(
                palette: palette,
                isSelected: isSelected,
                onTap: () => ref.read(themeProvider.notifier).setTheme(palette.id),
              );
            },
          ),
          const SizedBox(height: AppConstants.paddingLG),
          if (currentThemeId != roseGoldPalette.id)
            Center(
              child: TextButton(
                onPressed: () => ref.read(themeProvider.notifier).resetToDefault(),
                child: Text(
                  'Restablecer tema original',
                  style: TextStyle(color: cs.primary),
                ),
              ),
            ),
          const SizedBox(height: AppConstants.paddingLG),
        ],
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final BCPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = palette.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: isSelected ? palette.primary : palette.divider,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD - 1),
          child: Column(
            children: [
              // Mini phone mockup
              Expanded(
                child: Container(
                  color: palette.scaffoldBackground,
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      // Mini header bar
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: palette.primaryGradient,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Mini cards
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: palette.cardColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: palette.cardBorderColor,
                                    width: 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: palette.categoryColors.isNotEmpty
                                          ? palette.categoryColors[0]
                                          : palette.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: palette.cardColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: palette.cardBorderColor,
                                    width: 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: palette.categoryColors.length > 1
                                          ? palette.categoryColors[1]
                                          : palette.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Mini button
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 4,
                            decoration: BoxDecoration(
                              color: palette.onPrimary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Label
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: isSelected ? palette.primary : palette.scaffoldBackground,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: palette.onPrimary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      palette.nameEs,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isSelected
                                ? palette.onPrimary
                                : isDark
                                    ? palette.textPrimary
                                    : palette.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Add route in `lib/config/routes.dart`**

Add import at top: `import 'package:beautycita/screens/appearance_screen.dart';`

Add route constant: `static const String appearance = '/settings/appearance';`

Add GoRoute after the `security` route (before `],` on the routes list):

```dart
GoRoute(
  path: '/settings/appearance',
  name: 'appearance',
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: const AppearanceScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOutCubic));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  ),
),
```

**Step 3: Add Apariencia tile to settings_screen.dart**

In `settings_screen.dart`, after the "Metodos de pago" tile and before "Seguridad y cuenta":

```dart
SettingsTile(
  icon: Icons.palette_outlined,
  label: 'Apariencia',
  onTap: () => context.push('/settings/appearance'),
),
```

**Step 4: Verify it compiles and the route works**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/appearance_screen.dart lib/config/routes.dart lib/screens/settings_screen.dart`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/screens/appearance_screen.dart lib/config/routes.dart lib/screens/settings_screen.dart
git commit -m "feat(theme): add Appearance screen with theme picker grid"
```

---

## Task 7: Convert core widgets to use theme tokens

**Files:**
- Modify: `lib/widgets/cinematic_question_text.dart`
- Modify: `lib/widgets/bc_button.dart`
- Modify: `lib/widgets/bc_loading.dart`
- Modify: `lib/widgets/settings_widgets.dart`

**Step 1: Convert `cinematic_question_text.dart`**

Replace the import of `../config/theme.dart` with `../config/theme_extension.dart`.

Replace the static `_goldGradient` definition (lines 193-212) with a method that reads from context:

The widget already takes `primaryColor` and `accentColor` as parameters with defaults. Change the defaults to read from the extension at build time instead. Since these are constructor defaults, we can't use context there. Instead, make them nullable and resolve at build time:

```dart
// Change constructor defaults:
this.primaryColor, // was: = BeautyCitaTheme.primaryRose
this.accentColor,  // was: = BeautyCitaTheme.secondaryGold
```

In `_CinematicContent`, replace the static `_goldGradient` with a method:

```dart
LinearGradient _getGradient(BuildContext context) {
  final ext = Theme.of(context).extension<BCThemeExtension>();
  if (ext?.cinematicGradient != null) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: ext!.cinematicGradient!,
    );
  }
  final stops = ext?.goldGradientStops ?? kGoldStops;
  final positions = ext?.goldGradientPositions ?? kGoldPositions;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: stops,
    stops: positions,
  );
}
```

Update `_buildCharacterRow` to pass context and use `_getGradient(context)` instead of `_goldGradient`.

Also resolve null primaryColor/accentColor:
```dart
final resolvedPrimary = primaryColor ?? Theme.of(context).extension<BCThemeExtension>()?.cinematicPrimary ?? Theme.of(context).colorScheme.primary;
final resolvedAccent = accentColor ?? Theme.of(context).extension<BCThemeExtension>()?.cinematicAccent ?? Theme.of(context).colorScheme.secondary;
```

**Step 2: Convert `bc_button.dart`**

Replace all `BeautyCitaTheme.primaryRose` with `Theme.of(context).colorScheme.primary`.
Replace all `BeautyCitaTheme.secondaryGold` with `Theme.of(context).colorScheme.secondary`.
Replace all `BeautyCitaTheme.textDark` with `Theme.of(context).colorScheme.onSurface`.
Replace all `BeautyCitaTheme.textLight` with `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)`.
Replace `BeautyCitaTheme.primaryGradient` with `Theme.of(context).extension<BCThemeExtension>()!.primaryGradient`.
Replace `BeautyCitaTheme.accentGradient` with `Theme.of(context).extension<BCThemeExtension>()!.accentGradient`.

Import `../config/theme_extension.dart` instead of `../config/theme.dart`.

**Step 3: Convert `settings_widgets.dart`**

Replace `BeautyCitaTheme.textLight` with `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)`.
Replace `BeautyCitaTheme.primaryRose` with `Theme.of(context).colorScheme.primary`.
Replace `BeautyCitaTheme.spaceMD` with `AppConstants.paddingMD`.
Remove import of `../config/theme.dart`.

**Step 4: Convert `bc_loading.dart`**

Replace any `BeautyCitaTheme.*` references with `Theme.of(context).colorScheme.*` equivalents.

**Step 5: Verify it compiles**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/widgets/`
Expected: No errors

**Step 6: Commit**

```bash
git add lib/widgets/cinematic_question_text.dart lib/widgets/bc_button.dart lib/widgets/bc_loading.dart lib/widgets/settings_widgets.dart
git commit -m "refactor(theme): convert core widgets to use theme tokens"
```

---

## Task 8: Convert settings, profile, preferences, security screens

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/screens/profile_screen.dart`
- Modify: `lib/screens/preferences_screen.dart`
- Modify: `lib/screens/security_screen.dart`

**Conversion pattern for ALL screen files (apply to each):**

1. Replace `BeautyCitaTheme.primaryRose` → `Theme.of(context).colorScheme.primary`
2. Replace `BeautyCitaTheme.secondaryGold` → `Theme.of(context).colorScheme.secondary`
3. Replace `BeautyCitaTheme.surfaceCream` → `Theme.of(context).colorScheme.surface`
4. Replace `BeautyCitaTheme.backgroundWhite` → `Theme.of(context).scaffoldBackgroundColor`
5. Replace `BeautyCitaTheme.textDark` → `Theme.of(context).colorScheme.onSurface`
6. Replace `BeautyCitaTheme.textLight` → `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)` or `Theme.of(context).textTheme.bodySmall!.color!`
7. Replace `BeautyCitaTheme.dividerLight` → `Theme.of(context).dividerColor`
8. Replace `BeautyCitaTheme.primaryGradient` → `ext.primaryGradient` (where `final ext = Theme.of(context).extension<BCThemeExtension>()!;`)
9. Replace `BeautyCitaTheme.accentGradient` → `ext.accentGradient`
10. Replace any local `_goldGradient` definition (13-stop) → `ext.goldGradientDirectional()` or `ext.goldGradient`
11. Replace `BeautyCitaTheme.spaceXX` → `AppConstants.paddingXX` (they're already the same values)
12. Replace hardcoded `Color(0xFFC2185B)` → `Theme.of(context).colorScheme.primary`
13. Replace hardcoded `Color(0xFFFFB300)` → `Theme.of(context).colorScheme.secondary`

**For settings_screen.dart specifically:**

The file-local `_goldGradient` const must be replaced. Since it's used in `build()`, get it from the extension:

```dart
final ext = Theme.of(context).extension<BCThemeExtension>()!;
final goldGrad = ext.goldGradientDirectional();
```

Replace all 6 occurrences of `_goldGradient` in the file with `goldGrad`.

The `_GoldShimmerText` widget also needs access — pass the gradient as a parameter or have it read from context.

**Step 1: Convert each file** applying the pattern above.

**Step 2: Verify**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/settings_screen.dart lib/screens/profile_screen.dart lib/screens/preferences_screen.dart lib/screens/security_screen.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/settings_screen.dart lib/screens/profile_screen.dart lib/screens/preferences_screen.dart lib/screens/security_screen.dart
git commit -m "refactor(theme): convert settings/profile/preferences/security to theme tokens"
```

---

## Task 9: Convert booking flow screens

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/booking_flow_screen.dart`
- Modify: `lib/screens/follow_up_question_screen.dart`
- Modify: `lib/screens/subcategory_sheet.dart`
- Modify: `lib/screens/result_cards_screen.dart`
- Modify: `lib/screens/transport_selection.dart`
- Modify: `lib/screens/confirmation_screen.dart`
- Modify: `lib/screens/time_override_sheet.dart`

**Step 1: Apply the same conversion pattern from Task 8 to all files.**

Key notes per file:
- `result_cards_screen.dart`, `confirmation_screen.dart`, `transport_selection.dart` all have local `_goldGradient` const — replace with `ext.goldGradientDirectional()`
- `home_screen.dart` has category card colors — these come from `ext.categoryColors[index]`
- `follow_up_question_screen.dart` uses CinematicQuestionText (already converted in Task 7)

**Step 2: Verify**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/home_screen.dart lib/screens/booking_flow_screen.dart lib/screens/follow_up_question_screen.dart lib/screens/subcategory_sheet.dart lib/screens/result_cards_screen.dart lib/screens/transport_selection.dart lib/screens/confirmation_screen.dart lib/screens/time_override_sheet.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/home_screen.dart lib/screens/booking_flow_screen.dart lib/screens/follow_up_question_screen.dart lib/screens/subcategory_sheet.dart lib/screens/result_cards_screen.dart lib/screens/transport_selection.dart lib/screens/confirmation_screen.dart lib/screens/time_override_sheet.dart
git commit -m "refactor(theme): convert booking flow screens to theme tokens"
```

---

## Task 10: Convert booking detail, my bookings, booking screen

**Files:**
- Modify: `lib/screens/booking_screen.dart`
- Modify: `lib/screens/booking_detail_screen.dart`
- Modify: `lib/screens/my_bookings_screen.dart`

**Step 1: Apply conversion pattern.** `my_bookings_screen.dart` has TWO gold gradient definitions — remove both and use `ext`.

**Step 2: Verify**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/booking_screen.dart lib/screens/booking_detail_screen.dart lib/screens/my_bookings_screen.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/booking_screen.dart lib/screens/booking_detail_screen.dart lib/screens/my_bookings_screen.dart
git commit -m "refactor(theme): convert booking screens to theme tokens"
```

---

## Task 11: Convert provider, salon, and chat screens

**Files:**
- Modify: `lib/screens/provider_list_screen.dart`
- Modify: `lib/screens/provider_detail_screen.dart`
- Modify: `lib/screens/discovered_salon_detail_screen.dart`
- Modify: `lib/screens/salon_onboarding_screen.dart`
- Modify: `lib/screens/chat_list_screen.dart`
- Modify: `lib/screens/chat_router_screen.dart`
- Modify: `lib/screens/chat_conversation_screen.dart`

**Important:** `provider_detail_screen.dart:390` and `provider_list_screen.dart:332` have WhatsApp button colors (`Color(0xFF25D366)`). Replace those with the constant `kWhatsAppGreen` from `palettes.dart` — do NOT theme them.

**Step 1: Apply conversion pattern. Import `kWhatsAppGreen` from palettes.dart for WhatsApp buttons.**

**Step 2: Verify**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/provider_list_screen.dart lib/screens/provider_detail_screen.dart lib/screens/discovered_salon_detail_screen.dart lib/screens/salon_onboarding_screen.dart lib/screens/chat_list_screen.dart lib/screens/chat_router_screen.dart lib/screens/chat_conversation_screen.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/provider_list_screen.dart lib/screens/provider_detail_screen.dart lib/screens/discovered_salon_detail_screen.dart lib/screens/salon_onboarding_screen.dart lib/screens/chat_list_screen.dart lib/screens/chat_router_screen.dart lib/screens/chat_conversation_screen.dart
git commit -m "refactor(theme): convert provider/salon/chat screens to theme tokens"
```

---

## Task 12: Convert utility screens and remaining widgets

**Files:**
- Modify: `lib/screens/auth_screen.dart`
- Modify: `lib/screens/splash_screen.dart`
- Modify: `lib/screens/device_manager_screen.dart`
- Modify: `lib/screens/qr_scan_screen.dart`
- Modify: `lib/screens/payment_methods_screen.dart`
- Modify: `lib/screens/media_manager_screen.dart`
- Modify: `lib/screens/virtual_studio_screen.dart`
- Modify: `lib/widgets/location_picker_sheet.dart`
- Modify: `lib/widgets/bc_image_picker_sheet.dart`
- Modify: `lib/widgets/media_viewer.dart`
- Modify: `lib/widgets/animated_city_map.dart`
- Modify: `lib/widgets/video_map_background.dart`

**Step 1: Apply conversion pattern.**

**Step 2: Verify**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/auth_screen.dart lib/screens/splash_screen.dart lib/screens/device_manager_screen.dart lib/screens/qr_scan_screen.dart lib/screens/payment_methods_screen.dart lib/screens/media_manager_screen.dart lib/screens/virtual_studio_screen.dart lib/widgets/location_picker_sheet.dart lib/widgets/bc_image_picker_sheet.dart lib/widgets/media_viewer.dart`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/auth_screen.dart lib/screens/splash_screen.dart lib/screens/device_manager_screen.dart lib/screens/qr_scan_screen.dart lib/screens/payment_methods_screen.dart lib/screens/media_manager_screen.dart lib/screens/virtual_studio_screen.dart lib/widgets/location_picker_sheet.dart lib/widgets/bc_image_picker_sheet.dart lib/widgets/media_viewer.dart lib/widgets/animated_city_map.dart lib/widgets/video_map_background.dart
git commit -m "refactor(theme): convert utility screens and remaining widgets"
```

---

## Task 13: Convert admin screens, providers, services, and data

**Files:**
- Modify: `lib/screens/admin/admin_shell_screen.dart`
- Modify: `lib/screens/admin/salon_management_screen.dart`
- Modify: `lib/screens/admin/service_profile_editor_screen.dart`
- Modify: `lib/screens/admin/engine_settings_editor_screen.dart`
- Modify: `lib/screens/admin/category_tree_screen.dart`
- Modify: `lib/screens/admin/time_rules_screen.dart`
- Modify: `lib/screens/admin/analytics_screen.dart`
- Modify: `lib/screens/admin/notification_templates_screen.dart`
- Modify: `lib/providers/booking_flow_provider.dart`
- Modify: `lib/providers/payment_methods_provider.dart`
- Modify: `lib/services/toast_service.dart`
- Modify: `lib/data/categories.dart`
- Modify: `lib/config/routes.dart` (error page hardcoded color)

**For `categories.dart`:** The category `color` field stays as-is in the data file (it's the default). But screens should read from `ext.categoryColors[index]` instead. The category data structure keeps its color for fallback.

For `routes.dart` error page: Replace `Color(0xFFC2185B)` with `Theme.of(context).colorScheme.primary`.

For providers that have hardcoded colors: These are typically used for status indicators — replace with semantic color constants or pass colors from the UI layer.

**Step 1: Apply conversion pattern.**

**Step 2: Verify entire project compiles**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze`
Expected: No errors (or only pre-existing warnings)

**Step 3: Commit**

```bash
git add lib/screens/admin/ lib/providers/booking_flow_provider.dart lib/providers/payment_methods_provider.dart lib/services/toast_service.dart lib/data/categories.dart lib/config/routes.dart
git commit -m "refactor(theme): convert admin screens, providers, services, and data"
```

---

## Task 14: Full build verification

**Files:** None — this is a verification task.

**Step 1: Run flutter analyze on entire project**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze`
Expected: No errors

**Step 2: Build release APK**

Run: `cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter build apk --release --no-tree-shake-icons --target-platform android-arm64`
Expected: BUILD SUCCESSFUL

**Step 3: Verify Rose & Gold is default**

Install and launch app. It should look identical to the current build. Navigate to Settings → Apariencia. The Rose & Gold card should have a checkmark.

**Step 4: Test theme switching**

Tap each of the 7 themes. Verify:
- Theme applies instantly
- System status bar and nav bar update per theme
- Navigate to home, booking flow, settings — all use new colors
- Switch back to Rose & Gold — exact same as before

**Step 5: Test persistence**

Select a non-default theme, force-close the app, reopen. Theme should persist.

**Step 6: Commit final state if any tweaks were needed**

```bash
git add -A
git commit -m "feat(theme): complete 7-theme system with visual picker and persistence"
```

---

## File Summary

| File | Action |
|------|--------|
| `lib/config/palettes.dart` | **Create** — BCPalette class + 7 palette definitions |
| `lib/config/theme_extension.dart` | **Create** — BCThemeExtension for non-standard tokens |
| `lib/config/theme.dart` | **Rewrite** — buildThemeFromPalette() factory + legacy statics |
| `lib/providers/theme_provider.dart` | **Create** — Riverpod ThemeNotifier + SharedPreferences |
| `lib/screens/appearance_screen.dart` | **Create** — Visual theme picker grid |
| `lib/config/routes.dart` | **Modify** — Add /settings/appearance route |
| `lib/main.dart` | **Modify** — Wire themeProvider into MaterialApp |
| ~47 screen/widget/provider files | **Modify** — Replace hardcoded colors with theme tokens |

## Conversion Quick Reference

| Old Pattern | New Pattern |
|-------------|-------------|
| `BeautyCitaTheme.primaryRose` | `Theme.of(context).colorScheme.primary` |
| `BeautyCitaTheme.secondaryGold` | `Theme.of(context).colorScheme.secondary` |
| `BeautyCitaTheme.surfaceCream` | `Theme.of(context).colorScheme.surface` |
| `BeautyCitaTheme.backgroundWhite` | `Theme.of(context).scaffoldBackgroundColor` |
| `BeautyCitaTheme.textDark` | `Theme.of(context).colorScheme.onSurface` |
| `BeautyCitaTheme.textLight` | `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)` |
| `BeautyCitaTheme.dividerLight` | `Theme.of(context).dividerColor` |
| `BeautyCitaTheme.primaryGradient` | `ext.primaryGradient` |
| `BeautyCitaTheme.accentGradient` | `ext.accentGradient` |
| Local `_goldGradient` const | `ext.goldGradientDirectional()` |
| `Color(0xFFC2185B)` | `Theme.of(context).colorScheme.primary` |
| `Color(0xFFFFB300)` | `Theme.of(context).colorScheme.secondary` |
| `Color(0xFF212121)` | `Theme.of(context).colorScheme.onSurface` |
| `Color(0xFFFFF8F0)` | `Theme.of(context).colorScheme.surface` |
| `Color(0xFF25D366)` (WhatsApp) | `kWhatsAppGreen` (NOT themed) |
| `BeautyCitaTheme.spaceXX` | `AppConstants.paddingXX` (same values) |
