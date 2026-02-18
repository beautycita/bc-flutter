import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../variant_config.dart';
import '../../../screens/splash_screen.dart';
import '../../../screens/auth_screen.dart';
import '../../../screens/home_screen.dart';
import '../../../screens/settings_screen.dart';

/// Rose & Gold — wraps existing (FROZEN) screens with no changes.
class RoseGoldConfig extends ThemeVariantConfig {
  @override
  Widget buildSplash() => const SplashScreen();

  @override
  Widget buildAuth() => const AuthScreen();

  @override
  Widget buildHome() => const HomeScreen();

  @override
  Widget buildSettings() => const SettingsScreen();

  @override
  CustomTransitionPage buildPageTransition({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
