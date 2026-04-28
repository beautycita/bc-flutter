import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:beautycita/config/fonts.dart';

/// Guided ID-capture screen with a frame overlay (INE aspect ~1.586:1),
/// live brightness indicator, and a capture button gated on adequate
/// lighting. Returns the JPEG bytes of the captured photo cropped to
/// the on-screen frame, or null if the user cancels.
///
/// Why a custom screen instead of `image_picker(source: camera)`:
///   * The system camera lets the user shoot landscape OR portrait, with
///     the ID anywhere in the frame. Vision API rejects/struggles with
///     off-axis or partial captures.
///   * No way to surface "demasiado oscuro" feedback before submission.
///   * Frame overlay forces the user to fit the ID where Vision expects.
///
/// Output:
///   * bytes — JPEG, captured at native resolution then cropped to the
///     frame rectangle. Sized to land between ~300KB and ~3MB for typical
///     phone cameras, comfortably inside Vision's accepted range.
class IdCaptureScreen extends StatefulWidget {
  /// Title shown in the header — pass "Frente de tu INE" / "Reverso de tu INE".
  final String title;
  const IdCaptureScreen({super.key, required this.title});

  @override
  State<IdCaptureScreen> createState() => _IdCaptureScreenState();
}

class _IdCaptureScreenState extends State<IdCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _capturing = false;

  // Live brightness: mean luma of the camera image plane Y. Range 0..255.
  // Anything below ~70 reads as "needs more light"; above ~180 = overexposed.
  double _brightness = 0;
  bool _hasFrame = false;

  // INE / Mexican voter ID aspect ratio: 85.6mm × 54mm = 1.586:1
  static const double _idAspect = 1.586;
  // Inset percentage of screen used by the overlay box.
  static const double _overlayInset = 0.08;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No camera available');
    }
    // Prefer the rear camera (back) — IDs are physical objects, not selfies.
    final rear = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      rear,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
    // Subscribe to image stream for brightness sampling. Throttled below.
    await _controller!.startImageStream(_onImageFrame);
  }

  // Throttle brightness sampling to ~5 Hz to keep the UI smooth.
  DateTime _lastSample = DateTime.fromMillisecondsSinceEpoch(0);
  void _onImageFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastSample).inMilliseconds < 200) return;
    _lastSample = now;

    // YUV420: plane[0] is the Y (luma) plane. Mean of a stride-respecting
    // sample is sufficient for a brightness indicator.
    final yPlane = image.planes[0];
    final bytes = yPlane.bytes;
    if (bytes.isEmpty) return;
    // Sample every 16th byte to keep the per-frame cost negligible.
    int sum = 0, count = 0;
    for (var i = 0; i < bytes.length; i += 16) {
      sum += bytes[i];
      count++;
    }
    final mean = sum / count;
    if (!mounted) return;
    setState(() {
      _brightness = mean;
      _hasFrame = true;
    });
  }

  bool get _lightOk => _brightness >= 70 && _brightness <= 215;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initFuture = _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();
    try {
      // Stop the image stream during capture to free the buffer.
      if (c.value.isStreamingImages) await c.stopImageStream();
      final XFile shot = await c.takePicture();
      final raw = await shot.readAsBytes();
      // Crop to a centered 1.586:1 rectangle so Vision sees the ID
      // tightly framed. Without this the on-screen frame is purely
      // decorative and the JPEG includes the full preview surroundings.
      final cropped = await _cropToFrame(raw);
      if (!mounted) return;
      Navigator.of(context).pop(cropped);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar: $e')),
        );
        setState(() => _capturing = false);
      }
    }
  }

  // Crops the captured JPEG to a centered rectangle at the INE aspect
  // ratio, occupying ~92% of the available image area. Robust to
  // landscape/portrait sensor output: we bake EXIF orientation first
  // so width/height match what the user saw on screen.
  Future<Uint8List> _cropToFrame(Uint8List raw) async {
    img.Image? decoded = img.decodeImage(raw);
    if (decoded == null) return raw;
    decoded = img.bakeOrientation(decoded);
    final iw = decoded.width;
    final ih = decoded.height;
    // Fit the largest 1.586:1 box that fits inside 92% of the image.
    final maxW = iw * 0.92;
    final maxH = ih * 0.92;
    double cropW = maxW;
    double cropH = cropW / _idAspect;
    if (cropH > maxH) {
      cropH = maxH;
      cropW = cropH * _idAspect;
    }
    final cl = ((iw - cropW) / 2).round();
    final ct = ((ih - cropH) / 2).round();
    final out = img.copyCrop(
      decoded,
      x: cl,
      y: ct,
      width: cropW.round(),
      height: cropH.round(),
    );
    return Uint8List.fromList(img.encodeJpg(out, quality: 90));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                _controller == null ||
                !_controller!.value.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                // Frame overlay
                CustomPaint(
                  painter: _FramePainter(
                    inset: _overlayInset,
                    aspect: _idAspect,
                    color: _lightOk
                        ? const Color(0xFF22C55E)
                        : Colors.white,
                  ),
                ),
                // Header
                Positioned(
                  top: 12, left: 12, right: 12,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Instructions + brightness indicator
                Positioned(
                  left: 16, right: 16, bottom: 110,
                  child: Column(
                    children: [
                      _BrightnessChip(
                        brightness: _brightness,
                        ok: _lightOk,
                        hasFrame: _hasFrame,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hasFrame
                            ? (_lightOk
                                ? 'Encuadra la INE dentro del recuadro y captura'
                                : (_brightness < 70
                                    ? 'Necesita mas luz — busca un area iluminada'
                                    : 'Demasiada luz / reflejo — gira un poco la INE'))
                            : 'Cargando camara…',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(blurRadius: 6, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
                ),
                // Capture button
                Positioned(
                  bottom: 28, left: 0, right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _lightOk && !_capturing ? _capture : null,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _lightOk
                              ? colors.primary
                              : Colors.white.withValues(alpha: 0.3),
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                        ),
                        child: _capturing
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Icon(
                                _lightOk ? Icons.camera_rounded : Icons.camera_outlined,
                                color: Colors.white,
                                size: 32,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  final double inset;
  final double aspect;
  final Color color;
  _FramePainter({
    required this.inset,
    required this.aspect,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Compute the frame rect: width = (1 - 2*inset) * size.width, height
    // determined by aspect ratio. Centered.
    final w = size.width * (1 - 2 * inset);
    final h = w / aspect;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2;
    final rect = Rect.fromLTWH(left, top, w, h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    // Dim everything outside the frame.
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final outerPath = Path()..addRect(Offset.zero & size);
    final innerPath = Path()..addRRect(rrect);
    final dimPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(dimPath, dimPaint);

    // Frame border.
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(rrect, borderPaint);

    // Corner accents.
    const cornerLen = 28.0;
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    // Top-left
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(left + w - cornerLen, top), Offset(left + w, top), cornerPaint);
    canvas.drawLine(Offset(left + w, top), Offset(left + w, top + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(left, top + h - cornerLen), Offset(left, top + h), cornerPaint);
    canvas.drawLine(Offset(left, top + h), Offset(left + cornerLen, top + h), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(left + w - cornerLen, top + h), Offset(left + w, top + h), cornerPaint);
    canvas.drawLine(Offset(left + w, top + h), Offset(left + w, top + h - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) =>
      old.color != color || old.inset != inset || old.aspect != aspect;
}

class _BrightnessChip extends StatelessWidget {
  final double brightness;
  final bool ok;
  final bool hasFrame;
  const _BrightnessChip({
    required this.brightness,
    required this.ok,
    required this.hasFrame,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (brightness / 255).clamp(0.0, 1.0);
    final tone = ok ? const Color(0xFF22C55E) : Colors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.wb_sunny_rounded : Icons.wb_incandescent_outlined,
            color: tone, size: 16,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: hasFrame ? pct : null,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation<Color>(tone),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ok ? 'Buena luz' : (hasFrame ? (brightness < 70 ? 'Poca luz' : 'Mucho reflejo') : '—'),
            style: GoogleFonts.nunito(
              color: tone, fontSize: 12, fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
