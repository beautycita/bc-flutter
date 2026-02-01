import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientService {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient? get client =>
      _initialized ? Supabase.instance.client : null;

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (url.isEmpty || key.isEmpty || url.contains('PLACEHOLDER')) {
        debugPrint('Supabase: No credentials configured, running offline.');
        return;
      }

      await Supabase.initialize(url: url, anonKey: key);
      _initialized = true;
      debugPrint('Supabase: Connected to $url');
    } catch (e) {
      debugPrint('Supabase: Init failed ($e), running offline.');
    }
  }

  static String? get currentUserId => client?.auth.currentUser?.id;

  static bool get isAuthenticated => client?.auth.currentUser != null;
}
