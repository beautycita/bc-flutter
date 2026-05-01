import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/lobby_music_service.dart';
import '../services/sound_service.dart';

/// Wrap a screen's body with this widget to silence the lobby music
/// while that screen is on top. The user's saved preference (enabled
/// vs muted) is preserved — playback resumes automatically once this
/// widget is disposed (i.e. the screen pops). Use on chat, payment,
/// business panel, virtual studio, video portfolio playback, etc.
class LobbyMusicSuppressor extends ConsumerStatefulWidget {
  const LobbyMusicSuppressor({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LobbyMusicSuppressor> createState() =>
      _LobbyMusicSuppressorState();
}

class _LobbyMusicSuppressorState extends ConsumerState<LobbyMusicSuppressor> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(lobbyMusicProvider.notifier).setSuppressed(true);
    });
  }

  @override
  void dispose() {
    // Lift suppression through the notifier so Riverpod state (and any
    // pill that mounts on the next screen) reflects the resumed state.
    ref.read(lobbyMusicProvider.notifier).setSuppressed(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Tiny floating pill, anchored bottom-left, that toggles lobby music.
///
/// Lifecycle:
///   * Auto-fades to ~30% opacity 3s after the host page mounts so it's
///     not in the user's face — taps anywhere on the screen revive it
///     to full opacity for another 3s (handled by [LobbyMusicPillScope]).
///   * Single tap toggles enabled. Persists via [LobbyMusicNotifier].
///   * Visual: 40px circle, glass card, soft brand-gradient ring.
///   * Wraps the whole screen so the pill floats above content. Mount it
///     ONLY on screens where music is allowed (home / explorar / feed).
class LobbyMusicPillScope extends ConsumerStatefulWidget {
  const LobbyMusicPillScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LobbyMusicPillScope> createState() =>
      _LobbyMusicPillScopeState();
}

class _LobbyMusicPillScopeState extends ConsumerState<LobbyMusicPillScope> {
  bool _showFull = true;
  Timer? _fadeTimer;

  static const _idleOpacity = 0.32;
  static const _fadeDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _scheduleFade();
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _scheduleFade() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(_fadeDelay, () {
      if (mounted) setState(() => _showFull = false);
    });
  }

  void _wakePill() {
    if (!mounted) return;
    if (!_showFull) setState(() => _showFull = true);
    _scheduleFade();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _wakePill(),
      child: Stack(
        children: [
          widget.child,
          Positioned(
            left: 12,
            // Sit just above the system gesture inset / bottom nav so the
            // pill never overlaps a bottom-aligned CTA.
            bottom: MediaQuery.of(context).padding.bottom + 92,
            child: SafeArea(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                opacity: _showFull ? 1.0 : _idleOpacity,
                child: const _MutePill(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MutePill extends ConsumerWidget {
  const _MutePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lobbyMusicProvider);
    final playing = state.isPlaying;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () async {
          await SoundService.instance.play(UiSound.tap);
          await ref.read(lobbyMusicProvider.notifier).toggle();
        },
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: playing
                  ? const [Color(0xFFEC4899), Color(0xFF9333EA)]
                  : [
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      Theme.of(context).colorScheme.surface,
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          // Cross-fade the icon on toggle so mute/unmute reads as a smooth
          // state change rather than an instant glyph swap. The Stack +
          // AnimatedOpacity pair lets both icons share the same center cell
          // — fade-out the outgoing, fade-in the incoming, no layout shift.
          child: SizedBox(
            width: 22,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  opacity: playing ? 1.0 : 0.0,
                  child: Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 22,
                    semanticLabel: 'Silenciar musica',
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  opacity: playing ? 0.0 : 1.0,
                  child: Icon(
                    Icons.volume_off_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 22,
                    semanticLabel: 'Activar musica',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
