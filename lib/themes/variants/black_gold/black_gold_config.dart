import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../variant_config.dart';
import 'bg_splash_screen.dart';
import 'bg_auth_screen.dart';
import 'bg_home_screen.dart';
import 'bg_settings_screen.dart';
import 'bg_result_cards_screen.dart';
import 'bg_chat_list_screen.dart';
import 'bg_chat_conversation_screen.dart';
import 'bg_my_bookings_screen.dart';
import 'bg_business_shell_screen.dart';

/// Black & Gold — luxury editorial, dark surfaces, metallic gold accents.
class BlackGoldConfig extends ThemeVariantConfig {
  @override
  Widget buildSplash() => const BGSplashScreen();

  @override
  Widget buildAuth() => const BGAuthScreen();

  @override
  Widget buildHome() => const BGHomeScreen();

  @override
  Widget buildSettings() => const BGSettingsScreen();

  @override
  Widget buildResultCards() => const BGResultCardsScreen();

  @override
  Widget buildChatList() => const BGChatListScreen();

  @override
  Widget buildChatConversation(String threadId) =>
      BGChatConversationScreen(threadId: threadId);

  @override
  Widget buildMyBookings() => const BGMyBookingsScreen();

  @override
  Widget buildBusinessShell() => const BGBusinessShellScreen();

  @override
  CustomTransitionPage buildPageTransition({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 450),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slow fade + subtle slide — luxury feel
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide = Tween(begin: const Offset(0.03, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(animation);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }
}
