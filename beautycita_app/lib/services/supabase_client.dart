import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientService {
  static bool _initialized = false;

  /// Test seam: override with a mock SupabaseClient in tests.
  @visibleForTesting
  static SupabaseClient? testClient;

  /// Test seam: override with a fake user ID in tests.
  @visibleForTesting
  static String? testUserId;

  static bool get isInitialized => testClient != null || _initialized;

  static SupabaseClient get client {
    if (testClient != null) return testClient!;
    if (!_initialized) {
      throw StateError('Supabase not initialized. Call initialize() first.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (url.isEmpty || key.isEmpty || url.contains('PLACEHOLDER')) {
        if (kDebugMode) debugPrint('Supabase: No credentials configured, running offline.');
        return;
      }

      await Supabase.initialize(url: url, anonKey: key);
      _initialized = true;
      if (kDebugMode) debugPrint('Supabase: Connected to $url');
    } catch (e) {
      if (kDebugMode) debugPrint('Supabase: Init failed ($e), running offline.');
    }
  }

  static String? get currentUserId =>
      testUserId ?? (_initialized ? Supabase.instance.client.auth.currentUser?.id : null);

  static bool get isAuthenticated =>
      testUserId != null || (_initialized && Supabase.instance.client.auth.currentUser != null);
}
