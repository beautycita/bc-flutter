// Behavior tests for the FeatureToggles extension on AsyncValue.
//
// The provider itself talks to Supabase and is exercised by integration
// tests. This file pins the loading-state / error-state / data-state
// fallback semantics that every consumer depends on:
//
//   - During loading or on error, the consumer must see the hard-coded
//     defaults (so toggle-gated UI doesn't flash away on app start).
//   - When data is present but missing a key, fall back to defaults.
//   - When data is present with a key, the data value wins.
//   - Unknown keys (not in data, not in defaults) return false.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/providers/feature_toggle_provider.dart';

void main() {
  group('FeatureToggles.isEnabled', () {
    group('loading state — should return defaults', () {
      const loading = AsyncValue<Map<String, bool>>.loading();

      test('default-true toggle returns true while loading', () {
        // enable_qr_auth defaults to true.
        expect(loading.isEnabled('enable_qr_auth'), true);
      });

      test('default-false toggle returns false while loading', () {
        // enable_maintenance_mode defaults to false.
        expect(loading.isEnabled('enable_maintenance_mode'), false);
      });

      test('completely unknown key returns false while loading', () {
        expect(loading.isEnabled('not_a_real_toggle'), false);
      });
    });

    group('error state — should return defaults', () {
      final err = AsyncValue<Map<String, bool>>.error(
        Exception('network down'),
        StackTrace.empty,
      );

      test('default-true toggle returns true on error', () {
        expect(err.isEnabled('enable_stripe_payments'), true);
      });

      test('default-false toggle returns false on error', () {
        expect(err.isEnabled('enable_salon_registration'), false);
      });

      test('unknown key returns false on error', () {
        expect(err.isEnabled('foo_bar'), false);
      });
    });

    group('data state — server values win over defaults', () {
      test('server says false overrides default-true', () {
        const data = AsyncValue<Map<String, bool>>.data({
          'enable_qr_auth': false,
        });
        expect(data.isEnabled('enable_qr_auth'), false);
      });

      test('server says true overrides default-false', () {
        const data = AsyncValue<Map<String, bool>>.data({
          'enable_maintenance_mode': true,
        });
        expect(data.isEnabled('enable_maintenance_mode'), true);
      });

      test('key absent from data falls back to default', () {
        // Empty map; isEnabled should still return the hard-coded default.
        const data = AsyncValue<Map<String, bool>>.data({});
        expect(data.isEnabled('enable_pos'), true);
        expect(data.isEnabled('enable_maintenance_mode'), false);
      });

      test('unknown key with no default returns false', () {
        const data = AsyncValue<Map<String, bool>>.data({});
        expect(data.isEnabled('completely_unknown_xyz'), false);
      });
    });

    group('mixed data state', () {
      test('returns server value for keys present, default for keys absent', () {
        const data = AsyncValue<Map<String, bool>>.data({
          'enable_qr_auth': false,
          'enable_pos': false,
        });
        expect(data.isEnabled('enable_qr_auth'), false); // server override
        expect(data.isEnabled('enable_pos'), false);     // server override
        expect(data.isEnabled('enable_stripe_payments'), true); // default
        expect(data.isEnabled('enable_maintenance_mode'), false); // default
      });
    });
  });
}
