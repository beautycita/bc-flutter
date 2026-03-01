import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/services/toast_service.dart';

/// Consistent card decoration — same as btc_wallet_screen
BoxDecoration _cardDecoration(ColorScheme cs) => BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      border: Border.all(
        color: cs.onSurface.withValues(alpha: 0.12),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

/// Data passed to cash payment screen via route extra
class CashPaymentData {
  final double amountMxn;
  final String referenceNumber;
  final DateTime createdAt;
  final String? bookingId;
  final String? serviceName;

  const CashPaymentData({
    required this.amountMxn,
    required this.referenceNumber,
    required this.createdAt,
    this.bookingId,
    this.serviceName,
  });

  /// Expires at midnight of the creation day
  DateTime get expiresAt {
    final d = createdAt;
    return DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

}

class CashPaymentScreen extends ConsumerWidget {
  final CashPaymentData? data;

  const CashPaymentScreen({super.key, this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pago en efectivo')),
        body: const Center(child: Text('Sin datos de pago')),
      );
    }
    final payment = data!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceLight = colorScheme.onSurface.withValues(alpha: 0.5);
    final mxnFormat = NumberFormat('#,##0.00', 'es_MX');

    final now = DateTime.now();
    final remaining = payment.expiresAt.difference(now);
    final isExpired = remaining.isNegative;
    final timeLabel = _formatRemaining(remaining);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_rounded, color: Color(0xFFCC0000), size: 24),
            const SizedBox(width: 8),
            const Text('Pago en efectivo'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Amount Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            decoration: _cardDecoration(colorScheme),
            child: Column(
              children: [
                Text(
                  'Monto a pagar',
                  style: textTheme.labelMedium?.copyWith(
                    color: onSurfaceLight,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${mxnFormat.format(payment.amountMxn)} MXN',
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (payment.serviceName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    payment.serviceName!,
                    style: textTheme.bodyMedium?.copyWith(color: onSurfaceLight),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── QR Code ──
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            decoration: _cardDecoration(colorScheme),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    border: Border.all(
                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: QrImageView(
                    data: payment.referenceNumber.replaceAll(' ', ''),
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF1A1A1A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Text(
                  'Numero de referencia',
                  style: textTheme.labelMedium?.copyWith(color: onSurfaceLight),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  payment.referenceNumber,
                  style: textTheme.headlineSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: payment.referenceNumber.replaceAll(' ', '')),
                    );
                    ToastService.showSuccess('Referencia copiada');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copiar'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Expiration ──
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            decoration: BoxDecoration(
              color: (isExpired ? Colors.red : Colors.amber).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(
                color: (isExpired ? Colors.red : Colors.amber).withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isExpired ? Icons.error_rounded : Icons.schedule_rounded,
                  color: isExpired ? Colors.red.shade700 : Colors.amber.shade700,
                  size: 22,
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExpired
                            ? 'Voucher expirado'
                            : 'Valido hasta hoy a las 11:59 PM',
                        style: textTheme.bodyMedium?.copyWith(
                          color: isExpired ? Colors.red.shade700 : Colors.amber.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isExpired
                            ? 'Genera un nuevo codigo cuando estes listo.'
                            : 'Tiempo restante: $timeLabel',
                        style: textTheme.bodySmall?.copyWith(
                          color: isExpired ? Colors.red.shade600 : Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Instructions ──
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            decoration: _cardDecoration(colorScheme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Como pagar',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                _InstructionStep(
                  number: 1,
                  icon: Icons.store_rounded,
                  text: 'Acude a cualquier tienda OXXO o 7-Eleven',
                ),
                _InstructionStep(
                  number: 2,
                  icon: Icons.qr_code_scanner_rounded,
                  text: 'Muestra el codigo QR o dicta el numero de referencia',
                ),
                _InstructionStep(
                  number: 3,
                  icon: Icons.payments_rounded,
                  text: 'Paga el monto exacto en efectivo',
                ),
                _InstructionStep(
                  number: 4,
                  icon: Icons.check_circle_rounded,
                  text: 'Recibiras una confirmacion en la app automaticamente',
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Participating Stores ──
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingSM + 4,
            ),
            decoration: _cardDecoration(colorScheme),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, size: 18, color: onSurfaceLight),
                const SizedBox(width: 8),
                Text(
                  'Tiendas participantes',
                  style: textTheme.labelMedium?.copyWith(color: onSurfaceLight),
                ),
                const Spacer(),
                _StoreChip(label: 'OXXO', color: const Color(0xFFCC0000)),
                const SizedBox(width: 8),
                _StoreChip(label: '7-Eleven', color: const Color(0xFF008C45)),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Action Buttons ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Share.share(
                      'BeautyCita - Pago en efectivo\n'
                      'Monto: \$${mxnFormat.format(payment.amountMxn)} MXN\n'
                      'Referencia: ${payment.referenceNumber}\n'
                      'Valido hasta: ${DateFormat('dd MMM yyyy, 11:59 PM', 'es').format(payment.createdAt)}\n\n'
                      'Presenta este codigo en OXXO o 7-Eleven.',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Compartir'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppConstants.minTouchHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                    ),
                    side: BorderSide(
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (isExpired) ...[
                const SizedBox(width: AppConstants.paddingMD),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ToastService.showInfo('Proximamente - generacion automatica');
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Nuevo codigo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC0000),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, AppConstants.minTouchHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: AppConstants.paddingXL),
        ],
      ),
    );
  }

  String _formatRemaining(Duration d) {
    if (d.isNegative) return 'Expirado';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _InstructionStep extends StatelessWidget {
  final int number;
  final IconData icon;
  final String text;
  final bool isLast;

  const _InstructionStep({
    required this.number,
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceLight = colorScheme.onSurface.withValues(alpha: 0.5);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppConstants.paddingMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                '$number',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.paddingSM),
          Icon(icon, size: 20, color: onSurfaceLight),
          const SizedBox(width: AppConstants.paddingSM),
          Expanded(
            child: Text(text, style: textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StoreChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StoreChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusXS),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
