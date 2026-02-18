import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../variant_config.dart';
import 'mo_splash_screen.dart';
import 'mo_auth_screen.dart';
import 'mo_home_screen.dart';
import 'mo_settings_screen.dart';
import 'mo_result_cards_screen.dart';
import 'mo_chat_list_screen.dart';
import 'mo_chat_conversation_screen.dart';
import 'mo_my_bookings_screen.dart';
import 'mo_business_shell_screen.dart';

/// Midnight Orchid — bioluminescent garden, deep purple, soft organic shapes.
class MidnightOrchidConfig extends ThemeVariantConfig {
  @override
  Widget buildSplash() => const MOSplashScreen();

  @override
  Widget buildAuth() => const MOAuthScreen();

  @override
  Widget buildHome() => const MOHomeScreen();

  @override
  Widget buildSettings() => const MOSettingsScreen();

  @override
  Widget buildResultCards() => const MOResultCardsScreen();

  @override
  Widget buildChatList() => const MOChatListScreen();

  @override
  Widget buildChatConversation(String threadId) =>
      MOChatConversationScreen(threadId: threadId);

  @override
  Widget buildMyBookings() => const MOMyBookingsScreen();

  @override
  Widget buildBusinessShell() => const MOBusinessShellScreen();

  @override
  CustomTransitionPage buildPageTransition({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Morphing/organic feel: scale from 0.95 to 1.0 + fade
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final scale = Tween(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(animation);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }
}
