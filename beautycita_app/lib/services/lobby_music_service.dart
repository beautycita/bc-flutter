import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Streaming URL for the prepared lobby loop. 154s, 96kbps, 0.5s in/out
/// fades — produced from BeautyCita.mp3 with the first 5s trimmed off.
const String _lobbyMusicUrl =
    'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/audio/beautycita-loop.mp3';

const String _kEnabledKey = 'lobby_music_enabled';
const String _kPromptShownKey = 'lobby_music_prompt_shown';
const double _kFixedVolume = 0.30;

/// Background lobby music. One singleton player, looped, low volume.
/// External code should not poke the [AudioPlayer] directly — use the
/// notifier methods so [enabled] persists and [_suppressed] gates work.
class LobbyMusicService {
  LobbyMusicService._();
  static final instance = LobbyMusicService._();

  final AudioPlayer _player = AudioPlayer(playerId: 'lobby-music');
  bool _initialized = false;
  bool _enabled = false;
  bool _suppressed = false;
  bool _hasPrompted = false;

  bool get enabled => _enabled;
  bool get hasPrompted => _hasPrompted;
  bool get isSuppressed => _suppressed;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabledKey) ?? false;
    _hasPrompted = prefs.getBool(_kPromptShownKey) ?? false;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(_kFixedVolume);
    if (_enabled && !_suppressed) {
      await _start();
    }
  }

  Future<void> markPromptShown() async {
    _hasPrompted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPromptShownKey, true);
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
    if (value && !_suppressed) {
      await _start();
    } else {
      await _stop();
    }
  }

  /// Hard suppression while the user is on a screen where music would be
  /// inappropriate (chat, payment, video portfolio, business panel). The
  /// user's [enabled] preference is preserved — playback resumes as soon
  /// as the suppression lifts.
  Future<void> setSuppressed(bool value) async {
    if (_suppressed == value) return;
    _suppressed = value;
    if (value) {
      await _player.pause();
    } else if (_enabled) {
      await _start();
    }
  }

  /// Lifecycle-driven pause (app backgrounded). Different from suppression
  /// because we don't want to flip the user's saved preference.
  Future<void> pauseForLifecycle() async {
    try {
      await _player.pause();
    } catch (_) {/* best-effort */}
  }

  Future<void> resumeAfterLifecycle() async {
    if (_enabled && !_suppressed) {
      await _start();
    }
  }

  Future<void> _start() async {
    try {
      // play() with UrlSource handles "already playing" gracefully —
      // resume() alone won't (re)open the source if it was never set.
      await _player.play(UrlSource(_lobbyMusicUrl), volume: _kFixedVolume);
    } catch (e) {
      if (kDebugMode) debugPrint('[LobbyMusic] play failed: $e');
    }
  }

  Future<void> _stop() async {
    try {
      await _player.stop();
    } catch (_) {/* best-effort */}
  }

  Future<void> dispose() => _player.dispose();
}

@immutable
class LobbyMusicState {
  const LobbyMusicState({
    required this.enabled,
    required this.suppressed,
    required this.hasPrompted,
  });

  final bool enabled;
  final bool suppressed;
  final bool hasPrompted;

  /// True when the user wants music AND we're on a non-suppressed screen.
  /// Use this to decide what icon to show in the floating pill.
  bool get isPlaying => enabled && !suppressed;

  LobbyMusicState copyWith({
    bool? enabled,
    bool? suppressed,
    bool? hasPrompted,
  }) =>
      LobbyMusicState(
        enabled: enabled ?? this.enabled,
        suppressed: suppressed ?? this.suppressed,
        hasPrompted: hasPrompted ?? this.hasPrompted,
      );
}

class LobbyMusicNotifier extends StateNotifier<LobbyMusicState> {
  LobbyMusicNotifier()
      : super(const LobbyMusicState(
          enabled: false,
          suppressed: false,
          hasPrompted: false,
        )) {
    _load();
  }

  Future<void> _load() async {
    await LobbyMusicService.instance.init();
    state = state.copyWith(
      enabled: LobbyMusicService.instance.enabled,
      hasPrompted: LobbyMusicService.instance.hasPrompted,
    );
  }

  Future<void> setEnabled(bool value) async {
    await LobbyMusicService.instance.setEnabled(value);
    state = state.copyWith(enabled: value);
  }

  Future<void> toggle() => setEnabled(!state.enabled);

  Future<void> setSuppressed(bool value) async {
    await LobbyMusicService.instance.setSuppressed(value);
    state = state.copyWith(suppressed: value);
  }

  Future<void> markPromptShown() async {
    await LobbyMusicService.instance.markPromptShown();
    state = state.copyWith(hasPrompted: true);
  }

  Future<void> pauseForLifecycle() =>
      LobbyMusicService.instance.pauseForLifecycle();

  Future<void> resumeAfterLifecycle() =>
      LobbyMusicService.instance.resumeAfterLifecycle();
}

final lobbyMusicProvider =
    StateNotifierProvider<LobbyMusicNotifier, LobbyMusicState>(
  (ref) => LobbyMusicNotifier(),
);
