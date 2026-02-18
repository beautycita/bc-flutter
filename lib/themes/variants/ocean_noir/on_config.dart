import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../variant_config.dart';
import 'on_splash_screen.dart';
import 'on_auth_screen.dart';
import 'on_home_screen.dart';
import 'on_settings_screen.dart';
import 'on_result_cards_screen.dart';
import 'on_chat_list_screen.dart';
import 'on_chat_conversation_screen.dart';
import 'on_my_bookings_screen.dart';
import 'on_business_shell_screen.dart';

/// Ocean Noir — tech terminal aesthetic, deep navy surfaces, cyan/teal neon accents.
/// Angular cards with diagonal clipped corners, scan-line animations, HUD data overlays.
class OceanNoirConfig extends ThemeVariantConfig {
  @override
  Widget buildSplash() => const ONSplashScreen();

  @override
  Widget buildAuth() => const ONAuthScreen();

  @override
  Widget buildHome() => const ONHomeScreen();

  @override
  Widget buildSettings() => const ONSettingsScreen();

  @override
  Widget buildResultCards() => const ONResultCardsScreen();

  @override
  Widget buildChatList() => const ONChatListScreen();

  @override
  Widget buildChatConversation(String threadId) =>
      ONChatConversationScreen(threadId: threadId);

  @override
  Widget buildMyBookings() => const ONMyBookingsScreen();

  @override
  Widget buildBusinessShell() => const ONBusinessShellScreen();

  @override
  CustomTransitionPage buildPageTransition({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Horizontal wipe: slide from right + fade — digital/terminal feel
        final slide = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        )
            .chain(CurveTween(curve: Curves.linear))
            .animate(animation);

        final fade = Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: const Interval(0.0, 0.5)))
            .animate(animation);

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }
}
