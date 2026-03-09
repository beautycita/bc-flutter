import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';

/// Creates a [ProviderContainer] with optional overrides for testing.
ProviderContainer createContainer({
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(overrides: overrides);
  return container;
}

/// Sets up the Supabase test seam with a fake user ID.
/// Call in setUp(), and call [tearDownSupabase] in tearDown().
void setUpSupabaseTestSeam({String userId = 'test-user-id'}) {
  SupabaseClientService.testUserId = userId;
}

/// Tears down the Supabase test seam.
void tearDownSupabase() {
  SupabaseClientService.testClient = null;
  SupabaseClientService.testUserId = null;
}
