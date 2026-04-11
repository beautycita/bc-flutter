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
  final List<Color> accentGradientStops;
  final List<double> accentGradientPositions;

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
    required this.accentGradientStops,
    required this.accentGradientPositions,
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

/// The canonical 13-stop brand accent gradient (pink → purple).
const kAccentGradientStops = [
  Color(0xFFBE185D),
  Color(0xFFEC4899),
  Color(0xFFF9A8D4),
  Color(0xFFD946EF),
  Color(0xFFC026D3),
  Color(0xFFA855F7),
  Color(0xFFE9D5FF),
  Color(0xFF9333EA),
  Color(0xFF7C3AED),
  Color(0xFF8B5CF6),
  Color(0xFFF0ABFC),
  Color(0xFF7E22CE),
  Color(0xFF6B21A8),
];

const kAccentGradientPositions = [
  0.0, 0.08, 0.15, 0.25, 0.35, 0.45, 0.50, 0.58, 0.68, 0.78, 0.85, 0.93, 1.0
];

/// @deprecated Use [kAccentGradientStops] instead.
const kGoldStops = kAccentGradientStops;

/// @deprecated Use [kAccentGradientPositions] instead.
const kGoldPositions = kAccentGradientPositions;

/// WhatsApp brand colors — NOT themed, used as app-level constants.
const kWhatsAppGreen = Color(0xFF25D366);
const kWhatsAppDarkGreen = Color(0xFF075E54);

// ─── BeautyCita Palette (Light) ──────────────────────────────────────────

/// Brand palette: lilac primary (#C8A2C8), pink→purple→blue gradient.
const beautycitaPalette = BCPalette(
  id: 'beautycita',
  nameEs: 'BeautyCita',
  nameEn: 'BeautyCita',
  brightness: Brightness.light,
  primary: Color(0xFFC8A2C8),         // #C8A2C8 lilac
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFFAA7EAA),       // deeper lilac for contrast
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFFCF8FC),         // lilac-tinted surface
  onSurface: Color(0xFF212121),
  scaffoldBackground: Color(0xFFFFFFFF),
  error: Color(0xFFD32F2F),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0xFFFCF8FC),
  cardBorderColor: Color(0xFFEEEEEE),
  divider: Color(0xFFEEEEEE),
  textPrimary: Color(0xFF212121),
  textSecondary: Color(0xFF757575),
  textHint: Color(0xFF9E9E9E),
  shimmerColor: Color(0xFFAA7EAA),
  success: Color(0xFF4CAF50),
  warning: Color(0xFFFFA000),
  info: Color(0xFF2196F3),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFC8A2C8), Color(0xFFAA7EAA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradientStops: kAccentGradientStops,
  accentGradientPositions: kAccentGradientPositions,
  categoryColors: [
    Color(0xFFD4A0D4), // nails — lilac tint
    Color(0xFF8D6E63), // hair
    Color(0xFFB07EB0), // lashes_brows — deeper lilac
    Color(0xFFE08080), // makeup
    Color(0xFF26A69A), // facial
    Color(0xFF8A7CB8), // body_spa — purple-lilac
    Color(0xFFFFA726), // specialized
    Color(0xFF37474F), // barberia
  ],
  cinematicPrimary: Color(0xFFC8A2C8),
  cinematicAccent: Color(0xFFAA7EAA),
  cinematicGradient: [Color(0xFFBE185D), Color(0xFF7C3AED), Color(0xFF2563EB)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  navigationBarColor: Color(0xFFFFFFFF),
  navigationBarIconBrightness: Brightness.dark,
);

// ─── BeautyCita Palette (Dark) ───────────────────────────────────────────

/// Dark variant: same lilac primary, dark surfaces.
const beautycitaDarkPalette = BCPalette(
  id: 'beautycita_dark',
  nameEs: 'BeautyCita Oscuro',
  nameEn: 'BeautyCita Dark',
  brightness: Brightness.dark,
  primary: Color(0xFFC8A2C8),         // same lilac
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFFAA7EAA),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFF1E1E2A),
  onSurface: Color(0xFFF5F5F5),
  scaffoldBackground: Color(0xFF121218),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0xFF1E1E2A),
  cardBorderColor: Color(0xFF3A3A4A),
  divider: Color(0xFF2A2A3A),
  textPrimary: Color(0xFFF5F5F5),
  textSecondary: Color(0xFFB0B0B0),
  textHint: Color(0xFF808080),
  shimmerColor: Color(0xFFAA7EAA),
  success: Color(0xFF69F0AE),
  warning: Color(0xFFFFD740),
  info: Color(0xFF40C4FF),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFC8A2C8), Color(0xFFAA7EAA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradientStops: kAccentGradientStops,
  accentGradientPositions: kAccentGradientPositions,
  categoryColors: [
    Color(0xFFD4A0D4),
    Color(0xFF8D6E63),
    Color(0xFFB07EB0),
    Color(0xFFE08080),
    Color(0xFF26A69A),
    Color(0xFF8A7CB8),
    Color(0xFFFFA726),
    Color(0xFF37474F),
  ],
  cinematicPrimary: Color(0xFFC8A2C8),
  cinematicAccent: Color(0xFFAA7EAA),
  cinematicGradient: [Color(0xFFBE185D), Color(0xFF7C3AED), Color(0xFF2563EB)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  navigationBarColor: Color(0xFF121218),
  navigationBarIconBrightness: Brightness.light,
);
