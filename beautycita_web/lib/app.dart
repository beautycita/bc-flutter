import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/theme.dart';

import 'config/router.dart';
import 'config/web_theme.dart';
import 'config/web_transitions.dart';
import 'providers/auth_provider.dart';

class BeautyCitaWebApp extends ConsumerWidget {
  const BeautyCitaWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Watch auth state stream so session registration happens on page refresh
    ref.watch(authStateStreamProvider);
    return BcWebTapTracker(
      child: MaterialApp.router(
        title: 'BeautyCita',
        debugShowCheckedModeBanner: false,
        theme: buildWebTheme(roseGoldPalette),
        routerConfig: router,
      ),
    );
  }
}
