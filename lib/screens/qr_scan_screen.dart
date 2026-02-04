import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/services/qr_auth_service.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final QrAuthService _authService = QrAuthService();

  bool _isProcessing = false;
  ScanStatus _status = ScanStatus.scanning;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing || _status != ScanStatus.scanning) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _status = ScanStatus.processing;
    });

    final success = await _authService.authorizeSession(code);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _status = success ? ScanStatus.success : ScanStatus.error;
    });

    if (success) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) context.pop();
    } else {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _status = ScanStatus.scanning;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Escanear QR',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),

          // Overlay with viewfinder
          CustomPaint(
            painter: _ViewfinderPainter(),
            size: Size.infinite,
          ),

          // Top instruction text
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLG,
                  vertical: AppConstants.paddingMD,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                ),
                child: Text(
                  'Escanea el codigo QR de la web',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Status overlay
          if (_status != ScanStatus.scanning) _buildStatusOverlay(),
        ],
      ),
    );
  }

  Widget _buildStatusOverlay() {
    final isSuccess = _status == ScanStatus.success;
    final isError = _status == ScanStatus.error;
    final isProcessing = _status == ScanStatus.processing;

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppConstants.paddingXL),
          margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenPaddingHorizontal,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isProcessing)
                const CircularProgressIndicator(
                  color: BeautyCitaTheme.primaryRose,
                )
              else if (isSuccess)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                )
              else if (isError)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade500,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              const SizedBox(height: BeautyCitaTheme.spaceLG),
              Text(
                isProcessing
                    ? 'Vinculando...'
                    : isSuccess
                        ? 'Sesion vinculada!'
                        : 'Codigo invalido o expirado',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isError ? Colors.red.shade700 : BeautyCitaTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ScanStatus {
  scanning,
  processing,
  success,
  error,
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Draw dark overlay with cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final viewfinderSize = size.width * 0.7;
    final viewfinderLeft = (size.width - viewfinderSize) / 2;
    final viewfinderTop = (size.height - viewfinderSize) / 2;

    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        viewfinderLeft,
        viewfinderTop,
        viewfinderSize,
        viewfinderSize,
      ),
      const Radius.circular(24),
    );

    path.addRRect(cutoutRect);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw viewfinder border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(cutoutRect, borderPaint);

    // Draw corner accents
    final accentPaint = Paint()
      ..color = BeautyCitaTheme.primaryRose
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
      Offset(viewfinderLeft, viewfinderTop + 24),
      Offset(viewfinderLeft, viewfinderTop + 24 + cornerLength),
      accentPaint,
    );
    canvas.drawLine(
      Offset(viewfinderLeft + 24, viewfinderTop),
      Offset(viewfinderLeft + 24 + cornerLength, viewfinderTop),
      accentPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(viewfinderLeft + viewfinderSize, viewfinderTop + 24),
      Offset(viewfinderLeft + viewfinderSize, viewfinderTop + 24 + cornerLength),
      accentPaint,
    );
    canvas.drawLine(
      Offset(viewfinderLeft + viewfinderSize - 24, viewfinderTop),
      Offset(viewfinderLeft + viewfinderSize - 24 - cornerLength, viewfinderTop),
      accentPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(viewfinderLeft, viewfinderTop + viewfinderSize - 24),
      Offset(viewfinderLeft, viewfinderTop + viewfinderSize - 24 - cornerLength),
      accentPaint,
    );
    canvas.drawLine(
      Offset(viewfinderLeft + 24, viewfinderTop + viewfinderSize),
      Offset(viewfinderLeft + 24 + cornerLength, viewfinderTop + viewfinderSize),
      accentPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(viewfinderLeft + viewfinderSize, viewfinderTop + viewfinderSize - 24),
      Offset(viewfinderLeft + viewfinderSize, viewfinderTop + viewfinderSize - 24 - cornerLength),
      accentPaint,
    );
    canvas.drawLine(
      Offset(viewfinderLeft + viewfinderSize - 24, viewfinderTop + viewfinderSize),
      Offset(viewfinderLeft + viewfinderSize - 24 - cornerLength, viewfinderTop + viewfinderSize),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
