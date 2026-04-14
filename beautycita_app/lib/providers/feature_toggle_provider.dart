import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';

/// Default values for feature toggles (used while loading or if fetch fails).
/// Existing features default to true so they don't flash away on load.
const _defaults = <String, bool>{
  // Payments
  'enable_stripe_payments': true,
  'enable_cash_payments': true,
  'enable_deposit_required': true,
  // Booking
  'enable_time_inference': true,
  'enable_uber_integration': true,
  // Social
  'enable_reviews': true,
  'enable_salon_chat': true,
  'enable_referrals': true,
  // Platform
  'enable_push_notifications': true,
  'enable_no_show_processing': true,
  'enable_maintenance_mode': false,
  // Marketplace
  'enable_pos': true,
  'enable_feed': true,
  'enable_portfolio': true,
  'enable_gift_cards': true,
  'enable_marketing_automation': true,
  'enable_loyalty': true,
  // Registration
  'enable_salon_registration': false,
  // AI & Studio
  'enable_virtual_studio': true,
  'enable_aphrodite_ai': true,
  'enable_eros_support': true,
  'enable_ai_avatars': true,
  // Integrations
  'enable_google_calendar': true,
  'enable_cita_express': true,
  'enable_salon_invite': true,
  // Operations
  'enable_disputes': true,
  'enable_on_demand_scrape': true,
  'enable_outreach_pipeline': true,
  'enable_screenshot_report': false,
  'enable_qr_auth': true,
  'enable_contact_match': true,
  // UI Experiments
  'enable_photo_category_cards': true,
  'enable_haptic_feedback': true,
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
