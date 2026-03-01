import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
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
// uber_provider import removed — using deep links, no OAuth
import 'package:beautycita/services/qr_auth_service.dart';
import 'package:beautycita/services/user_session.dart';
import 'package:beautycita/screens/business/business_shell_screen.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/services/debug_log.dart';
import 'package:beautycita/services/presence_service.dart';
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

  // Track app open count (fire-and-forget, no await needed)
  UserSession.incrementAppOpenCount();

  // Initialize dotenv
  await dotenv.load(fileName: '.env');

  // Configure Stripe (lazy initialization - settings applied when SDK is used)
  final stripeKey = dotenv.env['STRIPE_PUBLIC_KEY'] ?? '';
  if (stripeKey.isNotEmpty) {
    Stripe.publishableKey = stripeKey;
    Stripe.merchantIdentifier = 'merchant.com.beautycita';
    assert(() { debugPrint('[Stripe] Configured'); return true; }());
  } else {
    debugPrint('[Stripe] WARNING: No publishable key found in .env');
  }

  // Start Supabase init in background — splash screen awaits supabaseReady
  SupabaseClientService.initialize().then((_) async {
    debugPrint('[Init] Supabase initialized successfully');
    // Initialize push notifications after Supabase is ready
    await NotificationService().initialize();
    debugPrint('[Init] Notifications initialized');
    PresenceService.instance.start();
    debugPrint('[Init] Presence heartbeat started');
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

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _safeParamRegex = RegExp(r'^[a-zA-Z0-9\-_]+$');

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

  static const _allowedNotificationRoutes = {
    '/bookings',
    '/chat',
    '/profile',
    '/settings',
  };

  bool _isAllowedRoute(String route) {
    return _allowedNotificationRoutes.contains(route) ||
        route.startsWith('/appointment/') ||
        route.startsWith('/chat/') ||
        route.startsWith('/booking/');
  }

  void _checkNotificationNavigation() {
    try {
      final pending = NotificationService().consumePendingNavigation();
      if (pending != null && mounted) {
        final route = pending['route'] as String?;
        if (route != null && route.isNotEmpty && _isAllowedRoute(route)) {
          assert(() { debugPrint('[Notification] Navigating to: $route'); return true; }());
          AppRoutes.router.go(route);
        } else if (route != null && route.isNotEmpty) {
          assert(() { debugPrint('[Notification] Rejected non-allowlisted route: $route'); return true; }());
        }
      }
    } catch (e) {
      assert(() { debugPrint('[Notification] Skipped — not yet initialized: $e'); return true; }());
    }
  }

  void _handleUri(Uri uri) {
    debugPrint('[DeepLink] Received URI: $uri');
    debugPrint('[DeepLink] scheme=${uri.scheme} host=${uri.host} path=${uri.path} params=${uri.queryParameters}');

    // Handle HTTPS deep links (beautycita.com)
    if (uri.scheme == 'https' && uri.host == 'beautycita.com') {
      _handleWebLink(uri);
      return;
    }

    if (uri.scheme != 'beautycita') return;

    switch (uri.host) {
      case 'uber-callback':
        final code = uri.queryParameters['code'];
        // Uber OAuth no longer used — deep link approach instead.
        debugPrint('[DeepLink] Uber callback (ignored — using deep links now)');
        break;
      case 'stripe-complete':
        debugPrint('[DeepLink] Stripe onboarding complete');
        // Navigate to business shell, Pagos tab
        ref.read(businessTabProvider.notifier).state = 6;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.business,
          (route) => false,
        );
        ToastService.showSuccess('Stripe conectado — tus servicios estan listos');
        break;
      case 'cita-express':
        // beautycita://cita-express/{bizId}
        final bizId = uri.path.replaceFirst('/', '');
        if (bizId.isNotEmpty && _uuidRegex.hasMatch(bizId)) {
          supabaseReady.future.then((_) {
            if (mounted) AppRoutes.router.go('/cita-express/$bizId');
          });
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

  void _handleWebLink(Uri uri) {
    final path = uri.path;
    final params = uri.queryParameters;
    assert(() { debugPrint('[DeepLink] Web link: path=$path'); return true; }());

    if (path == '/registro' || path.startsWith('/registro')) {
      // Salon registration with optional prefill from discovered salon.
      // Validate ref is alphanumeric/dash/underscore only — no special chars.
      final rawRef = params['ref'] ?? '';
      final safeRef = rawRef.isNotEmpty && _safeParamRegex.hasMatch(rawRef)
          ? rawRef
          : '';
      final route = safeRef.isNotEmpty ? '/registro?ref=$safeRef' : '/registro';
      supabaseReady.future.then((_) {
        if (mounted) AppRoutes.router.go(route);
      });
      return;
    }

    // Salon profile deep link → redirect to registration.
    // salonId must be a valid UUID.
    if (path.startsWith('/salon/')) {
      final salonId = path.replaceFirst('/salon/', '');
      if (salonId.isNotEmpty && _uuidRegex.hasMatch(salonId)) {
        supabaseReady.future.then((_) {
          if (mounted) AppRoutes.router.go('/registro?ref=$salonId');
        });
        return;
      }
      // Invalid or missing salonId — fall through to home.
    }

    // Cita Express walk-in QR deep link.
    // bizId must be a valid UUID.
    if (path.startsWith('/cita-express/')) {
      final bizId = path.replaceFirst('/cita-express/', '');
      if (bizId.isNotEmpty && _uuidRegex.hasMatch(bizId)) {
        supabaseReady.future.then((_) {
          if (mounted) AppRoutes.router.go('/cita-express/$bizId');
        });
        return;
      }
      // Invalid or missing bizId — fall through to home.
    }

    // Default: go home
    supabaseReady.future.then((_) {
      if (mounted) AppRoutes.router.go('/home');
    });
  }

  Future<void> _handleQrAuth(String code, String sessionId) async {
    final service = QrAuthService();
    final result = await service.authorizeSession(code, sessionId);

    switch (result) {
      case QrAuthSuccess():
        ToastService.showSuccess('Dispositivo vinculado exitosamente');
      case QrAuthError(:final message):
        ToastService.showError(message);
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
      darkTheme: themeState.themeData,
      themeMode: themeState.themeMode,
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
