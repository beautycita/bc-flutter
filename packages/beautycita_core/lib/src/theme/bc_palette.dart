import 'dart:ui' show Brightness, Color;

import 'package:flutter/painting.dart' show LinearGradient;

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
