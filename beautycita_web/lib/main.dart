import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Clean URLs — no #/ hash

  await initializeDateFormatting('es');

  // Start Supabase init WITHOUT awaiting — lets Flutter render immediately
  // so the splash screen shows. The login page awaits the same future.
  BCSupabase.initialize();

  runApp(const ProviderScope(child: BeautyCitaWebApp()));
}
