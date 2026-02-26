import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/services/qr_auth_service.dart';
import 'package:beautycita/services/biometric_service.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  final QrAuthService _authService = QrAuthService();
  final BiometricService _biometricService = BiometricService();
  final TextEditingController _codeController = TextEditingController();

  bool _isProcessing = false;
  ScanStatus _status = ScanStatus.scanning;
  String? _errorMessage;
  bool _showManualEntry = false;

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Parse QR data and extract code + session
  ({String code, String sessionId})? _parseQrData(String rawValue) {
    final uri = Uri.tryParse(rawValue);
    if (uri == null || uri.scheme != 'beautycita' || uri.host != 'auth' || uri.path != '/qr') {
      return null;
    }
    final code = uri.queryParameters['code'];
    final sessionId = uri.queryParameters['session'];
    if (code == null || sessionId == null) return null;
    return (code: code, sessionId: sessionId);
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing || _status != ScanStatus.scanning) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    final parsed = _parseQrData(rawValue);
    if (parsed == null) {
      setState(() {
        _status = ScanStatus.error;
        _errorMessage = 'Este QR no es de BeautyCita';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() { _status = ScanStatus.scanning; _errorMessage = null; });
      return;
    }

    await _authorizeWithConfirmation(parsed.code, parsed.sessionId);
  }

  /// Show confirmation dialog, require biometric, then authorize
  Future<void> _authorizeWithConfirmation(String code, String sessionId) async {
    setState(() {
      _isProcessing = true;
      _status = ScanStatus.confirming;
    });

    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    // Show confirmation
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Icon(
                  Icons.link_rounded,
                  size: AppConstants.iconSizeXL,
                  color: primary,
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'Vincular dispositivo?',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Text(
                  'Vas a iniciar sesion en BeautyCita Web.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: onSurfaceLight,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Se requiere tu huella o rostro para confirmar.',
                          style: GoogleFonts.nunito(fontSize: 13, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.paddingLG),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLG),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          minimumSize:
                              const Size(0, AppConstants.minTouchHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLG),
                          ),
                        ),
                        child: const Text(
                          'Vincular',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) {
      setState(() { _isProcessing = false; _status = ScanStatus.scanning; });
      return;
    }

    // Biometric check
    final authenticated = await _biometricService.authenticate();
    if (!authenticated || !mounted) {
      setState(() {
        _isProcessing = false;
        _status = ScanStatus.error;
        _errorMessage = 'Autenticacion biometrica fallida';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() { _status = ScanStatus.scanning; _errorMessage = null; });
      return;
    }

    // Authorize
    setState(() { _status = ScanStatus.processing; });

    final result = await _authService.authorizeSession(code, sessionId);

    if (!mounted) return;

    switch (result) {
      case QrAuthSuccess():
        setState(() {
          _isProcessing = false;
          _status = ScanStatus.success;
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) context.pop();
      case QrAuthError(:final message):
        setState(() {
          _isProcessing = false;
          _status = ScanStatus.error;
          _errorMessage = message;
        });
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) setState(() { _status = ScanStatus.scanning; _errorMessage = null; });
    }
  }

  /// Handle manual code submission
  Future<void> _submitManualCode() async {
    final code = _codeController.text.trim();
    if (code.length < 6) return;

    // Manual entry doesn't have a session ID — the edge function
    // finds the session by code alone
    await _authorizeWithConfirmation(code, '');
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Vincular con la Web',
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
      body: Column(
        children: [
          // Camera / scanner area
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                if (!_showManualEntry) ...[
                  MobileScanner(
                    controller: _controller,
                    onDetect: _handleBarcode,
                  ),
                  CustomPaint(
                    painter: _ViewfinderPainter(accentColor: primary),
                    size: Size.infinite,
                  ),
                  // Instruction text
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
                          'Escanea el QR de beautycita.com',
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
                ] else ...[
                  _buildManualEntry(),
                ],
                if (_status != ScanStatus.scanning && _status != ScanStatus.confirming)
                  _buildStatusOverlay(),
              ],
            ),
          ),
          // Bottom toggle
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() { _showManualEntry = !_showManualEntry; });
                      },
                      icon: Icon(
                        _showManualEntry ? Icons.qr_code_scanner_rounded : Icons.keyboard_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      label: Text(
                        _showManualEntry ? 'Escanear QR' : 'Ingresar codigo manual',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.keyboard_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Ingresa el codigo que aparece\nen la pagina web',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                maxLength: 8,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'ABCD1234',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: Colors.white24,
                    letterSpacing: 4,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _submitManualCode(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 48,
              child: FilledButton(
                onPressed: _isProcessing ? null : _submitManualCode,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'VINCULAR',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverlay() {
    final isSuccess = _status == ScanStatus.success;
    final isError = _status == ScanStatus.error;
    final isProcessing = _status == ScanStatus.processing;
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
                CircularProgressIndicator(
                  color: primary,
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
              const SizedBox(height: AppConstants.paddingLG),
              Text(
                isProcessing
                    ? 'Vinculando...'
                    : isSuccess
                        ? 'Sesion vinculada!'
                        : _errorMessage ?? 'Error desconocido',
                style: GoogleFonts.poppins(
                  fontSize: isError ? 16 : 20,
                  fontWeight: FontWeight.w700,
                  color: isError ? Colors.red.shade700 : onSurface,
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
  confirming,
  processing,
  success,
  error,
}

class _ViewfinderPainter extends CustomPainter {
  final Color accentColor;

  _ViewfinderPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final viewfinderSize = size.width * 0.7;
    final viewfinderLeft = (size.width - viewfinderSize) / 2;
    final viewfinderTop = (size.height - viewfinderSize) / 2;

    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(viewfinderLeft, viewfinderTop, viewfinderSize, viewfinderSize),
      const Radius.circular(24),
    );

    path.addRRect(cutoutRect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(cutoutRect, borderPaint);

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;

    // Top-left
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

    // Top-right
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

    // Bottom-left
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

    // Bottom-right
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
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor;
}
