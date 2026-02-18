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

  // Status colors (booking/appointment lifecycle)
  final Color statusPending;
  final Color statusConfirmed;
  final Color statusCompleted;
  final Color statusCancelled;

  // Chart colors
  final List<Color> chartColors;
  final Color chartGridColor;
  final Color chartLabelColor;

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
    this.statusPending = const Color(0xFFFFA000),
    this.statusConfirmed = const Color(0xFF2196F3),
    this.statusCompleted = const Color(0xFF4CAF50),
    this.statusCancelled = const Color(0xFFE53E3E),
    this.chartColors = const [
      Color(0xFFC2185B),
      Color(0xFFFFB300),
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFF9C27B0),
      Color(0xFF00BCD4),
      Color(0xFFFF5722),
      Color(0xFF607D8B),
    ],
    this.chartGridColor = const Color(0xFFE0E0E0),
    this.chartLabelColor = const Color(0xFF757575),
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
  // Light palette — default status colors are fine
  chartColors: [
    Color(0xFFC2185B),
    Color(0xFFFFB300),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF607D8B),
  ],
  chartGridColor: Color(0xFFEEEEEE),
  chartLabelColor: Color(0xFF757575),
);

/// 2. Black & Gold — luxury editorial, sharp corners, tight spacing
const blackGoldPalette = BCPalette(
  id: 'black_gold',
  nameEs: 'Negro y Oro',
  nameEn: 'Black & Gold',
  brightness: Brightness.dark,
  headingFont: 'Playfair Display',
  bodyFont: 'Lato',
  spacingScale: 0.9,
  radiusScale: 0.5,
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
  // Dark palette — bright status colors
  statusPending: Color(0xFFFFD740),
  statusConfirmed: Color(0xFF40C4FF),
  statusCompleted: Color(0xFF69F0AE),
  statusCancelled: Color(0xFFFF6B6B),
  chartColors: [
    Color(0xFFFFB300),
    Color(0xFFD4AF37),
    Color(0xFF40C4FF),
    Color(0xFF69F0AE),
    Color(0xFFCE93D8),
    Color(0xFFFF8A80),
    Color(0xFFFFCC80),
    Color(0xFF90A4AE),
  ],
  chartGridColor: Color(0xFF2A2A3E),
  chartLabelColor: Color(0xFFB0B0B0),
);

/// 3. Glassmorphism — modern minimal, large radius, airy spacing
const glassmorphismPalette = BCPalette(
  id: 'glass',
  nameEs: 'Cristal',
  nameEn: 'Glassmorphism',
  brightness: Brightness.dark,
  headingFont: 'Inter',
  bodyFont: 'Inter',
  spacingScale: 1.15,
  radiusScale: 1.5,
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
  // Dark palette — bright status colors
  statusPending: Color(0xFFFFD740),
  statusConfirmed: Color(0xFF40C4FF),
  statusCompleted: Color(0xFF69F0AE),
  statusCancelled: Color(0xFFFF6B6B),
  chartColors: [
    Color(0xFFEC4899),
    Color(0xFF9333EA),
    Color(0xFF3B82F6),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
    Color(0xFF60A5FA),
    Color(0xFFF472B6),
    Color(0xFF94A3B8),
  ],
  chartGridColor: Color(0xFF1A1A2E),
  chartLabelColor: Color(0xFFB0B0B0),
);

/// 4. Midnight Orchid — whimsical, soft/rounded, playful
const midnightOrchidPalette = BCPalette(
  id: 'midnight_orchid',
  nameEs: 'Orquidea Nocturna',
  nameEn: 'Midnight Orchid',
  brightness: Brightness.dark,
  headingFont: 'Quicksand',
  bodyFont: 'Quicksand',
  spacingScale: 1.05,
  radiusScale: 1.3,
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
  // Dark palette — bright status colors
  statusPending: Color(0xFFFFD740),
  statusConfirmed: Color(0xFF40C4FF),
  statusCompleted: Color(0xFF69F0AE),
  statusCancelled: Color(0xFFFF6B6B),
  chartColors: [
    Color(0xFFB388FF),
    Color(0xFFE040FB),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFFF80AB),
    Color(0xFFFFD740),
    Color(0xFFCE93D8),
    Color(0xFF90A4AE),
  ],
  chartGridColor: Color(0xFF2A1545),
  chartLabelColor: Color(0xFFCE93D8),
);

/// 5. Ocean Noir — tech/cyberpunk, angular, tight
const oceanNoirPalette = BCPalette(
  id: 'ocean_noir',
  nameEs: 'Oceano Oscuro',
  nameEn: 'Ocean Noir',
  brightness: Brightness.dark,
  headingFont: 'Rajdhani',
  bodyFont: 'Source Sans 3',
  spacingScale: 0.85,
  radiusScale: 0.4,
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
  // Dark palette — bright status colors
  statusPending: Color(0xFFFFD740),
  statusConfirmed: Color(0xFF40C4FF),
  statusCompleted: Color(0xFF69F0AE),
  statusCancelled: Color(0xFFFF6B6B),
  chartColors: [
    Color(0xFF00E5FF),
    Color(0xFF1DE9B6),
    Color(0xFF448AFF),
    Color(0xFFFFD740),
    Color(0xFFFF6B9D),
    Color(0xFFCE93D8),
    Color(0xFF80CBC4),
    Color(0xFF90A4AE),
  ],
  chartGridColor: Color(0xFF163650),
  chartLabelColor: Color(0xFF80DEEA),
);

/// 6. Cherry Blossom — romantic, elegant serif headers, airy
const cherryBlossomPalette = BCPalette(
  id: 'cherry_blossom',
  nameEs: 'Flor de Cerezo',
  nameEn: 'Cherry Blossom',
  brightness: Brightness.light,
  headingFont: 'Cormorant Garamond',
  bodyFont: 'Nunito Sans',
  spacingScale: 1.1,
  radiusScale: 1.2,
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
  // Light palette — default status colors are fine
  chartColors: [
    Color(0xFFFF6B9D),
    Color(0xFFC084FC),
    Color(0xFF818CF8),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
    Color(0xFF60A5FA),
    Color(0xFFFB7185),
    Color(0xFF94A3B8),
  ],
  chartGridColor: Color(0xFFF8BBD0),
  chartLabelColor: Color(0xFF7C5295),
);

/// 7. Emerald Luxe — art deco, geometric, structured
const emeraldLuxePalette = BCPalette(
  id: 'emerald_luxe',
  nameEs: 'Esmeralda Lujosa',
  nameEn: 'Emerald Luxe',
  brightness: Brightness.dark,
  headingFont: 'Cinzel',
  bodyFont: 'Raleway',
  spacingScale: 0.95,
  radiusScale: 0.6,
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
  goldGradientStops: kGoldStops,
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
  // Dark palette — bright status colors
  statusPending: Color(0xFFFFD740),
  statusConfirmed: Color(0xFF40C4FF),
  statusCompleted: Color(0xFF69F0AE),
  statusCancelled: Color(0xFFFF6B6B),
  chartColors: [
    Color(0xFF00E676),
    Color(0xFFFFD700),
    Color(0xFF40C4FF),
    Color(0xFFFF6B9D),
    Color(0xFFCE93D8),
    Color(0xFFFF8A80),
    Color(0xFFFFCC80),
    Color(0xFF90A4AE),
  ],
  chartGridColor: Color(0xFF1B3A1B),
  chartLabelColor: Color(0xFFA5D6A7),
);

// ─── Light / Dark counterpart palettes ───────────────────────────────────────

/// Rose Gold DARK — "Jewelry in a dark velvet box"
const roseGoldDarkPalette = BCPalette(
  id: 'rose_gold',
  nameEs: 'Rosa y Oro',
  nameEn: 'Rose & Gold',
  brightness: Brightness.dark,
  primary: Color(0xFFE91E63),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFFFFD700),
  onSecondary: Color(0xFF120A10),
  surface: Color(0xFF1E1420),
  onSurface: Color(0xFFF5E8F0),
  scaffoldBackground: Color(0xFF120A10),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFF120A10),
  cardColor: Color(0xFF1E1420),
  cardBorderColor: Color(0xFF3D1830),
  divider: Color(0xFF2A1520),
  textPrimary: Color(0xFFF5E8F0),
  textSecondary: Color(0xFFC0A0B0),
  textHint: Color(0xFF806070),
  shimmerColor: Color(0xFFFFD700),
  success: Color(0xFF69F0AE),
  warning: Color(0xFFFFA000),
  info: Color(0xFF82B1FF),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFFD81B60)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
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
  cinematicPrimary: Color(0xFFE91E63),
  cinematicAccent: Color(0xFFFFD700),
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  navigationBarColor: Color(0xFF120A10),
  navigationBarIconBrightness: Brightness.light,
  // Dark palette — bright status colors
  statusPending: Color(0xFFFFD740),
  statusConfirmed: Color(0xFF40C4FF),
  statusCompleted: Color(0xFF69F0AE),
  statusCancelled: Color(0xFFFF6B6B),
  chartColors: [
    Color(0xFFE91E63),
    Color(0xFFFFD700),
    Color(0xFF40C4FF),
    Color(0xFF69F0AE),
    Color(0xFFCE93D8),
    Color(0xFF9FA8DA),
    Color(0xFFFFCC80),
    Color(0xFF90A4AE),
  ],
  chartGridColor: Color(0xFF2A1520),
  chartLabelColor: Color(0xFFC0A0B0),
);

/// Black & Gold LIGHT — "Luxury magazine on cream paper"
const blackGoldLightPalette = BCPalette(
  id: 'black_gold',
  nameEs: 'Negro y Oro',
  nameEn: 'Black & Gold',
  brightness: Brightness.light,
  headingFont: 'Playfair Display',
  bodyFont: 'Lato',
  spacingScale: 0.9,
  radiusScale: 0.5,
  primary: Color(0xFFB8860B),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF8B6914),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFFFF5E6),
  onSurface: Color(0xFF2C2416),
  scaffoldBackground: Color(0xFFFFF9F0),
  error: Color(0xFFD32F2F),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0xFFFFFFFF),
  cardBorderColor: Color(0xFFE8D5B0),
  divider: Color(0xFFE8D5B0),
  textPrimary: Color(0xFF2C2416),
  textSecondary: Color(0xFF7A6B55),
  textHint: Color(0xFFB0A08A),
  shimmerColor: Color(0xFFD4AF37),
  success: Color(0xFF4CAF50),
  warning: Color(0xFFFFA000),
  info: Color(0xFF2196F3),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFB8860B), Color(0xFFD4AF37)],
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
    Color(0xFFE91E63), Color(0xFF8D6E63), Color(0xFF9C27B0),
    Color(0xFFFF5252), Color(0xFF26A69A), Color(0xFF5C6BC0),
    Color(0xFFFFA726), Color(0xFF37474F),
  ],
  cinematicPrimary: Color(0xFFB8860B),
  cinematicAccent: Color(0xFFD4AF37),
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  navigationBarColor: Color(0xFFFFF9F0),
  navigationBarIconBrightness: Brightness.dark,
  // Light palette — default status colors are fine
  chartColors: [
    Color(0xFFB8860B),
    Color(0xFFD4AF37),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFFFFA726),
    Color(0xFF607D8B),
  ],
  chartGridColor: Color(0xFFE8D5B0),
  chartLabelColor: Color(0xFF7A6B55),
);

/// Glass LIGHT — "Frosted white panels, pastel neon"
const glassmorphismLightPalette = BCPalette(
  id: 'glass',
  nameEs: 'Cristal',
  nameEn: 'Glassmorphism',
  brightness: Brightness.light,
  headingFont: 'Inter',
  bodyFont: 'Inter',
  spacingScale: 1.15,
  radiusScale: 1.5,
  primary: Color(0xFFE91E63),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF7E57C2),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFEDE5F5),
  onSurface: Color(0xFF1A1A2E),
  scaffoldBackground: Color(0xFFF5F0FA),
  error: Color(0xFFE53E3E),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0x0D000000), // 5% black
  cardBorderColor: Color(0x1A000000), // 10% black
  divider: Color(0x14000000), // 8% black
  textPrimary: Color(0xFF1A1A2E),
  textSecondary: Color(0xFF5C5070),
  textHint: Color(0xFF9088A0),
  shimmerColor: Color(0xFF7E57C2),
  success: Color(0xFF2E7D32),
  warning: Color(0xFFF57C00),
  info: Color(0xFF1565C0),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFF7E57C2), Color(0xFF00ACC1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFF7E57C2), Color(0xFF00ACC1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: kGoldStops,
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFE91E63), Color(0xFF7E57C2), Color(0xFF5C6BC0),
    Color(0xFFE91E63), Color(0xFF2E7D32), Color(0xFF1565C0),
    Color(0xFFF57C00), Color(0xFF546E7A),
  ],
  blurSigma: 20,
  glassTint: Color(0x0D000000),
  glassBorderOpacity: 0.10,
  cinematicPrimary: Color(0xFFE91E63),
  cinematicAccent: Color(0xFF7E57C2),
  cinematicGradient: [Color(0xFFE91E63), Color(0xFF7E57C2), Color(0xFF00ACC1)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  navigationBarColor: Color(0xFFF5F0FA),
  navigationBarIconBrightness: Brightness.dark,
  // Light palette — default status colors are fine
  chartColors: [
    Color(0xFFE91E63),
    Color(0xFF7E57C2),
    Color(0xFF00ACC1),
    Color(0xFF2E7D32),
    Color(0xFFF57C00),
    Color(0xFF5C6BC0),
    Color(0xFF00838F),
    Color(0xFF546E7A),
  ],
  chartGridColor: Color(0xFFEDE5F5),
  chartLabelColor: Color(0xFF5C5070),
);

/// Midnight Orchid LIGHT — "Botanical watercolor on lavender"
const midnightOrchidLightPalette = BCPalette(
  id: 'midnight_orchid',
  nameEs: 'Orquidea Nocturna',
  nameEn: 'Midnight Orchid',
  brightness: Brightness.light,
  headingFont: 'Quicksand',
  bodyFont: 'Quicksand',
  spacingScale: 1.05,
  radiusScale: 1.3,
  primary: Color(0xFF7B1FA2),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFFAD1457),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFF0E6F5),
  onSurface: Color(0xFF2D1040),
  scaffoldBackground: Color(0xFFF8F0FA),
  error: Color(0xFFE53E3E),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0xFFFFFFFF),
  cardBorderColor: Color(0x66CE93D8), // 40% lavender border
  divider: Color(0x40CE93D8),
  textPrimary: Color(0xFF2D1040),
  textSecondary: Color(0xFF6A3D7D),
  textHint: Color(0xFFA080B0),
  shimmerColor: Color(0xFFAD1457),
  success: Color(0xFF4CAF50),
  warning: Color(0xFFFFA000),
  info: Color(0xFF7B1FA2),
  primaryGradient: LinearGradient(
    colors: [Color(0xFF7B1FA2), Color(0xFFAD1457)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFAD1457), Color(0xFFE91E63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: [
    Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFF8F0FA),
    Color(0xFFAD1457), Color(0xFF9C27B0), Color(0xFFCE93D8),
    Color(0xFFF8F0FA), Color(0xFF7B1FA2), Color(0xFF6A1B9A),
    Color(0xFFBA68C8), Color(0xFFF8F0FA), Color(0xFF8E24AA),
    Color(0xFF4A148C),
  ],
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFAD1457), Color(0xFF7B1FA2), Color(0xFF9C27B0),
    Color(0xFFE91E63), Color(0xFF4CAF50), Color(0xFF5C6BC0),
    Color(0xFFFFA000), Color(0xFF546E7A),
  ],
  cinematicPrimary: Color(0xFF7B1FA2),
  cinematicAccent: Color(0xFFAD1457),
  cinematicGradient: [Color(0xFF6A1B9A), Color(0xFF7B1FA2), Color(0xFFAD1457), Color(0xFFF8F0FA)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  navigationBarColor: Color(0xFFF8F0FA),
  navigationBarIconBrightness: Brightness.dark,
  // Light palette — default status colors are fine
  chartColors: [
    Color(0xFF7B1FA2),
    Color(0xFFAD1457),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFCE93D8),
    Color(0xFFE91E63),
    Color(0xFFFFA000),
    Color(0xFF546E7A),
  ],
  chartGridColor: Color(0x40CE93D8),
  chartLabelColor: Color(0xFF6A3D7D),
);

/// Ocean Noir LIGHT — "Clean tech dashboard, whiteboard"
const oceanNoirLightPalette = BCPalette(
  id: 'ocean_noir',
  nameEs: 'Oceano Oscuro',
  nameEn: 'Ocean Noir',
  brightness: Brightness.light,
  headingFont: 'Rajdhani',
  bodyFont: 'Source Sans 3',
  spacingScale: 0.85,
  radiusScale: 0.4,
  primary: Color(0xFF00838F),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF2E7D32),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFE5F0F5),
  onSurface: Color(0xFF0A1628),
  scaffoldBackground: Color(0xFFF0F8FA),
  error: Color(0xFFC62828),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0xFFFFFFFF),
  cardBorderColor: Color(0xFFC5D8E5),
  divider: Color(0xFFD0E0EA),
  textPrimary: Color(0xFF0A1628),
  textSecondary: Color(0xFF3D5570),
  textHint: Color(0xFF7090A8),
  shimmerColor: Color(0xFF00838F),
  success: Color(0xFF2E7D32),
  warning: Color(0xFFF57C00),
  info: Color(0xFF00838F),
  primaryGradient: LinearGradient(
    colors: [Color(0xFF00838F), Color(0xFF2E7D32)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFF2E7D32), Color(0xFF00838F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: [
    Color(0xFF004D6E), Color(0xFF00838F), Color(0xFFF0F8FA),
    Color(0xFF00838F), Color(0xFF00695C), Color(0xFF26A69A),
    Color(0xFFF0F8FA), Color(0xFF00838F), Color(0xFF004D40),
    Color(0xFF00897B), Color(0xFFF0F8FA), Color(0xFF006064),
    Color(0xFF004D6E),
  ],
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFE91E63), Color(0xFF00838F), Color(0xFF9C27B0),
    Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFF1565C0),
    Color(0xFFF57C00), Color(0xFF546E7A),
  ],
  cinematicPrimary: Color(0xFF00838F),
  cinematicAccent: Color(0xFF2E7D32),
  cinematicGradient: [Color(0xFF004D40), Color(0xFF00838F), Color(0xFF2E7D32), Color(0xFFF0F8FA)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  navigationBarColor: Color(0xFFF0F8FA),
  navigationBarIconBrightness: Brightness.dark,
  // Light palette — default status colors are fine
  chartColors: [
    Color(0xFF00838F),
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFFF57C00),
    Color(0xFF26A69A),
    Color(0xFF546E7A),
  ],
  chartGridColor: Color(0xFFD0E0EA),
  chartLabelColor: Color(0xFF3D5570),
);

/// Cherry Blossom DARK — "Cherry blossoms at night, moonlit"
const cherryBlossomDarkPalette = BCPalette(
  id: 'cherry_blossom',
  nameEs: 'Flor de Cerezo',
  nameEn: 'Cherry Blossom',
  brightness: Brightness.dark,
  headingFont: 'Cormorant Garamond',
  bodyFont: 'Nunito Sans',
  spacingScale: 1.1,
  radiusScale: 1.2,
  primary: Color(0xFFFF6B9D),
  onPrimary: Color(0xFF0C0810),
  secondary: Color(0xFFCE93D8),
  onSecondary: Color(0xFF0C0810),
  surface: Color(0xFF1A1020),
  onSurface: Color(0xFFF0E5F0),
  scaffoldBackground: Color(0xFF0C0810),
  error: Color(0xFFFF6B6B),
  onError: Color(0xFF0C0810),
  cardColor: Color(0xFF1A1020),
  cardBorderColor: Color(0xFF3D1830),
  divider: Color(0xFF2A1525),
  textPrimary: Color(0xFFF0E5F0),
  textSecondary: Color(0xFFB090B8),
  textHint: Color(0xFF7A6080),
  shimmerColor: Color(0xFFCE93D8),
  success: Color(0xFF69F0AE),
  warning: Color(0xFFFBBF24),
  info: Color(0xFF82B1FF),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFCE93D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFCE93D8), Color(0xFF82B1FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: [
    Color(0xFF5C1040), Color(0xFFFF6B9D), Color(0xFFF0E5F0),
    Color(0xFFCE93D8), Color(0xFFE040FB), Color(0xFFF0ABFC),
    Color(0xFFF0E5F0), Color(0xFFFF6B9D), Color(0xFFA855F7),
    Color(0xFFE879F9), Color(0xFFF0E5F0), Color(0xFFBE185D),
    Color(0xFF5C1040),
  ],
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFFF6B9D), Color(0xFFD946EF), Color(0xFFCE93D8),
    Color(0xFFFB7185), Color(0xFF69F0AE), Color(0xFF82B1FF),
    Color(0xFFFBBF24), Color(0xFF94A3B8),
  ],
  cinematicPrimary: Color(0xFFFF6B9D),
  cinematicAccent: Color(0xFFCE93D8),
  cinematicGradient: [Color(0xFF5C1040), Color(0xFFFF6B9D), Color(0xFFCE93D8), Color(0xFFF0E5F0)],
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  navigationBarColor: Color(0xFF0C0810),
  navigationBarIconBrightness: Brightness.light,
  // Dark palette — bright status colors
  statusPending: Color(0xFFFFD740),
  statusConfirmed: Color(0xFF40C4FF),
  statusCompleted: Color(0xFF69F0AE),
  statusCancelled: Color(0xFFFF6B6B),
  chartColors: [
    Color(0xFFFF6B9D),
    Color(0xFFCE93D8),
    Color(0xFF82B1FF),
    Color(0xFF69F0AE),
    Color(0xFFFBBF24),
    Color(0xFFD946EF),
    Color(0xFFFB7185),
    Color(0xFF94A3B8),
  ],
  chartGridColor: Color(0xFF2A1525),
  chartLabelColor: Color(0xFFB090B8),
);

/// Emerald Luxe LIGHT — "Art deco poster on ivory"
const emeraldLuxeLightPalette = BCPalette(
  id: 'emerald_luxe',
  nameEs: 'Esmeralda Lujosa',
  nameEn: 'Emerald Luxe',
  brightness: Brightness.light,
  headingFont: 'Cinzel',
  bodyFont: 'Raleway',
  spacingScale: 0.95,
  radiusScale: 0.6,
  primary: Color(0xFF2E7D32),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFFB8860B),
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFF5F5E8),
  onSurface: Color(0xFF1A2A1A),
  scaffoldBackground: Color(0xFFFAFAF0),
  error: Color(0xFFD32F2F),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0xFFFFFFFF),
  cardBorderColor: Color(0xFFD4C9A8),
  divider: Color(0xFFE8E0C8),
  textPrimary: Color(0xFF1A2A1A),
  textSecondary: Color(0xFF4A6040),
  textHint: Color(0xFF8A9A78),
  shimmerColor: Color(0xFFD4AF37),
  success: Color(0xFF2E7D32),
  warning: Color(0xFFF57C00),
  info: Color(0xFF1565C0),
  primaryGradient: LinearGradient(
    colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFB8860B), Color(0xFFD4AF37)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: kGoldStops,
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFE91E63), Color(0xFF2E7D32), Color(0xFF9C27B0),
    Color(0xFFFF5252), Color(0xFF00C853), Color(0xFF1565C0),
    Color(0xFFF57C00), Color(0xFF546E7A),
  ],
  cinematicPrimary: Color(0xFF2E7D32),
  cinematicAccent: Color(0xFFD4AF37),
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  navigationBarColor: Color(0xFFFAFAF0),
  navigationBarIconBrightness: Brightness.dark,
  // Light palette — default status colors are fine
  chartColors: [
    Color(0xFF2E7D32),
    Color(0xFFB8860B),
    Color(0xFF1565C0),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF00C853),
    Color(0xFFF57C00),
    Color(0xFF546E7A),
  ],
  chartGridColor: Color(0xFFE8E0C8),
  chartLabelColor: Color(0xFF4A6040),
);

// ─── Palette pairs (light + dark for each variant) ──────────────────────────

const palettePairs = <String, ({BCPalette light, BCPalette dark})>{
  'rose_gold': (light: roseGoldPalette, dark: roseGoldDarkPalette),
  'black_gold': (light: blackGoldLightPalette, dark: blackGoldPalette),
  'glass': (light: glassmorphismLightPalette, dark: glassmorphismPalette),
  'midnight_orchid': (light: midnightOrchidLightPalette, dark: midnightOrchidPalette),
  'ocean_noir': (light: oceanNoirLightPalette, dark: oceanNoirPalette),
  'cherry_blossom': (light: cherryBlossomPalette, dark: cherryBlossomDarkPalette),
  'emerald_luxe': (light: emeraldLuxeLightPalette, dark: emeraldLuxePalette),
};

// ─── Palette registry ──────────────────────────────────────────────────────

final allPalettes = <String, BCPalette>{
  roseGoldPalette.id: roseGoldPalette,
  blackGoldPalette.id: blackGoldPalette,
  glassmorphismPalette.id: glassmorphismPalette,
  midnightOrchidPalette.id: midnightOrchidPalette,
  oceanNoirPalette.id: oceanNoirPalette,
  cherryBlossomPalette.id: cherryBlossomPalette,
  emeraldLuxePalette.id: emeraldLuxePalette,
};
