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
