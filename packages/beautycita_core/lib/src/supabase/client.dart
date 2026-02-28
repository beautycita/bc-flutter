import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase client initialization.
/// Both mobile and web apps call this during startup.
class BCSupabase {
  static bool _initialized = false;
  static bool _initAttempted = false;
  static String? _initError;
  static Future<void>? _initFuture;

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

  /// Initialize Supabase. Safe to call multiple times — returns the same
  /// cached future. Use [force] to reset and re-attempt after failure.
  /// Can be called without await to start init in the background.
  static Future<void> initialize({bool force = false}) {
    if (force) _initFuture = null;
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  static Future<void> _doInitialize() async {
    if (_initialized) return;

    _initAttempted = true;
    _initError = null;

    try {
      debugPrint('Supabase: Loading .env...');
      await dotenv.load(fileName: '.env');
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      debugPrint('Supabase: .env loaded. URL=$url, key=${anonKey.isNotEmpty ? "${anonKey.substring(0, 20)}..." : "EMPTY"}');

      if (url.isEmpty || anonKey.isEmpty || url.contains('PLACEHOLDER')) {
        _initError = 'No credentials configured (url=${url.isEmpty ? "empty" : "ok"}, key=${anonKey.isEmpty ? "empty" : "ok"})';
        debugPrint('Supabase: $_initError');
        return;
      }

      // The SDK's _init() creates the client synchronously, then awaits
      // supabaseAuth.initialize() which can hang on web (deeplink observer,
      // SharedPreferences). Timeout prevents infinite hang. Recovery below
      // detects if the client is usable despite the timeout.
      debugPrint('Supabase: Calling Supabase.initialize()...');
      await Supabase.initialize(url: url, anonKey: anonKey)
          .timeout(const Duration(seconds: 12));
      _initialized = true;
      debugPrint('Supabase: Connected to $url');
    } catch (e, st) {
      debugPrint('Supabase: Init exception: $e');
      debugPrint('Supabase: Stack: ${st.toString().split('\n').take(5).join('\n')}');
      // The SDK's _init() runs synchronously before the async auth init.
      // If timeout fires, the client may already exist and be usable.
      try {
        final _ = Supabase.instance.client;
        _initialized = true;
        _initError = null;
        debugPrint('Supabase: Recovered after exception, client usable.');
      } catch (e2) {
        _initError = e.toString();
        debugPrint('Supabase: Recovery failed ($e2). Init failed.');
      }
    }
  }

  static String? get currentUserId =>
      _initialized ? Supabase.instance.client.auth.currentUser?.id : null;

  static bool get isAuthenticated =>
      _initialized && Supabase.instance.client.auth.currentUser != null;
}
