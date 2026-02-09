import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/routes.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/uber_provider.dart';
import 'package:beautycita/services/qr_auth_service.dart';

/// Completes when Supabase is ready (or failed). Splash screen awaits this.
final Completer<void> supabaseReady = Completer<void>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Spanish locale data for intl date formatting
  await initializeDateFormatting('es');

  // Use bundled fonts only — never fetch from network
  GoogleFonts.config.allowRuntimeFetching = false;

  // Portrait only for thumb-friendly design
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Start Supabase init in background — splash screen awaits supabaseReady
  SupabaseClientService.initialize().then((_) {
    supabaseReady.complete();
  }).catchError((e) {
    supabaseReady.complete(); // Complete even on error so splash doesn't hang
  });

  runApp(
    const ProviderScope(
      child: BeautyCitaApp(),
    ),
  );
}

class BeautyCitaApp extends ConsumerStatefulWidget {
  const BeautyCitaApp({super.key});

  @override
  ConsumerState<BeautyCitaApp> createState() => _BeautyCitaAppState();
}

class _BeautyCitaAppState extends ConsumerState<BeautyCitaApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // Handle links when app is already running
    _linkSub = _appLinks.uriLinkStream.listen(_handleUri);

    // Handle cold-start link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    debugPrint('[DeepLink] Received URI: $uri');
    debugPrint('[DeepLink] scheme=${uri.scheme} host=${uri.host} params=${uri.queryParameters}');
    if (uri.scheme != 'beautycita') return;

    switch (uri.host) {
      case 'uber-callback':
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];
        debugPrint('[DeepLink] Uber callback - code=${code != null ? "${code.substring(0, code.length.clamp(0, 8) as int)}..." : "null"}, error=$error');
        if (error != null) {
          debugPrint('[DeepLink] Uber OAuth error: $error - ${uri.queryParameters['error_description']}');
        }
        if (code != null) {
          ref.read(uberLinkProvider.notifier).handleCallback(code);
        }
        break;
      case 'auth':
        if (uri.path == '/qr') {
          final code = uri.queryParameters['code'];
          final sessionId = uri.queryParameters['session'];
          if (code != null && sessionId != null) {
            _handleQrAuth(code, sessionId);
          }
        }
        break;
    }
  }

  Future<void> _handleQrAuth(String code, String sessionId) async {
    final service = QrAuthService();
    final result = await service.authorizeSession(code, sessionId);

    if (!mounted) return;

    switch (result) {
      case QrAuthSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispositivo vinculado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      case QrAuthError(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: BeautyCitaTheme.lightTheme,
      routerConfig: AppRoutes.router,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final scaler = MediaQuery.of(context).textScaler;
        final scale = scaler.scale(1.0).clamp(0.8, 1.2);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
