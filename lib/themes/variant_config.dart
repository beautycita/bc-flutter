import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/result_cards_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/my_bookings_screen.dart';
import '../screens/business/business_shell_screen.dart';
import '../screens/business/business_dashboard_screen.dart';

/// Abstract configuration for a theme variant's unique screen implementations.
abstract class ThemeVariantConfig {
  /// Build the splash screen widget for this variant.
  Widget buildSplash();

  /// Build the auth screen widget for this variant.
  Widget buildAuth();

  /// Build the home screen widget for this variant.
  Widget buildHome();

  /// Build the settings screen widget for this variant.
  Widget buildSettings();

  /// Build a page transition wrapping the given child widget.
  CustomTransitionPage buildPageTransition({
    required Widget child,
    required GoRouterState state,
  });

  // ─── Non-abstract builders with default implementations ──────────────────
  // Existing variant configs don't need to override these.

  Widget buildResultCards() => const ResultCardsScreen();

  Widget buildChatList() => const ChatListScreen();

  Widget buildChatConversation(String threadId) =>
      ChatConversationScreen(threadId: threadId);

  Widget buildMyBookings() => const MyBookingsScreen();

  Widget buildBusinessShell() => const BusinessShellScreen();

  Widget buildBusinessDashboard() => const BusinessDashboardScreen();
}
