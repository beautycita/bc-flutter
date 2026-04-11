import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/gyro_parallax_service.dart';

const _r2Base = 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/video/';

const _categoryVideoMap = <String, String>{
  'nails': 'curlySelfie.mp4',
  'hair': 'hairTreat.mp4',
  'lashes_brows': 'twinMakeup.mp4',
  'makeup': 'makeupArtist.mp4',
  'facial': 'spaTreat.mp4',
  'body_spa': 'spaTreat.mp4',
  'specialized': 'happyPort.mp4',
  'barberia': 'cutOff.mp4',
};
const _defaultVideo = 'bcApp.mp4';

/// Derive a category ID from a service type string by scanning the category data.
/// Returns the matching category ID or null.
String? categoryIdFromServiceType(String serviceType) {
  // Service types are structured: subcategory_variant (e.g. 'manicure_gel').
  // Map known subcategory prefixes to categories.
  const prefixMap = <String, String>{
    'manicure': 'nails',
    'pedicure': 'nails',
    'nail': 'nails',
    'corte': 'hair',
    'color': 'hair',
    'alaciado': 'hair',
    'keratina': 'hair',
    'tratamiento_capilar': 'hair',
    'peinado': 'hair',
    'extension_cabello': 'hair',
    'facial': 'facial',
    'limpieza_facial': 'facial',
    'microderma': 'facial',
    'peeling': 'facial',
    'lash': 'lashes_brows',
    'brow': 'lashes_brows',
    'extension_pestana': 'lashes_brows',
    'lifting_pestana': 'lashes_brows',
    'tinte_ceja': 'lashes_brows',
    'laminado': 'lashes_brows',
    'masaje': 'body_spa',
    'depilacion': 'body_spa',
    'body': 'body_spa',
    'maquillaje': 'makeup',
    'makeup': 'makeup',
    'barberia': 'barberia',
    'barba': 'barberia',
    'afeitado': 'barberia',
    'microblading': 'specialized',
    'micropigmentacion': 'specialized',
    'dermapen': 'specialized',
    'plasma': 'specialized',
  };

  final lower = serviceType.toLowerCase();
  for (final entry in prefixMap.entries) {
    if (lower.startsWith(entry.key)) return entry.value;
  }
  return null;
}

/// Full-screen blurred video background with gyroscope parallax shift.
///
/// Plays a category-matched looping/muted video from R2 CDN.
/// Falls back to a gradient when the video fails to load.
class BookingFlowBackground extends StatefulWidget {
  /// Category id used to select the video file.
  final String categoryId;

  /// Accent color for the gradient fallback and tint overlay.
  final Color accentColor;

  /// Content layered on top of the background.
  final Widget child;

  const BookingFlowBackground({
    super.key,
    required this.categoryId,
    required this.accentColor,
    required this.child,
  });

  @override
  State<BookingFlowBackground> createState() => _BookingFlowBackgroundState();
}

class _BookingFlowBackgroundState extends State<BookingFlowBackground> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoFailed = false;
  StreamSubscription<ParallaxOffset>? _gyroSub;
  double _offsetX = 0;
  double _offsetY = 0;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _initGyro();
  }

  void _initVideo() {
    final file = _categoryVideoMap[widget.categoryId] ?? _defaultVideo;
    final url = Uri.parse('$_r2Base$file');
    _controller = VideoPlayerController.networkUrl(url)
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _controller?.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _videoFailed = true);
      });
  }

  void _initGyro() {
    final gyro = GyroParallaxService.instance;
    gyro.addListener();
    _gyroSub = gyro.stream.listen((offset) {
      if (!mounted) return;
      setState(() {
        _offsetX = offset.x * 12; // ±12px
        _offsetY = offset.y * 12;
      });
    });
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    GyroParallaxService.instance.removeListener();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video or gradient fallback
        if (_videoReady && !_videoFailed)
          _buildVideoLayer()
        else
          _buildGradientFallback(),

        // Gaussian blur overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: const SizedBox.expand(),
          ),
        ),

        // Dark overlay
        Container(color: Colors.black.withValues(alpha: 0.3)),

        // Category color tint
        Container(color: widget.accentColor.withValues(alpha: 0.08)),

        // Content
        widget.child,
      ],
    );
  }

  Widget _buildVideoLayer() {
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(_offsetX, _offsetY),
        child: Transform.scale(
          scale: 1.15,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientFallback() {
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(_offsetX, _offsetY),
        child: Transform.scale(
          scale: 1.15,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.accentColor.withValues(alpha: 0.6),
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
