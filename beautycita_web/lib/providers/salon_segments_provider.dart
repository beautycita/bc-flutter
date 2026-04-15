import 'package:beautycita_core/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fetches computed salon segments from the DB RPC.
/// Cached — invalidate to refresh.
final salonSegmentsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  if (!BCSupabase.isInitialized) return {};
  final user = BCSupabase.client.auth.currentUser;
  if (user == null) return {};

  try {
    final result = await BCSupabase.client.rpc('compute_salon_segments');
    return (result as Map<String, dynamic>?) ?? {};
  } catch (e) {
    debugPrint('[salonSegments] error: $e');
    return {};
  }
});
