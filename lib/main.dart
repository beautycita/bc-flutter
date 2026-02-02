import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/routes.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/uber_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Spanish locale data for intl date formatting
  await initializeDateFormatting('es');

  // Initialize Supabase
  await SupabaseClientService.initialize();

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
    if (uri.scheme == 'beautycita' && uri.host == 'uber-callback') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        ref.read(uberLinkProvider.notifier).handleCallback(code);
      }
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
