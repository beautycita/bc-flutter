import 'package:flutter/material.dart';
import 'package:beautycita_core/theme.dart';

/// Builds a full [ThemeData] from a [BCPalette].
///
/// Desktop-first styling: larger text, spacious padding, hover states.
/// Uses font family names directly — no Google Fonts CDN fetching.
ThemeData buildWebTheme(
  BCPalette palette, {
  Brightness brightness = Brightness.light,
}) {
  final colorScheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.secondary,
    onSecondary: palette.onSecondary,
    error: palette.error,
    onError: palette.onError,
    surface: palette.surface,
    onSurface: palette.onSurface,
    surfaceContainerHighest: palette.cardColor,
    outline: palette.cardBorderColor,
    outlineVariant: palette.divider,
  );

  // Build text styles from palette fonts — no CDN fetching
  TextStyle heading(double size, FontWeight weight) => TextStyle(
        fontFamily: palette.headingFont,
        fontSize: size,
        fontWeight: weight,
        color: palette.textPrimary,
        letterSpacing: -0.2,
      );

  TextStyle body(double size, FontWeight weight) => TextStyle(
        fontFamily: palette.bodyFont,
        fontSize: size,
        fontWeight: weight,
        color: palette.textPrimary,
      );

  final textTheme = TextTheme(
    // Display
    displayLarge: heading(57, FontWeight.w700),
    displayMedium: heading(45, FontWeight.w600),
    displaySmall: heading(36, FontWeight.w600),
    // Headline
    headlineLarge: heading(32, FontWeight.w600),
    headlineMedium: heading(28, FontWeight.w600),
    headlineSmall: heading(24, FontWeight.w600),
    // Title
    titleLarge: heading(22, FontWeight.w600),
    titleMedium: heading(18, FontWeight.w500),
    titleSmall: heading(16, FontWeight.w500),
    // Body
    bodyLarge: body(16, FontWeight.w400),
    bodyMedium: body(14, FontWeight.w400),
    bodySmall: body(12, FontWeight.w400),
    // Label
    labelLarge: body(14, FontWeight.w600),
    labelMedium: body(12, FontWeight.w500),
    labelSmall: body(11, FontWeight.w500),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.scaffoldBackground,
    dividerColor: palette.divider,
    textTheme: textTheme,

    // ── AppBar ────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      foregroundColor: palette.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: heading(20, FontWeight.w600),
      toolbarHeight: 64,
    ),

    // ── Card ──────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: palette.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          BCSpacing.radiusSm * palette.radiusScale,
        ),
        side: BorderSide(color: palette.cardBorderColor, width: 1),
      ),
      margin: const EdgeInsets.all(BCSpacing.sm),
    ),

    // ── Divider ───────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: BCSpacing.md,
    ),

    // ── Input decoration ──────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.md,
        vertical: BCSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          BCSpacing.radiusXs * palette.radiusScale,
        ),
        borderSide: BorderSide(color: palette.cardBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          BCSpacing.radiusXs * palette.radiusScale,
        ),
        borderSide: BorderSide(color: palette.cardBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          BCSpacing.radiusXs * palette.radiusScale,
        ),
        borderSide: BorderSide(color: palette.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          BCSpacing.radiusXs * palette.radiusScale,
        ),
        borderSide: BorderSide(color: palette.error),
      ),
      hintStyle: body(14, FontWeight.w400).copyWith(color: palette.textHint),
      labelStyle: body(14, FontWeight.w500).copyWith(
        color: palette.textSecondary,
      ),
    ),

    // ── Elevated button ───────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: BCSpacing.lg,
          vertical: BCSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            BCSpacing.radiusXs * palette.radiusScale,
          ),
        ),
        textStyle: body(15, FontWeight.w600),
        minimumSize: const Size(120, 48),
      ),
    ),

    // ── Text button ───────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
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
        foregroundColor: palette.primary,
        side: BorderSide(color: palette.primary),
        padding: const EdgeInsets.symmetric(
          horizontal: BCSpacing.lg,
          vertical: BCSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            BCSpacing.radiusXs * palette.radiusScale,
          ),
        ),
        textStyle: body(15, FontWeight.w600),
        minimumSize: const Size(120, 48),
      ),
    ),

    // ── Icon button ───────────────────────────────────────────────────────
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.onSurface,
        hoverColor: palette.primary.withValues(alpha: 0.08),
      ),
    ),

    // ── Tooltip ───────────────────────────────────────────────────────────
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: palette.onSurface,
        borderRadius: BorderRadius.circular(BCSpacing.xs),
      ),
      textStyle: body(12, FontWeight.w400).copyWith(color: palette.surface),
      waitDuration: const Duration(milliseconds: 500),
    ),

    // ── Data table ────────────────────────────────────────────────────────
    dataTableTheme: DataTableThemeData(
      headingTextStyle: body(13, FontWeight.w600).copyWith(
        color: palette.textSecondary,
      ),
      dataTextStyle: body(14, FontWeight.w400),
      dividerThickness: 1,
    ),

    // ── Chip ──────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: palette.surface,
      selectedColor: palette.primary.withValues(alpha: 0.12),
      side: BorderSide(color: palette.cardBorderColor),
      labelStyle: body(13, FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
    ),

    // ── Navigation rail (for sidebar) ─────────────────────────────────────
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.surface,
      selectedIconTheme: IconThemeData(color: palette.primary),
      unselectedIconTheme: IconThemeData(color: palette.textSecondary),
      indicatorColor: palette.primary.withValues(alpha: 0.12),
    ),

    // ── Dialog ────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          BCSpacing.radiusMd * palette.radiusScale,
        ),
      ),
      titleTextStyle: heading(20, FontWeight.w600),
      contentTextStyle: body(14, FontWeight.w400),
    ),

    // ── Snackbar ──────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.onSurface,
      contentTextStyle: body(14, FontWeight.w400).copyWith(
        color: palette.surface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
      ),
    ),
  );
}
