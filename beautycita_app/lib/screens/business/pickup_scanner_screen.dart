// =============================================================================
// PickupScannerScreen — salon scans buyer's pickup QR
// =============================================================================
// Opens MobileScanner camera, calls redeem-pickup-qr on detect, shows
// success/failure toast. Receipt-ready: server returns product_name +
// business_name on success.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/constants.dart';
import '../../providers/order_provider.dart';
import '../../services/toast_service.dart';

class PickupScannerScreen extends ConsumerStatefulWidget {
  const PickupScannerScreen({super.key});

  @override
  ConsumerState<PickupScannerScreen> createState() =>
      _PickupScannerScreenState();
}

class _PickupScannerScreenState extends ConsumerState<PickupScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    setState(() => _processing = true);

    try {
      final svc = ref.read(orderServiceProvider);
      final result = await svc.redeemPickupQr(raw.trim());
      if (result == null) {
        ToastService.showError('Sin respuesta del servidor');
        return;
      }
      if (result.containsKey('error')) {
        ToastService.showError(result['error'] as String? ?? 'Error');
        return;
      }
      final product = result['product_name'] as String? ?? 'producto';
      final already = result['already_redeemed'] == true;
      ToastService.showSuccess(
        already
            ? 'Ya recolectado: $product'
            : 'Entregado: $product',
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      ToastService.showErrorWithDetails('Scan error', e);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear recoleccion')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Container(
                padding: const EdgeInsets.all(AppConstants.paddingMD),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                ),
                child: Text(
                  _processing
                      ? 'Validando codigo…'
                      : 'Apunta la camara al QR del cliente',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
