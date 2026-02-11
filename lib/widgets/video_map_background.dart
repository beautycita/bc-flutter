import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-bleed looping video background with brand color overlay and
/// cross-fade transition at loop boundaries.
///
/// Uses two [VideoPlayerController] instances playing the same asset.
/// When player A nears the end, player B starts from 0 and a cross-fade
/// dissolve makes the loop seamless.
class VideoMapBackground extends StatefulWidget {
  const VideoMapBackground({super.key});

  @override
  State<VideoMapBackground> createState() => _VideoMapBackgroundState();
}

class _VideoMapBackgroundState extends State<VideoMapBackground>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _playerA;
  late VideoPlayerController _playerB;

  late AnimationController _fadeController;

  /// true  → _playerA is visible (opacity 1), _playerB underneath
  /// false → _playerB is visible, _playerA underneath
  bool _showA = true;

  /// Prevent re-entrant crossfade triggers.
  bool _crossfading = false;

  static const _crossfadeDuration = Duration(milliseconds: 1500);
  static const _triggerBeforeEnd = Duration(milliseconds: 2000);
  static const _assetPath = 'assets/videos/home_map_bg.mp4';

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: _crossfadeDuration,
    );

    _playerA = VideoPlayerController.asset(_assetPath);
    _playerB = VideoPlayerController.asset(_assetPath);

    _initPlayers();
  }

  Future<void> _initPlayers() async {
    await Future.wait([
      _playerA.initialize(),
      _playerB.initialize(),
    ]);

    if (!mounted) return;

    // Player A starts playing, B is paused at 0 ready to go.
    _playerA.setLooping(false);
    _playerB.setLooping(false);
    _playerA.setVolume(0);
    _playerB.setVolume(0);

    _playerA.play();
    _playerA.addListener(_onTickA);
    _playerB.addListener(_onTickB);

    setState(() {});
  }

  void _onTickA() {
    if (!_showA || _crossfading) return;
    _checkCrossfade(_playerA, _playerB, true);
  }

  void _onTickB() {
    if (_showA || _crossfading) return;
    _checkCrossfade(_playerB, _playerA, false);
  }

  void _checkCrossfade(
    VideoPlayerController active,
    VideoPlayerController standby,
    bool activeIsA,
  ) {
    final pos = active.value.position;
    final dur = active.value.duration;
    if (dur.inMilliseconds == 0) return;

    final remaining = dur - pos;
    if (remaining <= _triggerBeforeEnd && remaining > Duration.zero) {
      _startCrossfade(standby, activeIsA);
    }
  }

  Future<void> _startCrossfade(
    VideoPlayerController standby,
    bool fadingFromA,
  ) async {
    if (_crossfading) return;
    _crossfading = true;

    // Seek standby to beginning and start it.
    await standby.seekTo(Duration.zero);
    await standby.play();

    // Animate the fade.
    _fadeController.reset();
    await _fadeController.forward();

    if (!mounted) return;

    setState(() {
      _showA = !fadingFromA;
    });

    _crossfading = false;
  }

  @override
  void dispose() {
    _playerA.removeListener(_onTickA);
    _playerB.removeListener(_onTickB);
    _playerA.dispose();
    _playerB.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aReady = _playerA.value.isInitialized;
    final bReady = _playerB.value.isInitialized;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Bottom layer (incoming)
          if (_showA && bReady || !_showA && aReady)
            _videoFitted(_showA ? _playerB : _playerA),

          // Top layer (outgoing) with animated opacity
          if (_showA && aReady || !_showA && bReady)
            AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                return Opacity(
                  opacity: 1.0 - _fadeController.value,
                  child: child,
                );
              },
              child: _videoFitted(_showA ? _playerA : _playerB),
            ),

          // BC brand color overlay — rose gradient filter
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFAD1457).withValues(alpha: 0.55),
                  const Color(0xFFC2185B).withValues(alpha: 0.40),
                  const Color(0xFFE91E63).withValues(alpha: 0.30),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoFitted(VideoPlayerController controller) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
