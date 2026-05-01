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
  // True once we've issued the first play(UrlSource) for this session.
  // Subsequent toggles use resume()/pause() so playback continues from where
  // it left off instead of restarting the loop from t=0.
  bool _sourceLoaded = false;

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
      // Pause (don't stop) so the playhead position is preserved.
      // Next setEnabled(true) calls resume(), continuing the loop from
      // where the user paused it instead of restarting from t=0.
      await _pause();
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
      await _pause();
    } else if (_enabled) {
      await _start();
    }
  }

  /// Lifecycle-driven pause (app backgrounded). Different from suppression
  /// because we don't want to flip the user's saved preference.
  Future<void> pauseForLifecycle() => _pause();

  Future<void> resumeAfterLifecycle() async {
    if (_enabled && !_suppressed) {
      await _start();
    }
  }

  Future<void> _start() async {
    try {
      if (!_sourceLoaded) {
        // First play of the session — open the URL source.
        await _player.play(UrlSource(_lobbyMusicUrl), volume: _kFixedVolume);
        _sourceLoaded = true;
      } else {
        // Source already opened — resume() continues from the paused
        // playhead instead of restarting the loop from t=0.
        await _player.resume();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LobbyMusic] play/resume failed: $e');
    }
  }

  Future<void> _pause() async {
    try {
      await _player.pause();
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
