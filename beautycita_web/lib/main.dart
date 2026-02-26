import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Spanish locale for date formatting
  await initializeDateFormatting('es');

  // Bundled fonts only — no runtime fetching
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize Supabase (shared) — loads .env internally
  await BCSupabase.initialize();

  runApp(const ProviderScope(child: BeautyCitaWebApp()));
}
