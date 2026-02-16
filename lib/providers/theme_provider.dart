import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/palettes.dart';
import '../config/theme.dart';
import '../config/theme_extension.dart';

const _prefKey = 'selected_theme';

class ThemeState {
  final String themeId;
  final ThemeData themeData;
  final BCPalette palette;

  const ThemeState({
    required this.themeId,
    required this.themeData,
    required this.palette,
  });
}

class ThemeNotifier extends StateNotifier<ThemeState> {
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
    final savedId = prefs.getString(_prefKey);
    if (savedId != null && allPalettes.containsKey(savedId)) {
      _applyPalette(allPalettes[savedId]!);
    }
  }

  Future<void> setTheme(String themeId) async {
    final palette = allPalettes[themeId];
    if (palette == null) return;
    _applyPalette(palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, themeId);
  }

  void _applyPalette(BCPalette palette) {
    final themeData = buildThemeFromPalette(palette);
    state = ThemeState(
      themeId: palette.id,
      themeData: themeData,
      palette: palette,
    );
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

  Future<void> resetToDefault() async {
    await setTheme(roseGoldPalette.id);
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
