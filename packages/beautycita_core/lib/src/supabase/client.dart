import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase client initialization.
/// Both mobile and web apps call this during startup.
class BCSupabase {
  static bool _initialized = false;
  static bool _initAttempted = false;
  static String? _initError;

  static bool get isInitialized => _initialized;

  /// Whether initialization was attempted (successfully or not).
  static bool get initAttempted => _initAttempted;

  /// Whether initialization was attempted and failed.
  static bool get initFailed => _initAttempted && !_initialized;

  /// The error message from the last failed initialization attempt, if any.
  static String? get initError => _initError;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
          'Supabase not initialized. Call BCSupabase.initialize() first.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    _initAttempted = true;
    _initError = null;

    try {
      await dotenv.load(fileName: '.env');
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (url.isEmpty || anonKey.isEmpty || url.contains('PLACEHOLDER')) {
        _initError = 'No credentials configured';
        debugPrint('Supabase: No credentials configured, running offline.');
        return;
      }

      await Supabase.initialize(url: url, anonKey: anonKey)
          .timeout(const Duration(seconds: 10));
      _initialized = true;
      debugPrint('Supabase: Connected to $url');
    } on TimeoutException {
      _initError = 'Connection timed out';
      debugPrint('Supabase: Init timed out after 10s, running offline.');
    } catch (e) {
      _initError = e.toString();
      debugPrint('Supabase: Init failed ($e), running offline.');
    }
  }

  static String? get currentUserId =>
      _initialized ? Supabase.instance.client.auth.currentUser?.id : null;

  static bool get isAuthenticated =>
      _initialized && Supabase.instance.client.auth.currentUser != null;
}
