import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../variant_config.dart';
import 'el_splash_screen.dart';
import 'el_auth_screen.dart';
import 'el_home_screen.dart';
import 'el_settings_screen.dart';
import 'el_result_cards_screen.dart';
import 'el_chat_list_screen.dart';
import 'el_chat_conversation_screen.dart';
import 'el_my_bookings_screen.dart';
import 'el_business_shell_screen.dart';

/// Emerald Luxe — deep green art deco, gold geometric accents, structured feel.
/// Transition: scale(0.97→1.0) + fade, 400ms, easeOutQuart.
class EmeraldLuxeConfig extends ThemeVariantConfig {
  @override
  Widget buildSplash() => const ELSplashScreen();

  @override
  Widget buildAuth() => const ELAuthScreen();

  @override
  Widget buildHome() => const ELHomeScreen();

  @override
  Widget buildSettings() => const ELSettingsScreen();

  @override
  Widget buildResultCards() => const ELResultCardsScreen();

  @override
  Widget buildChatList() => const ELChatListScreen();

  @override
  Widget buildChatConversation(String threadId) =>
      ELChatConversationScreen(threadId: threadId);

  @override
  Widget buildMyBookings() => const ELMyBookingsScreen();

  @override
  Widget buildBusinessShell() => const ELBusinessShellScreen();

  @override
  CustomTransitionPage buildPageTransition({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Geometric feel: scale up from 0.97 + fade — structured, precise
        final easeOutQuart = CurveTween(
          curve: const Cubic(0.25, 1.0, 0.5, 1.0),
        );

        final fade = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(easeOutQuart),
        );
        final scale = animation.drive(
          Tween(begin: 0.97, end: 1.0).chain(easeOutQuart),
        );

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
    );
  }
}
