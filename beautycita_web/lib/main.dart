import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Clean URLs — no #/ hash

  await initializeDateFormatting('es');

  // Start Supabase init WITHOUT awaiting — lets Flutter render immediately
  // so the splash screen shows. The login page awaits the same future.
  BCSupabase.initialize();

  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN',
          defaultValue: 'https://3ffa879e65080eaec1b7c016dd390e64@o4510248503869440.ingest.us.sentry.io/4510248532049921');
      options.environment = kDebugMode ? 'debug' : 'production';
      options.release = 'beautycita-web@1.0.1';
      options.tracesSampleRate = kDebugMode ? 1.0 : 0.2;
      options.attachStacktrace = true;
      options.sendDefaultPii = false;
      options.beforeSend = (event, hint) {
        // Strip any PII that might leak through
        final user = event.user;
        if (user != null) {
          user.email = null;
          user.ipAddress = null;
          user.name = null;
        }
        return event;
      };
    },
    appRunner: () => runApp(
      const ProviderScope(child: BeautyCitaWebApp()),
    ),
  );
}
