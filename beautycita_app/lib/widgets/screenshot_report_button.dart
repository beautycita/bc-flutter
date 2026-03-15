import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/screenshot_editor_screen.dart';

/// Persistent floating button for iOS testers to report screenshots.
/// On Android, screenshots are auto-detected — this button is iOS-only.
/// Positioned as a small draggable FAB so it doesn't obstruct the UI.
class ScreenshotReportButton extends StatefulWidget {
  const ScreenshotReportButton({super.key});

  @override
  State<ScreenshotReportButton> createState() => _ScreenshotReportButtonState();
}

class _ScreenshotReportButtonState extends State<ScreenshotReportButton> {
  // Draggable position — starts bottom-right
  Offset _position = const Offset(-1, -1); // sentinel for "not initialized"
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    // Only show on iOS
    if (!Platform.isIOS) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    // Initialize position on first build: bottom-right with padding
    if (_position.dx < 0) {
      _position = Offset(
        mq.size.width - 64,
        mq.size.height - mq.padding.bottom - 120,
      );
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
            // Clamp to screen bounds
            _position = Offset(
              _position.dx.clamp(0, mq.size.width - 48),
              _position.dy.clamp(mq.padding.top, mq.size.height - 48),
            );
          });
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _picking ? null : _pickAndReport,
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
              child: _picking
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
    );
  }

  Future<void> _pickAndReport() async {
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

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
      if (mounted) setState(() => _picking = false);
    }
  }
}
