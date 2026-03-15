import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../screens/screenshot_editor_screen.dart';

/// Key for the RepaintBoundary that wraps the app content.
/// Set in main.dart's builder, read here for programmatic capture.
final screenshotBoundaryKey = GlobalKey();

/// Persistent floating button for iOS testers to report screenshots.
/// On Android, screenshots are auto-detected — this button is iOS-only.
/// Tapping captures the current screen, flashes white, then opens the editor.
class ScreenshotReportButton extends StatefulWidget {
  const ScreenshotReportButton({super.key});

  @override
  State<ScreenshotReportButton> createState() => _ScreenshotReportButtonState();
}

class _ScreenshotReportButtonState extends State<ScreenshotReportButton> {
  Offset _position = const Offset(-1, -1);
  bool _capturing = false;
  bool _flashing = false;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    if (_position.dx < 0) {
      _position = Offset(
        mq.size.width - 64,
        mq.size.height - mq.padding.bottom - 120,
      );
    }

    return Stack(
      children: [
        // Flash overlay
        if (_flashing)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _flashing ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(color: Colors.white),
              ),
            ),
          ),
        // FAB
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position += details.delta;
                _position = Offset(
                  _position.dx.clamp(0, mq.size.width - 48),
                  _position.dy.clamp(mq.padding.top, mq.size.height - 48),
                );
              });
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _capturing ? null : _captureAndReport,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _capturing
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _captureAndReport() async {
    setState(() => _capturing = true);

    try {
      // Find the RepaintBoundary
      final boundary = screenshotBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        HapticFeedback.heavyImpact();
        setState(() => _capturing = false);
        return;
      }

      // Flash effect
      setState(() => _flashing = true);
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() => _flashing = false);

      // Capture at device pixel ratio for full resolution
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null || !mounted) return;

      final bytes = byteData.buffer.asUint8List();

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScreenshotEditorScreen(screenshotBytes: bytes),
        ),
      );
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }
}
