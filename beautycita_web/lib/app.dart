import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/theme.dart';

import 'config/router.dart';
import 'config/web_theme.dart';

class BeautyCitaWebApp extends ConsumerWidget {
  const BeautyCitaWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'BeautyCita',
      debugShowCheckedModeBanner: false,
      theme: buildWebTheme(roseGoldPalette),
      routerConfig: router,
    );
  }
}
