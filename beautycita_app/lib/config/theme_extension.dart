import 'package:flutter/material.dart';

/// Extended theme tokens that don't fit in standard ThemeData.
/// Access via: `Theme.of(context).extension<BCThemeExtension>()!`
class BCThemeExtension extends ThemeExtension<BCThemeExtension> {
  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;
  final List<Color> accentGradientStops;
  final List<double> accentGradientPositions;
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

  // Typography
  final String headingFont;
  final String bodyFont;

  // Extra palette colors not in ColorScheme
  final Color cardBorderColor;
  final Color shimmerColor;
  final Color successColor;
  final Color warningColor;
  final Color infoColor;

  const BCThemeExtension({
    required this.primaryGradient,
    required this.accentGradient,
    required this.accentGradientStops,
    required this.accentGradientPositions,
    required this.categoryColors,
    this.blurSigma,
    this.glassTint,
    this.glassBorderOpacity,
    required this.cinematicPrimary,
    required this.cinematicAccent,
    this.cinematicGradient,
    this.spacingScale = 1.0,
    this.radiusScale = 1.0,
    this.headingFont = 'Poppins',
    this.bodyFont = 'Nunito',
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

  /// Convenience: build a LinearGradient from the accent stops.
  LinearGradient get accentShimmerGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: accentGradientStops,
        stops: accentGradientPositions,
      );

  /// Convenience: build an accent gradient in any direction.
  LinearGradient accentShimmerGradientDirectional({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) =>
      LinearGradient(
        begin: begin,
        end: end,
        colors: accentGradientStops,
        stops: accentGradientPositions,
      );

  @override
  BCThemeExtension copyWith({
    LinearGradient? primaryGradient,
    LinearGradient? accentGradient,
    List<Color>? accentGradientStops,
    List<double>? accentGradientPositions,
    List<Color>? categoryColors,
    double? blurSigma,
    Color? glassTint,
    double? glassBorderOpacity,
    Color? cinematicPrimary,
    Color? cinematicAccent,
    List<Color>? cinematicGradient,
    double? spacingScale,
    double? radiusScale,
    String? headingFont,
    String? bodyFont,
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
      accentGradientStops: accentGradientStops ?? this.accentGradientStops,
      accentGradientPositions: accentGradientPositions ?? this.accentGradientPositions,
      categoryColors: categoryColors ?? this.categoryColors,
      blurSigma: blurSigma ?? this.blurSigma,
      glassTint: glassTint ?? this.glassTint,
      glassBorderOpacity: glassBorderOpacity ?? this.glassBorderOpacity,
      cinematicPrimary: cinematicPrimary ?? this.cinematicPrimary,
      cinematicAccent: cinematicAccent ?? this.cinematicAccent,
      cinematicGradient: cinematicGradient ?? this.cinematicGradient,
      spacingScale: spacingScale ?? this.spacingScale,
      radiusScale: radiusScale ?? this.radiusScale,
      headingFont: headingFont ?? this.headingFont,
      bodyFont: bodyFont ?? this.bodyFont,
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
      accentGradientStops: t < 0.5 ? accentGradientStops : other.accentGradientStops,
      accentGradientPositions: t < 0.5 ? accentGradientPositions : other.accentGradientPositions,
      categoryColors: t < 0.5 ? categoryColors : other.categoryColors,
      blurSigma: t < 0.5 ? blurSigma : other.blurSigma,
      glassTint: Color.lerp(glassTint, other.glassTint, t),
      glassBorderOpacity: t < 0.5 ? glassBorderOpacity : other.glassBorderOpacity,
      cinematicPrimary: Color.lerp(cinematicPrimary, other.cinematicPrimary, t)!,
      cinematicAccent: Color.lerp(cinematicAccent, other.cinematicAccent, t)!,
      cinematicGradient: t < 0.5 ? cinematicGradient : other.cinematicGradient,
      spacingScale: spacingScale + (other.spacingScale - spacingScale) * t,
      radiusScale: radiusScale + (other.radiusScale - radiusScale) * t,
      headingFont: t < 0.5 ? headingFont : other.headingFont,
      bodyFont: t < 0.5 ? bodyFont : other.bodyFont,
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
