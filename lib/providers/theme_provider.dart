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

  void _rebuild(BCPalette palette) {
    final effectiveRadius = _radiusScale * palette.radiusScale;
    final themeData = buildThemeFromPalette(
      palette,
      fontScale: _fontScale,
      radiusOverride: effectiveRadius,
    );
    state = ThemeState(
      themeId: palette.id,
      themeData: themeData,
      palette: palette,
      fontScale: _fontScale,
      radiusScale: _radiusScale,
      animationSpeed: _animationSpeed,
      themeMode: _themeMode,
    );
  }

  Future<void> resetAll() async {
    _fontScale = 1.0;
    _radiusScale = 1.0;
    _animationSpeed = 1.0;
    _themeMode = ThemeMode.system;
    _applyPalette(roseGoldPalette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, roseGoldPalette.id);
    await prefs.setDouble(_prefFontScale, 1.0);
    await prefs.setDouble(_prefRadiusScale, 1.0);
    await prefs.setDouble(_prefAnimSpeed, 1.0);
    await prefs.setInt(_prefThemeMode, 0);
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
