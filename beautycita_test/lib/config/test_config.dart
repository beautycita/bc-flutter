/// Configuration for the test suite.
/// All sensitive values come from dart-define at build time.
class TestConfig {
  static const supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const supabaseServiceKey =
      String.fromEnvironment('SUPABASE_SERVICE_KEY', defaultValue: '');
  static const supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const satApiKey =
      String.fromEnvironment('SAT_API_KEY', defaultValue: '');
  static const satApiSecret =
      String.fromEnvironment('SAT_API_SECRET', defaultValue: '');
  static const docUrl =
      String.fromEnvironment('DOC_URL', defaultValue: 'http://192.168.0.21:3101');

  /// The superadmin email that must authenticate before tests run.
  static const superadminEmail = 'kriket-admin@beautycita.com';

  /// Edge function base URL (derived from supabaseUrl).
  static String get functionsUrl {
    if (supabaseUrl.isEmpty) return '';
    // beautycita.com/supabase → beautycita.com/supabase/functions/v1
    return '$supabaseUrl/functions/v1';
  }

  /// Direct DB access via PostgREST (service role).
  static String get restUrl {
    if (supabaseUrl.isEmpty) return '';
    return '$supabaseUrl/rest/v1';
  }

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseServiceKey.isNotEmpty;
}
