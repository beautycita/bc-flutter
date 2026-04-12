import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beautycita/providers/theme_provider.dart';
import 'package:beautycita/config/palettes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeNotifier', () {
    late ThemeNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      notifier = ThemeNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('initial state uses beautycitaPalette', () {
      expect(notifier.state.themeId, beautycitaPalette.id);
      expect(notifier.state.palette.id, beautycitaPalette.id);
    });

    test('initial fontScale is 1.0', () {
      expect(notifier.state.fontScale, 1.0);
    });

    test('initial radiusScale is 1.0', () {
      expect(notifier.state.radiusScale, 1.0);
    });

    test('initial animationSpeed is 1.0', () {
      expect(notifier.state.animationSpeed, 1.0);
    });

    test('initial themeMode is light', () {
      expect(notifier.state.themeMode, ThemeMode.light);
    });

    group('setFontScale', () {
      test('updates fontScale in state', () async {
        await notifier.setFontScale(1.5);
        expect(notifier.state.fontScale, 1.5);
      });

      test('persists to SharedPreferences', () async {
        await notifier.setFontScale(1.3);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('font_scale'), 1.3);
      });
    });

    group('setRadiusScale', () {
      test('updates radiusScale in state', () async {
        await notifier.setRadiusScale(0.5);
        expect(notifier.state.radiusScale, 0.5);
      });
    });

    group('setAnimationSpeed', () {
      test('updates animationSpeed in state', () async {
        await notifier.setAnimationSpeed(2.0);
        expect(notifier.state.animationSpeed, 2.0);
      });
    });

    group('setThemeMode', () {
      test('switches to dark mode', () async {
        await notifier.setThemeMode(ThemeMode.dark);
        expect(notifier.state.themeMode, ThemeMode.dark);
      });

      test('switches to light mode', () async {
        await notifier.setThemeMode(ThemeMode.light);
        expect(notifier.state.themeMode, ThemeMode.light);
      });

      test('persists mode to SharedPreferences', () async {
        await notifier.setThemeMode(ThemeMode.dark);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('theme_mode'), ThemeMode.dark.index);
      });
    });

    group('setTheme', () {
      test('single palette — setTheme is no-op, stays on beautycitaPalette', () async {
        final originalId = notifier.state.themeId;

        await runZonedGuarded(() async {
          notifier.setTheme('any_id');
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }, (_, _) {});

        // Single palette — always stays on beautycitaPalette
        expect(notifier.state.themeId, originalId);
      });
    });

    group('custom color', () {
      test('hasCustomColor is true initially (lila default)', () {
        // _load() sets _customHue/_customSat to lila defaults when no prefs saved
        expect(notifier.hasCustomColor, isTrue);
      });

      test('setCustomColorLive updates state without persistence', () async {
        notifier.setCustomColorLive(180.0, 0.7);

        expect(notifier.hasCustomColor, isTrue);
        expect(notifier.customHue, 180.0);
        expect(notifier.customSat, 0.7);

        // Should NOT be in SharedPreferences yet
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('custom_hue'), isNull);
      });

      test('saveCustomColor persists to SharedPreferences', () async {
        notifier.setCustomColorLive(200.0, 0.6);
        await notifier.saveCustomColor();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('custom_hue'), 200.0);
        expect(prefs.getDouble('custom_sat'), 0.6);
      });

      test('clearCustomColor removes override', () async {
        notifier.setCustomColorLive(200.0, 0.6);
        await notifier.saveCustomColor();

        await notifier.clearCustomColor();

        expect(notifier.hasCustomColor, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('custom_hue'), isNull);
        expect(prefs.getDouble('custom_sat'), isNull);
      });
    });

    group('category color offsets', () {
      test('basePrimaryHue is computed from palette primary', () {
        expect(notifier.basePrimaryHue, isNotNaN);
      });

      test('category hue offsets match palette category count', () {
        expect(
          notifier.categoryHueOffsets.length,
          notifier.state.palette.categoryColors.length,
        );
      });
    });

    group('resetAll', () {
      test('restores all defaults', () async {
        // Change everything
        await notifier.setFontScale(2.0);
        await notifier.setRadiusScale(0.5);
        await notifier.setAnimationSpeed(3.0);
        await notifier.setThemeMode(ThemeMode.dark);
        notifier.setCustomColorLive(100.0, 0.5);
        await notifier.saveCustomColor();

        // Reset
        await notifier.resetAll();

        expect(notifier.state.fontScale, 1.0);
        expect(notifier.state.radiusScale, 1.0);
        expect(notifier.state.animationSpeed, 1.0);
        expect(notifier.state.themeMode, ThemeMode.light);
        expect(notifier.hasCustomColor, isFalse);
        expect(notifier.state.themeId, beautycitaPalette.id);
      });

      test('clears SharedPreferences custom color keys', () async {
        notifier.setCustomColorLive(100.0, 0.5);
        await notifier.saveCustomColor();
        await notifier.resetAll();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('custom_hue'), isNull);
        expect(prefs.getDouble('custom_sat'), isNull);
      });
    });
  });
}
