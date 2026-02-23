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
  final ThemeData themeData;
  final BCPalette palette;
  final double fontScale;
  final double radiusScale;
  final double animationSpeed;
  final ThemeMode themeMode;

  const ThemeState({
    required this.themeId,
    required this.themeData,
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

    final savedId = prefs.getString(_prefKey);
    if (savedId != null && allPalettes.containsKey(savedId)) {
      _applyPalette(allPalettes[savedId]!);
    } else {
      _rebuild(state.palette);
    }
  }

  Future<void> setTheme(String themeId) async {
    final palette = allPalettes[themeId];
    if (palette == null) return;
    _applyPalette(palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, themeId);
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
    _rebuild(state.palette);
  }

  /// Persist the custom color after drag ends.
  Future<void> saveCustomColor() async {
    if (_customHue == null || _customSat == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefCustomHue, _customHue!);
    await prefs.setDouble(_prefCustomSat, _customSat!);
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

  void _rebuild(BCPalette palette) {
    final effectiveRadius = _radiusScale * palette.radiusScale;

    // Apply custom color override if set
    BCPalette effectivePalette = palette;
    if (_customHue != null && _customSat != null) {
      effectivePalette = _applyColorOverride(palette, _customHue!, _customSat!);
    }

    final themeData = buildThemeFromPalette(
      effectivePalette,
      fontScale: _fontScale,
      radiusOverride: effectiveRadius,
    );
    state = ThemeState(
      themeId: palette.id,
      themeData: themeData,
      palette: effectivePalette,
      fontScale: _fontScale,
      radiusScale: _radiusScale,
      animationSpeed: _animationSpeed,
      themeMode: _themeMode,
    );
  }

  /// Create a modified palette with custom primary color from HSV.
  BCPalette _applyColorOverride(BCPalette base, double hue, double sat) {
    final primary = HSVColor.fromAHSV(1.0, hue.clamp(0, 360), sat.clamp(0.1, 1.0), 0.5).toColor();
    // Gradient end: slightly shifted hue, higher value
    final gradEnd = HSVColor.fromAHSV(1.0, (hue + 15).clamp(0, 360), (sat * 0.8).clamp(0.1, 1.0), 0.65).toColor();
    return BCPalette(
      id: base.id,
      nameEs: base.nameEs,
      nameEn: base.nameEn,
      brightness: base.brightness,
      primary: primary,
      onPrimary: base.onPrimary,
      secondary: base.secondary,
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
      shimmerColor: base.shimmerColor,
      success: base.success,
      warning: base.warning,
      info: base.info,
      primaryGradient: LinearGradient(
        colors: [primary, gradEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      accentGradient: base.accentGradient,
      goldGradientStops: base.goldGradientStops,
      goldGradientPositions: base.goldGradientPositions,
      categoryColors: base.categoryColors,
      headingFont: base.headingFont,
      bodyFont: base.bodyFont,
      spacingScale: base.spacingScale,
      radiusScale: base.radiusScale,
      blurSigma: base.blurSigma,
      glassTint: base.glassTint,
      glassBorderOpacity: base.glassBorderOpacity,
      cinematicPrimary: primary,
      cinematicAccent: base.cinematicAccent,
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
    _applyPalette(roseGoldPalette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, roseGoldPalette.id);
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
  return ref.watch(themeProvider).themeData.extension<BCThemeExtension>()!;
});
