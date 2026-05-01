import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';

import '../services/lobby_music_service.dart';

/// One-time bottom sheet asking the user whether they want background
/// music. Shown on the first home-screen mount only — afterwards the
/// preference lives in SharedPreferences (via [LobbyMusicNotifier]).
///
/// Call [maybeShow] once from [HomeScreen.initState] (post-frame).
class LobbyMusicPrompt {
  LobbyMusicPrompt._();

  /// Show the sheet if the user hasn't been asked yet. No-op otherwise.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    final state = ref.read(lobbyMusicProvider);
    if (state.hasPrompted) return;

    // Mark immediately so a second mount can't re-trigger the sheet
    // before this one finishes animating in.
    await ref.read(lobbyMusicProvider.notifier).markPromptShown();

    if (!context.mounted) return;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PromptSheet(),
    );

    if (accepted == true) {
      await ref.read(lobbyMusicProvider.notifier).setEnabled(true);
    }
  }
}

class _PromptSheet extends StatelessWidget {
  const _PromptSheet();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: palette.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                ),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Musica de fondo',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Te acompañamos con musica suave mientras exploras. La puedes silenciar o reactivar cuando quieras desde el boton flotante.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: palette.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('No, gracias'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Activar musica'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
