import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase client initialization.
/// Both mobile and web apps call this during startup.
class BCSupabase {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
          'Supabase not initialized. Call BCSupabase.initialize() first.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await dotenv.load(fileName: '.env');
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (url.isEmpty || anonKey.isEmpty || url.contains('PLACEHOLDER')) {
        debugPrint('Supabase: No credentials configured, running offline.');
        return;
      }

      await Supabase.initialize(url: url, anonKey: anonKey);
      _initialized = true;
      debugPrint('Supabase: Connected to $url');
    } catch (e) {
      debugPrint('Supabase: Init failed ($e), running offline.');
    }
  }

  static String? get currentUserId =>
      _initialized ? Supabase.instance.client.auth.currentUser?.id : null;

  static bool get isAuthenticated =>
      _initialized && Supabase.instance.client.auth.currentUser != null;
}
