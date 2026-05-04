// Behavior tests for BiometricPreferences.
//
// Backed by SharedPreferences in-memory mock. Verifies:
//   - default is enabled (true) when nothing is stored.
//   - setEnabled(false) persists across reads.
//   - setEnabled flips back work as expected.
//   - The default flips to enabled even if a non-bool key was previously
//     written (defensive default).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beautycita/services/biometric_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricPreferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('default is true when nothing is stored', () async {
      final prefs = BiometricPreferences();
      expect(await prefs.isEnabled(), true);
    });

    test('setEnabled(false) persists', () async {
      final prefs = BiometricPreferences();
      await prefs.setEnabled(false);
      expect(await prefs.isEnabled(), false);
    });

    test('setEnabled(true) restores after disable', () async {
      final prefs = BiometricPreferences();
      await prefs.setEnabled(false);
      await prefs.setEnabled(true);
      expect(await prefs.isEnabled(), true);
    });

    test('persists across new instances (same SharedPreferences backend)', () async {
      await BiometricPreferences().setEnabled(false);
      // Fresh instance, same SharedPreferences singleton.
      expect(await BiometricPreferences().isEnabled(), false);
    });

    test('default still true when an unrelated key exists', () async {
      SharedPreferences.setMockInitialValues({'unrelated_key': 'foo'});
      expect(await BiometricPreferences().isEnabled(), true);
    });
  });
}
