import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Lightweight UI sound service — plays short audio cues alongside haptic feedback.
/// Sounds are gated by the same feature toggle as haptics (enable_haptic_feedback).
class SoundService {
  SoundService._();
  static final instance = SoundService._();

  final _player = AudioPlayer();

  /// Enable/disable sounds globally (mirrors haptic toggle).
  bool enabled = true;

  /// Play a named sound from assets/sounds/.
  Future<void> play(UiSound sound) async {
    if (!enabled) return;
    try {
      await _player.stop();
      await _player.setSource(AssetSource('sounds/${sound.filename}'));
      await _player.setVolume(sound.volume);
      await _player.resume();
    } catch (e) {
      if (kDebugMode) debugPrint('[Sound] Failed to play ${sound.filename}: $e');
    }
  }

  void dispose() => _player.dispose();
}

/// Available UI sounds mapped to asset filenames.
enum UiSound {
  tap('tap.mp3', 0.3),
  tick('tick.mp3', 0.2),
  select('select.mp3', 0.4),
  swipe('swipe.mp3', 0.25),
  error('error.mp3', 0.5),
  success('success.mp3', 0.6),
  notification('notification.mp3', 0.7),
  alert('alert.mp3', 0.6);

  const UiSound(this.filename, this.volume);
  final String filename;
  final double volume;
}
