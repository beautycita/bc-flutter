import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/test_config.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!TestConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: TestConfig.supabaseUrl,
    anonKey: TestConfig.supabaseAnonKey,
  );

  runApp(const TestSuiteApp());
}

class TestSuiteApp extends StatelessWidget {
  const TestSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeautyCita Test Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEC4899),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Missing configuration.\n\n'
              'Build with dart-define flags:\n'
              'SUPABASE_URL, SUPABASE_SERVICE_KEY,\n'
              'SUPABASE_ANON_KEY, SAT_API_KEY, SAT_API_SECRET',
              style: GoogleFonts.jetBrainsMono(
                color: Colors.red,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
