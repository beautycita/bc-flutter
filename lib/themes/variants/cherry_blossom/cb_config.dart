import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../variant_config.dart';
import 'cb_splash_screen.dart';
import 'cb_auth_screen.dart';
import 'cb_home_screen.dart';
import 'cb_settings_screen.dart';
import 'cb_result_cards_screen.dart';
import 'cb_chat_list_screen.dart';
import 'cb_chat_conversation_screen.dart';
import 'cb_my_bookings_screen.dart';
import 'cb_business_shell_screen.dart';

/// Cherry Blossom — airy, elegant light theme with pink-lavender palette.
/// Soft crossfade transition at 450ms with easeOut curve.
class CherryBlossomConfig extends ThemeVariantConfig {
  @override
  Widget buildSplash() => const CBSplashScreen();

  @override
  Widget buildAuth() => const CBAuthScreen();

  @override
  Widget buildHome() => const CBHomeScreen();

  @override
  Widget buildSettings() => const CBSettingsScreen();

  @override
  Widget buildResultCards() => const CBResultCardsScreen();

  @override
  Widget buildChatList() => const CBChatListScreen();

  @override
  Widget buildChatConversation(String threadId) =>
      CBChatConversationScreen(threadId: threadId);

  @override
  Widget buildMyBookings() => const CBMyBookingsScreen();

  @override
  Widget buildBusinessShell() => const CBBusinessShellScreen();

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
        // Pure crossfade — soft, airy, no directional slide
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(opacity: fade, child: child);
      },
    );
  }
}
