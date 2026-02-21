import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme_extension.dart';
import '../providers/chat_provider.dart';

/// Smart router that skips the chat list when there are no unread messages
/// and goes directly to the Aphrodite conversation.
class ChatRouterScreen extends ConsumerWidget {
  const ChatRouterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(chatThreadsProvider);

    return threadsAsync.when(
      data: (threads) {
        // Count non-Aphrodite threads with unread messages
        final unreadCount = threads
            .where((t) => t.contactType != 'aphrodite' && t.unreadCount > 0)
            .length;

        if (unreadCount > 0) {
          // Has unreads — show chat list
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pushReplacement('/chat/list');
          });
        } else {
          // No unreads — go straight to Aphrodite
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;
            try {
              final aphThread = await ref
                  .read(aphroditeThreadProvider.future)
                  .timeout(const Duration(seconds: 10));
              if (aphThread != null && context.mounted) {
                context.pushReplacement('/chat/${aphThread.id}');
              } else if (context.mounted) {
                context.pushReplacement('/chat/list');
              }
            } catch (_) {
              if (context.mounted) context.pushReplacement('/chat/list');
            }
          });
        }

        // Show loading spinner while routing
        return _LoadingView();
      },
      loading: () => _LoadingView(),
      error: (_, __) {
        // Fallback to chat list on error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.pushReplacement('/chat/list');
        });
        return _LoadingView();
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: Theme.of(context).extension<BCThemeExtension>()!.accentGradient,
              ),
              child: const Center(
                child: Text('\u{1F3DB}\uFE0F', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
