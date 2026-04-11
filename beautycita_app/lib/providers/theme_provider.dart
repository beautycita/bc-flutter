import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/palettes.dart';
import '../config/theme.dart';
import '../config/theme_extension.dart';

const _prefKey = 'selected_theme';
const _prefFontScale = 'font_scale';
const _prefRadiusScale = 'radius_scale';
const _prefAnimSpeed = 'animation_speed';
const _prefThemeMode = 'theme_mode';
const _prefCustomHue = 'custom_hue';
const _prefCustomSat = 'custom_sat';

class ThemeState {
  final String themeId;
  final ThemeData lightThemeData;
  final ThemeData darkThemeData;
  final BCPalette palette;
  final double fontScale;
  final double radiusScale;
  final double animationSpeed;
  final ThemeMode themeMode;

  /// Backward-compat alias — returns the light theme.
  ThemeData get themeData => lightThemeData;

  const ThemeState({
    required this.themeId,
    required this.lightThemeData,
    required this.darkThemeData,
    required this.palette,
    this.fontScale = 1.0,
    this.radiusScale = 1.0,
    this.animationSpeed = 1.0,
    this.themeMode = ThemeMode.system,
  });
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  double _fontScale = 1.0;
  double _radiusScale = 1.0;
  double _animationSpeed = 1.0;
  ThemeMode _themeMode = ThemeMode.system;
  double? _customHue;
  double? _customSat;
  List<Color>? _customGradientColors;

  // Pre-cached category color offsets — computed once per palette, not per drag tick.
  double _basePrimaryHue = 0;
  List<double> _catHueOffsets = [];
  List<double> _catSaturations = [];
  List<double> _catLightnesses = [];

  // Memoization cache for _rebuild — avoids recomputing palette + ThemeData
  // when inputs haven't changed (e.g. redundant rebuilds, same-value drags).
  String? _lastRebuildKey;
  BCPalette? _lastEffectivePalette;
  ThemeData? _lastLightThemeData;
  ThemeData? _lastDarkThemeData;

  ThemeNotifier()
      : super(ThemeState(
          themeId: beautycitaPalette.id,
          lightThemeData: buildThemeFromPalette(beautycitaPalette),
          darkThemeData: buildThemeFromPalette(beautycitaDarkPalette),
          palette: beautycitaPalette,
        )) {
    _cacheCategoryOffsets(beautycitaPalette);
    _load();
  }

  /// Compute and cache hue offsets from base primary for each category color.
  /// Called once when palette changes, not on every drag tick.
  /// Sat/lightness are normalized to vibrant, readable ranges so hue-shifted
  /// categories never look muddy (e.g. hair=0.18sat → clamped to 0.50).
  void _cacheCategoryOffsets(BCPalette palette) {
    // Invalidate memoization cache — category offsets changed.
    _lastRebuildKey = null;
    final baseHsl = HSLColor.fromColor(palette.primary);
    _basePrimaryHue = baseHsl.hue;
    _catHueOffsets = [];
    _catSaturations = [];
    _catLightnesses = [];
    for (final c in palette.categoryColors) {
      final hsl = HSLColor.fromColor(c);
      _catHueOffsets.add(hsl.hue - _basePrimaryHue);
      _catSaturations.add(hsl.saturation.clamp(0.50, 0.80));
      _catLightnesses.add(hsl.lightness.clamp(0.40, 0.55));
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _fontScale = prefs.getDouble(_prefFontScale) ?? 1.0;
    _radiusScale = prefs.getDouble(_prefRadiusScale) ?? 1.0;
    _animationSpeed = prefs.getDouble(_prefAnimSpeed) ?? 1.0;
    final modeIndex = prefs.getInt(_prefThemeMode) ?? 0;
    _themeMode = ThemeMode.values[modeIndex.clamp(0, ThemeMode.values.length - 1)];
    final savedHue = prefs.getDouble(_prefCustomHue);
    final savedSat = prefs.getDouble(_prefCustomSat);
    if (savedHue != null && savedSat != null) {
      _customHue = savedHue;
      _customSat = savedSat;
    }

    // Single palette — no palette switching. Always use beautycitaPalette.
    final palette = beautycitaPalette;

    // Default to lila/lilac (#C8A2C8) gradient for all installations.
    // This is the brand color — locked, not user-changeable.
    if (_customHue == null || _customSat == null) {
      const lilaColor = Color(0xFFC8A2C8);
      final hsl = HSLColor.fromColor(lilaColor);
      _customHue = hsl.hue;
      _customSat = hsl.saturation;
    }

    _applyPalette(palette);
  }

  Future<void> setTheme(String themeId) async {
    // Single palette — theme switching removed.
    _applyPalette(beautycitaPalette);
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    _rebuild(state.palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefFontScale, scale);
  }

  Future<void> setRadiusScale(double scale) async {
    _radiusScale = scale;
    _rebuild(state.palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefRadiusScale, scale);
  }

  Future<void> setAnimationSpeed(double speed) async {
    _animationSpeed = speed;
    _rebuild(state.palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefAnimSpeed, speed);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _rebuild(state.palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefThemeMode, mode.index);
  }

  void _applyPalette(BCPalette palette) {
    _cacheCategoryOffsets(palette);
    _rebuild(palette);
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

  /// Live update during drag — no persistence, just rebuild.
  void setCustomColorLive(double hue, double sat) {
    _customHue = hue;
    _customSat = sat;
    _customGradientColors = null; // Clear multi-color gradient
    _rebuild(state.palette);
  }

  /// Set a full custom gradient with any number of color stops.
  /// Used by avatar style selector for multi-color gradients.
  void setCustomGradient(List<Color> colors) {
    _customGradientColors = colors;
    // Also update hue/sat from first color for consistency
    final hsl = HSLColor.fromColor(colors.first);
    _customHue = hsl.hue;
    _customSat = hsl.saturation;
    _rebuild(state.palette);
  }

  /// Persist the custom color after drag ends.
  Future<void> saveCustomColor() async {
    final hue = _customHue;
    final sat = _customSat;
    if (hue == null || sat == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefCustomHue, hue);
    await prefs.setDouble(_prefCustomSat, sat);
  }

  /// Clear custom color override (restore palette default).
  Future<void> clearCustomColor() async {
    _customHue = null;
    _customSat = null;
    _rebuild(state.palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefCustomHue);
    await prefs.remove(_prefCustomSat);
  }

  /// Whether user has a custom color active.
  bool get hasCustomColor => _customHue != null && _customSat != null;
  double? get customHue => _customHue;
  double? get customSat => _customSat;

  /// Exposed for live color computation (bypasses ThemeData during drag).
  double get basePrimaryHue => _basePrimaryHue;
  List<double> get categoryHueOffsets => _catHueOffsets;
  List<double> get categorySaturations => _catSaturations;
  List<double> get categoryLightnesses => _catLightnesses;

  void _rebuild(BCPalette palette) {
    final effectiveRadius = _radiusScale * palette.radiusScale;

    // Build a cache key from all inputs that affect palette + ThemeData.
    // Avoids redundant HSL math + ThemeData construction on duplicate calls.
    final cacheKey = '${palette.id}|$_customHue|$_customSat|$_fontScale|$effectiveRadius|${_customGradientColors?.length}';

    BCPalette effectivePalette;
    ThemeData lightThemeData;
    ThemeData darkThemeData;

    if (cacheKey == _lastRebuildKey && _lastEffectivePalette != null && _lastLightThemeData != null && _lastDarkThemeData != null) {
      effectivePalette = _lastEffectivePalette!;
      lightThemeData = _lastLightThemeData!;
      darkThemeData = _lastDarkThemeData!;
    } else {
      // ── Light theme ──
      effectivePalette = palette;
      if (_customHue != null && _customSat != null) {
        effectivePalette = _applyColorOverride(palette, _customHue!, _customSat!);
      }

      lightThemeData = buildThemeFromPalette(
        effectivePalette,
        fontScale: _fontScale,
        radiusOverride: effectiveRadius,
      );

      // ── Dark theme ──
      final darkBase = beautycitaDarkPalette;
      final darkEffective = (_customHue != null && _customSat != null)
          ? _applyColorOverride(darkBase, _customHue!, _customSat!)
          : darkBase;
      final darkRadius = _radiusScale * darkBase.radiusScale;

      darkThemeData = buildThemeFromPalette(
        darkEffective,
        fontScale: _fontScale,
        radiusOverride: darkRadius,
      );

      _lastRebuildKey = cacheKey;
      _lastEffectivePalette = effectivePalette;
      _lastLightThemeData = lightThemeData;
      _lastDarkThemeData = darkThemeData;
    }

    state = ThemeState(
      themeId: palette.id,
      lightThemeData: lightThemeData,
      darkThemeData: darkThemeData,
      palette: effectivePalette,
      fontScale: _fontScale,
      radiusScale: _radiusScale,
      animationSpeed: _animationSpeed,
      themeMode: _themeMode,
    );
  }

  /// Create a modified palette with custom primary color from HSV.
  /// Category colors use pre-cached hue offsets with normalized sat/light.
  /// Secondary and accent colors shift proportionally to maintain harmony.
  BCPalette _applyColorOverride(BCPalette base, double hue, double sat) {
    final clampedSat = sat.clamp(0.1, 1.0);
    // Use HSL at lightness 0.45 — same formula as home screen _gradientPair()
    // so buttons/text match the header gradient from first frame.
    final primary = HSLColor.fromAHSL(1.0, hue.clamp(0, 360), clampedSat.clamp(0.5, 1.0), 0.45).toColor();
    final gradEnd = HSLColor.fromAHSL(1.0, (hue + 15) % 360, (clampedSat * 0.8).clamp(0.4, 0.9), 0.40).toColor();

    // Shift secondary color by the same hue delta to maintain harmony
    final hueDelta = hue - _basePrimaryHue;
    final baseSecHsl = HSLColor.fromColor(base.secondary);
    final secHue = (baseSecHsl.hue + hueDelta) % 360;
    final secondary = HSLColor.fromAHSL(
      1.0, secHue < 0 ? secHue + 360 : secHue,
      baseSecHsl.saturation.clamp(0.50, 0.90),
      baseSecHsl.lightness,
    ).toColor();

    // Category colors: use pre-cached offsets + normalized sat/lightness
    final shiftedCategories = List<Color>.generate(_catHueOffsets.length, (i) {
      var newHue = (_basePrimaryHue + _catHueOffsets[i] + hueDelta) % 360;
      if (newHue < 0) newHue += 360;
      return HSLColor.fromAHSL(1.0, newHue, _catSaturations[i], _catLightnesses[i]).toColor();
    });

    return BCPalette(
      id: base.id,
      nameEs: base.nameEs,
      nameEn: base.nameEn,
      brightness: base.brightness,
      primary: primary,
      onPrimary: base.onPrimary,
      secondary: secondary,
      onSecondary: base.onSecondary,
      surface: base.surface,
      onSurface: base.onSurface,
      scaffoldBackground: base.scaffoldBackground,
      error: base.error,
      onError: base.onError,
      cardColor: base.cardColor,
      cardBorderColor: base.cardBorderColor,
      divider: base.divider,
      textPrimary: base.textPrimary,
      textSecondary: base.textSecondary,
      textHint: base.textHint,
      shimmerColor: secondary,
      success: base.success,
      warning: base.warning,
      info: base.info,
      primaryGradient: LinearGradient(
        colors: _customGradientColors ?? [primary, gradEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGradient: LinearGradient(
        colors: _customGradientColors != null && _customGradientColors!.length >= 2
            ? [_customGradientColors![(_customGradientColors!.length * 0.3).round()], _customGradientColors!.last]
            : [secondary, gradEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      goldGradientStops: base.goldGradientStops,
      goldGradientPositions: base.goldGradientPositions,
      categoryColors: shiftedCategories,
      headingFont: base.headingFont,
      bodyFont: base.bodyFont,
      spacingScale: base.spacingScale,
      radiusScale: base.radiusScale,
      blurSigma: base.blurSigma,
      glassTint: base.glassTint,
      glassBorderOpacity: base.glassBorderOpacity,
      cinematicPrimary: primary,
      cinematicAccent: secondary,
      cinematicGradient: base.cinematicGradient,
      statusBarColor: base.statusBarColor,
      statusBarIconBrightness: base.statusBarIconBrightness,
      navigationBarColor: base.navigationBarColor,
      navigationBarIconBrightness: base.navigationBarIconBrightness,
    );
  }

  Future<void> resetAll() async {
    _fontScale = 1.0;
    _radiusScale = 1.0;
    _animationSpeed = 1.0;
    _themeMode = ThemeMode.system;
    _customHue = null;
    _customSat = null;
    _applyPalette(beautycitaPalette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, beautycitaPalette.id);
    await prefs.setDouble(_prefFontScale, 1.0);
    await prefs.setDouble(_prefRadiusScale, 1.0);
    await prefs.setDouble(_prefAnimSpeed, 1.0);
    await prefs.setInt(_prefThemeMode, 0);
    await prefs.remove(_prefCustomHue);
    await prefs.remove(_prefCustomSat);
  }

  Future<void> resetToDefault() async {
    await resetAll();
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
  final ext = ref.watch(themeProvider).themeData.extension<BCThemeExtension>();
  if (ext == null) {
    throw StateError('BCThemeExtension missing from ThemeData — check buildThemeFromPalette');
  }
  return ext;
});

/// Live color picker state — lightweight, bypasses ThemeData during drag.
/// Null when not actively dragging.
final liveHueProvider = StateProvider<double?>((ref) => null);
final liveSatProvider = StateProvider<double?>((ref) => null);
