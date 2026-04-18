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

  // Widen what we log when something throws on the web. dart2js minifies
  // class names in release builds so stack traces read like "bSh.$2" —
  // surface runtimeType + full details so bughunter (and real users via
  // Sentry) see something actionable.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(
      '[FlutterError] ${details.exception.runtimeType}: ${details.exceptionAsString()}',
    );
  };

  await initializeDateFormatting('es');

  // Await Supabase init before mounting the router. The not-awaiting
  // variant let the router mount authed pages before Supabase had an
  // instance, which threw StateError from BCSupabase.client in
  // downstream widgets (client_shell avatar, reservar, cuenta, etc).
  // The index.html splash stays visible until runApp, so the user still
  // sees something immediately; we just don't ship widgets that depend
  // on Supabase until it's ready.
  await BCSupabase.initialize();

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
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
  } else {
    runApp(const ProviderScope(child: BeautyCitaWebApp()));
  }
}
