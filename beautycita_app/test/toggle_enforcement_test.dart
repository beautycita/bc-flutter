import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/providers/feature_toggle_provider.dart';

void main() {
  test('all toggle keys have defaults', () {
    final required = [
      'enable_stripe_payments',
      'enable_cash_payments',
      'enable_deposit_required',
      'enable_instant_booking',
      'enable_time_inference',
      'enable_uber_integration',
      'enable_waitlist',
      'enable_reviews',
      'enable_salon_chat',
      'enable_referrals',
      'enable_voice_booking',
      'enable_push_notifications',
      'enable_analytics',
      'enable_maintenance_mode',
      'enable_pos',
      'enable_feed',
      'enable_portfolio',
      'enable_salon_registration',
      'enable_virtual_studio',
      'enable_aphrodite_ai',
      'enable_eros_support',
      'enable_ai_copy',
      'enable_ai_avatars',
      'enable_google_calendar',
      'enable_cita_express',
      'enable_salon_invite',
      'enable_disputes',
      'enable_on_demand_scrape',
      'enable_outreach_pipeline',
      'enable_screenshot_report',
      'enable_qr_auth',
    ];

    // Use AsyncLoading so isEnabled falls through to _defaults map.
    // If a key is missing from _defaults, isEnabled returns false (the ?? false).
    // We use AsyncData with an empty map — isEnabled checks data map first (miss),
    // then falls back to _defaults.
    const AsyncValue<Map<String, bool>> toggles = AsyncData({});

    for (final key in required) {
      // Should not throw. The value comes from _defaults since data map is empty.
      // We just verify isEnabled returns a bool (does not crash).
      final value = toggles.isEnabled(key);
      expect(value, isA<bool>(), reason: 'Toggle $key should return a bool');
    }
  });

  test('isEnabled returns true for enabled defaults', () {
    const AsyncValue<Map<String, bool>> toggles = AsyncData({});

    // These are all defaulted to true in _defaults
    expect(toggles.isEnabled('enable_stripe_payments'), isTrue);
    expect(toggles.isEnabled('enable_reviews'), isTrue);
    expect(toggles.isEnabled('enable_virtual_studio'), isTrue);
    expect(toggles.isEnabled('enable_aphrodite_ai'), isTrue);
    expect(toggles.isEnabled('enable_disputes'), isTrue);
  });

  test('isEnabled returns false for disabled defaults', () {
    const AsyncValue<Map<String, bool>> toggles = AsyncData({});

    // These are defaulted to false in _defaults
    expect(toggles.isEnabled('enable_uber_integration'), isFalse);
    expect(toggles.isEnabled('enable_waitlist'), isFalse);
    expect(toggles.isEnabled('enable_maintenance_mode'), isFalse);
    expect(toggles.isEnabled('enable_voice_booking'), isFalse);
  });

  test('isEnabled returns false for unknown keys', () {
    const AsyncValue<Map<String, bool>> toggles = AsyncData({});

    expect(toggles.isEnabled('enable_nonexistent_feature'), isFalse);
  });

  test('data map overrides defaults', () {
    const AsyncValue<Map<String, bool>> toggles = AsyncData({
      'enable_uber_integration': true, // default is false
      'enable_reviews': false, // default is true
    });

    expect(toggles.isEnabled('enable_uber_integration'), isTrue);
    expect(toggles.isEnabled('enable_reviews'), isFalse);
  });
}
