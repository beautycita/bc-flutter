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
    _rebuildFromCurrentTheme();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefFontScale, scale);
  }

  Future<void> setRadiusScale(double scale) async {
    _radiusScale = scale;
    _rebuildFromCurrentTheme();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefRadiusScale, scale);
  }

  Future<void> setAnimationSpeed(double speed) async {
    _animationSpeed = speed;
    _rebuildFromCurrentTheme();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefAnimSpeed, speed);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _rebuildFromCurrentTheme();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefThemeMode, mode.index);
  }

  /// Re-resolve effective palette from the current base theme ID.
  void _rebuildFromCurrentTheme() {
    final basePalette = allPalettes[state.themeId] ?? state.palette;
    _applyPalette(basePalette);
  }

  void _applyPalette(BCPalette palette) {
    _rebuild(palette);
    // Update system UI chrome from the effective (resolved) palette
    final effective = state.palette;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: effective.statusBarColor,
      statusBarIconBrightness: effective.statusBarIconBrightness,
      statusBarBrightness: effective.brightness == Brightness.light
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: effective.navigationBarColor,
      systemNavigationBarIconBrightness: effective.navigationBarIconBrightness,
    ));
  }

  /// Resolve the effective palette based on _themeMode, then build ThemeData.
  void _rebuild(BCPalette basePalette) {
    final pair = palettePairs[basePalette.id];
    BCPalette effectivePalette;
    if (pair != null) {
      switch (_themeMode) {
        case ThemeMode.light:
          effectivePalette = pair.light;
        case ThemeMode.dark:
          effectivePalette = pair.dark;
        case ThemeMode.system:
          // Use platform brightness; default to palette's native brightness
          final platformBrightness =
              WidgetsBinding.instance.platformDispatcher.platformBrightness;
          effectivePalette = platformBrightness == Brightness.light
              ? pair.light
              : pair.dark;
      }
    } else {
      effectivePalette = basePalette;
    }

    final effectiveRadius = _radiusScale * effectivePalette.radiusScale;
    final themeData = buildThemeFromPalette(
      effectivePalette,
      fontScale: _fontScale,
      radiusOverride: effectiveRadius,
    );
    state = ThemeState(
      themeId: basePalette.id, // keep base ID for variant routing
      themeData: themeData,
      palette: effectivePalette,
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
