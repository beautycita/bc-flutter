import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';

/// Default values for feature toggles (used while loading or if fetch fails).
/// Existing features default to true so they don't flash away on load.
const _defaults = <String, bool>{
  // Payments
  'enable_stripe_payments': true,
  'enable_btc_payments': true,
  'enable_cash_payments': true,
  'enable_deposit_required': false,
  // Booking
  'enable_instant_booking': true,
  'enable_time_inference': true,
  'enable_uber_integration': false,
  'enable_waitlist': false,
  // Social
  'enable_reviews': true,
  'enable_salon_chat': true,
  'enable_referrals': true,
  // Experimental
  'enable_virtual_studio': false,
  'enable_ai_recommendations': false,
  'enable_voice_booking': false,
  // Platform
  'enable_push_notifications': true,
  'enable_analytics': true,
  'enable_maintenance_mode': false,
  // Marketplace
  'enable_pos': true,
  'enable_feed': true,
  'enable_portfolio': true,
};

/// Fetches all boolean feature toggles from app_config and returns a map.
final featureTogglesProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  if (!SupabaseClientService.isInitialized) return Map.of(_defaults);

  try {
    final data = await SupabaseClientService.client
        .from('app_config')
        .select('key, value')
        .eq('data_type', 'bool');

    final result = Map.of(_defaults);
    for (final row in (data as List)) {
      result[row['key'] as String] = (row['value'] as String) == 'true';
    }
    return result;
  } catch (_) {
    return Map.of(_defaults);
  }
});

/// Convenience extension for reading toggle values.
extension FeatureToggles on AsyncValue<Map<String, bool>> {
  /// Returns toggle value, falling back to [_defaults] while loading or on error.
  bool isEnabled(String key) {
    return whenOrNull(data: (map) => map[key]) ?? _defaults[key] ?? false;
  }
}
