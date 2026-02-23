import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme_extension.dart';
import '../providers/chat_provider.dart';

const _prefHasSeenAphrodite = 'has_seen_aphrodite';

/// Smart router: first-time users go to Aphrodite intro.
/// After that, always go to chat list.
class ChatRouterScreen extends ConsumerWidget {
  const ChatRouterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: SharedPreferences.getInstance()
          .then((p) => p.getBool(_prefHasSeenAphrodite) ?? false),
      builder: (context, snap) {
        if (!snap.hasData) return _LoadingView();

        final hasSeenAphrodite = snap.data!;

        if (hasSeenAphrodite) {
          // Already met Aphrodite — always show chat list
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pushReplacement('/chat/list');
          });
        } else {
          // First time — go to Aphrodite, then mark as seen
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;
            // Mark seen before navigating
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_prefHasSeenAphrodite, true);
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
