import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../variant_config.dart';
import 'gl_splash_screen.dart';
import 'gl_auth_screen.dart';
import 'gl_home_screen.dart';
import 'gl_settings_screen.dart';
import 'gl_result_cards_screen.dart';
import 'gl_chat_list_screen.dart';
import 'gl_chat_conversation_screen.dart';
import 'gl_my_bookings_screen.dart';
import 'gl_business_shell_screen.dart';

/// Glassmorphism (Cristal) — aurora gradients, frosted glass panels,
/// neon pink/purple/blue accents on deep navy-black.
class GlassConfig extends ThemeVariantConfig {
  @override
  Widget buildSplash() => const GLSplashScreen();

  @override
  Widget buildAuth() => const GLAuthScreen();

  @override
  Widget buildHome() => const GLHomeScreen();

  @override
  Widget buildSettings() => const GLSettingsScreen();

  @override
  Widget buildResultCards() => const GLResultCardsScreen();

  @override
  Widget buildChatList() => const GLChatListScreen();

  @override
  Widget buildChatConversation(String threadId) =>
      GLChatConversationScreen(threadId: threadId);

  @override
  Widget buildMyBookings() => const GLMyBookingsScreen();

  @override
  Widget buildBusinessShell() => const GLBusinessShellScreen();

  /// Blur+fade transition (300ms) — incoming content blurs in from
  /// frosted to clear, combined with a gentle fade.
  @override
  CustomTransitionPage buildPageTransition({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Fade: incoming page fades in
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        // Scale: subtle grow-in from 0.96 to 1.0 for glass depth feel
        final scale = Tween(begin: 0.96, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(animation);

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: _BlurFadeTransition(
              animation: animation,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Applies a BackdropFilter blur that clears as the animation progresses —
/// the "frosted glass reveals to clear" effect.
class _BlurFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _BlurFadeTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Blur starts at sigma=8, clears to 0 as animation completes
        final sigma = (1.0 - animation.value) * 8.0;
        if (sigma < 0.1) {
          // Fully revealed — skip BackdropFilter overhead
          return child!;
        }
        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}
