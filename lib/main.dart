import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/notification_service.dart';
import 'package:beautycita/config/routes.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/theme_provider.dart';
import 'package:beautycita/providers/uber_provider.dart';
import 'package:beautycita/services/qr_auth_service.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/services/debug_log.dart';
import 'package:go_router/go_router.dart';

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

  // Install debug log capture (before anything else that uses debugPrint)
  DebugLog.instance.install();

  // Initialize dotenv
  await dotenv.load(fileName: '.env');

  // Configure Stripe (lazy initialization - settings applied when SDK is used)
  final stripeKey = dotenv.env['STRIPE_PUBLIC_KEY'] ?? '';
  if (stripeKey.isNotEmpty) {
    Stripe.publishableKey = stripeKey;
    Stripe.merchantIdentifier = 'merchant.com.beautycita';
    debugPrint('[Stripe] Configured with key: ${stripeKey.substring(0, 20)}...');
  } else {
    debugPrint('[Stripe] WARNING: No publishable key found in .env');
  }

  // Start Supabase init in background — splash screen awaits supabaseReady
  SupabaseClientService.initialize().then((_) async {
    debugPrint('[Init] Supabase initialized successfully');
    // Initialize push notifications after Supabase is ready
    await NotificationService().initialize();
    debugPrint('[Init] Notifications initialized');
    supabaseReady.complete();
  }).catchError((e) {
    debugPrint('[Init] ERROR: Supabase initialization failed: $e');
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

    // Check for pending notification navigation after a brief delay
    Future.delayed(const Duration(milliseconds: 500), _checkNotificationNavigation);
  }

  void _checkNotificationNavigation() {
    final pending = NotificationService().consumePendingNavigation();
    if (pending != null && mounted) {
      final route = pending['route'] as String?;
      if (route != null && route.isNotEmpty) {
        debugPrint('[Notification] Navigating to: $route');
        AppRoutes.router.go(route);
      }
    }
  }

  void _handleUri(Uri uri) {
    debugPrint('[DeepLink] Received URI: $uri');
    debugPrint('[DeepLink] scheme=${uri.scheme} host=${uri.host} params=${uri.queryParameters}');
    if (uri.scheme != 'beautycita') return;

    switch (uri.host) {
      case 'uber-callback':
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];
        debugPrint('[DeepLink] Uber callback - code=${code != null ? "${code.substring(0, code.length.clamp(0, 8))}..." : "null"}, error=$error');
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
    final router = AppRoutes.router;
    final themeState = ref.watch(themeProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: themeState.themeData,
      darkTheme: themeState.palette.brightness == Brightness.dark ? themeState.themeData : null,
      themeMode: themeState.palette.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      backButtonDispatcher: _SafeBackButtonDispatcher(router),
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
        return ScaffoldMessenger(
          key: ToastService.messengerKey,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Prevents system back button from closing the app on non-home screens.
/// If there's a route to pop, pops it. Otherwise navigates to /home.
/// Only allows app exit from /home, /, or /auth.
class _SafeBackButtonDispatcher extends RootBackButtonDispatcher {
  final GoRouter _router;
  _SafeBackButtonDispatcher(this._router);

  @override
  Future<bool> didPopRoute() async {
    if (_router.canPop()) {
      _router.pop();
      return true;
    }
    final location = _router.routeInformationProvider.value.uri.path;
    if (location == '/home' || location == '/' || location == '/auth') {
      return false; // Let system handle — exits the app
    }
    _router.go('/home');
    return true;
  }
}
