import 'package:flutter/material.dart';
import 'package:beautycita_core/theme.dart';

// ============================================================================
// Web Theme — Approved Design Spec (2026-03-24)
//
// Overrides palette defaults with web-specific values:
//   Background: #FFFAF5, Surface: #FFFFFF, Card border: #f0ebe6
//   Text: #1a1a1a / #666 / #999
//   Font: system-ui stack (no Google Fonts CDN)
//   Typography scaled for desktop monitors
// ============================================================================

// ── Web-specific color overrides ───────────────────────────────────────────

/// Warm white page background.
const kWebBackground = Color(0xFFFFFAF5);

/// Pure white for cards and surfaces.
const kWebSurface = Color(0xFFFFFFFF);

/// Warm card border color.
const kWebCardBorder = Color(0xFFF0EBE6);

/// Text hierarchy.
const kWebTextPrimary = Color(0xFF1A1A1A);
const kWebTextSecondary = Color(0xFF666666);
const kWebTextHint = Color(0xFF999999);

/// Brand colors.
const kWebPrimary = Color(0xFFEC4899);
const kWebSecondary = Color(0xFF9333EA);
const kWebTertiary = Color(0xFF3B82F6);

/// Brand gradient: pink -> purple -> blue at 135 degrees.
const kWebBrandGradient = LinearGradient(
  colors: [kWebPrimary, kWebSecondary, kWebTertiary],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// System font stack — no external font loading.
const kWebFontFamily = 'system-ui, -apple-system, BlinkMacSystemFont, '
    '"Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

// For Flutter, we use the first value that the engine will resolve.
const _kSystemFont = 'system-ui';

/// Max content width for centered layouts.
const kWebMaxContentWidth = 1200.0;

/// Standard section vertical spacing.
const kWebSectionSpacing = 100.0;

// ── Theme builder ──────────────────────────────────────────────────────────

/// Builds a full [ThemeData] from a [BCPalette] with web-specific overrides.
///
/// Desktop-first styling: larger text, spacious padding, hover states.
/// Uses system font stack — no Google Fonts CDN fetching.
ThemeData buildWebTheme(
  BCPalette palette, {
  Brightness brightness = Brightness.light,
}) {
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: kWebPrimary,
    onPrimary: Colors.white,
    secondary: kWebSecondary,
    onSecondary: Colors.white,
    tertiary: kWebTertiary,
    onTertiary: Colors.white,
    error: palette.error,
    onError: palette.onError,
    surface: kWebSurface,
    onSurface: kWebTextPrimary,
    surfaceContainerHighest: kWebSurface,
    outline: kWebCardBorder,
    outlineVariant: kWebCardBorder,
  );

  // ── Typography (design spec sizes) ──────────────────────────────────────

  TextStyle heading(double size, FontWeight weight) => TextStyle(
        fontFamily: _kSystemFont,
        fontSize: size,
        fontWeight: weight,
        color: kWebTextPrimary,
        letterSpacing: -0.2,
        height: 1.2,
      );

  TextStyle body(double size, FontWeight weight) => TextStyle(
        fontFamily: _kSystemFont,
        fontSize: size,
        fontWeight: weight,
        color: kWebTextPrimary,
        height: 1.7,
      );

  final textTheme = TextTheme(
    // Display — hero headlines: 48-56px, weight 800
    displayLarge: heading(56, FontWeight.w800),
    displayMedium: heading(48, FontWeight.w800),
    displaySmall: heading(42, FontWeight.w800),
    // Headline — section titles: 36-42px, weight 800
    headlineLarge: heading(42, FontWeight.w800),
    headlineMedium: heading(36, FontWeight.w800),
    headlineSmall: heading(28, FontWeight.w700),
    // Title — card titles: 18-20px, weight 700
    titleLarge: heading(22, FontWeight.w700),
    titleMedium: heading(20, FontWeight.w700),
    titleSmall: heading(18, FontWeight.w700),
    // Body — 16-18px, weight 400, line-height 1.7
    bodyLarge: body(18, FontWeight.w400),
    bodyMedium: body(16, FontWeight.w400),
    bodySmall: body(14, FontWeight.w400),
    // Label — 12-14px, weight 600
    labelLarge: body(14, FontWeight.w600),
    labelMedium: body(12, FontWeight.w600),
    labelSmall: body(11, FontWeight.w500),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kWebBackground,
    dividerColor: kWebCardBorder,
    textTheme: textTheme,

    // ── AppBar ────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: kWebSurface,
      foregroundColor: kWebTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: heading(20, FontWeight.w700),
      toolbarHeight: 64,
    ),

    // ── Card ──────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: kWebSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kWebCardBorder, width: 1),
      ),
      margin: const EdgeInsets.all(BCSpacing.sm),
    ),

    // ── Divider ───────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: kWebCardBorder,
      thickness: 1,
      space: BCSpacing.md,
    ),

    // ── Input decoration ──────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kWebSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.md,
        vertical: BCSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kWebCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kWebCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kWebPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.error),
      ),
      hintStyle: body(14, FontWeight.w400).copyWith(color: kWebTextHint),
      labelStyle: body(14, FontWeight.w500).copyWith(color: kWebTextSecondary),
    ),

    // ── Elevated button ───────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kWebPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: BCSpacing.lg,
          vertical: BCSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: body(15, FontWeight.w600),
        minimumSize: const Size(120, 48),
      ),
    ),

    // ── Text button ───────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kWebPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: BCSpacing.md,
          vertical: BCSpacing.sm,
        ),
        textStyle: body(14, FontWeight.w600),
      ),
    ),

    // ── Outlined button ───────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kWebPrimary,
        side: const BorderSide(color: kWebPrimary, width: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: BCSpacing.lg,
          vertical: BCSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: body(15, FontWeight.w600),
        minimumSize: const Size(120, 48),
      ),
    ),

    // ── Icon button ───────────────────────────────────────────────────────
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: kWebTextPrimary,
        hoverColor: kWebPrimary.withValues(alpha: 0.08),
      ),
    ),

    // ── Tooltip ───────────────────────────────────────────────────────────
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: kWebTextPrimary,
        borderRadius: BorderRadius.circular(BCSpacing.xs),
      ),
      textStyle: body(12, FontWeight.w400).copyWith(color: kWebSurface),
      waitDuration: const Duration(milliseconds: 500),
    ),

    // ── Data table ────────────────────────────────────────────────────────
    dataTableTheme: DataTableThemeData(
      headingTextStyle: body(13, FontWeight.w600).copyWith(
        color: kWebTextSecondary,
      ),
      dataTextStyle: body(14, FontWeight.w400),
      dividerThickness: 1,
    ),

    // ── Chip ──────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: kWebSurface,
      selectedColor: kWebPrimary.withValues(alpha: 0.12),
      side: const BorderSide(color: kWebCardBorder),
      labelStyle: body(13, FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
    ),

    // ── Navigation rail (for sidebar) ─────────────────────────────────────
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: kWebSurface,
      selectedIconTheme: const IconThemeData(color: kWebPrimary),
      unselectedIconTheme: const IconThemeData(color: kWebTextSecondary),
      indicatorColor: kWebPrimary.withValues(alpha: 0.12),
    ),

    // ── Dialog ────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: kWebSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: heading(20, FontWeight.w700),
      contentTextStyle: body(14, FontWeight.w400),
    ),

    // ── Snackbar ──────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kWebTextPrimary,
      contentTextStyle: body(14, FontWeight.w400).copyWith(color: kWebSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
