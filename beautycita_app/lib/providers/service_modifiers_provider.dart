import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita_core/supabase.dart';

/// Valid modifier tags (60056). Keep in sync with
/// migration 20260418000001_service_modifiers.sql.
const kServiceModifierTags = <String>[
  'kids_friendly',
  'accessibility_equipped',
  'senior_friendly',
  'event_specialist',
];

/// Client-side shape of the per-user service_preferences jsonb.
class ServicePreferences {
  final bool kidsFriendly;
  final bool accessibilityRequired;
  final bool? seniorFriendlyOverride; // null = auto from birthday

  const ServicePreferences({
    required this.kidsFriendly,
    required this.accessibilityRequired,
    required this.seniorFriendlyOverride,
  });

  factory ServicePreferences.empty() => const ServicePreferences(
        kidsFriendly: false,
        accessibilityRequired: false,
        seniorFriendlyOverride: null,
      );

  factory ServicePreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ServicePreferences.empty();
    final override = json['senior_friendly_override'];
    return ServicePreferences(
      kidsFriendly: json['kids_friendly'] == true,
      accessibilityRequired: json['accessibility_required'] == true,
      seniorFriendlyOverride: override is bool ? override : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'kids_friendly': kidsFriendly,
        'accessibility_required': accessibilityRequired,
        if (seniorFriendlyOverride != null)
          'senior_friendly_override': seniorFriendlyOverride,
      };

  ServicePreferences copyWith({
    bool? kidsFriendly,
    bool? accessibilityRequired,
    Object? seniorFriendlyOverride = _sentinel,
  }) =>
      ServicePreferences(
        kidsFriendly: kidsFriendly ?? this.kidsFriendly,
        accessibilityRequired:
            accessibilityRequired ?? this.accessibilityRequired,
        seniorFriendlyOverride: identical(seniorFriendlyOverride, _sentinel)
            ? this.seniorFriendlyOverride
            : seniorFriendlyOverride as bool?,
      );
}

const _sentinel = Object();

/// Reads profiles.service_preferences for the current user.
final servicePreferencesProvider =
    FutureProvider<ServicePreferences>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return ServicePreferences.empty();
  final row = await SupabaseClientService.client
      .from(BCTables.profiles)
      .select('service_preferences')
      .eq('id', userId)
      .maybeSingle();
  final prefs = row?['service_preferences'];
  if (prefs is Map) {
    return ServicePreferences.fromJson(prefs.cast<String, dynamic>());
  }
  return ServicePreferences.empty();
});

/// Writes the service_preferences jsonb back to the user's profile.
Future<void> updateServicePreferences(
  WidgetRef ref,
  ServicePreferences next,
) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return;
  await SupabaseClientService.client
      .from(BCTables.profiles)
      .update({'service_preferences': next.toJson()})
      .eq('id', userId);
  ref.invalidate(servicePreferencesProvider);
}
