import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/toast_service.dart';
import '../../widgets/empty_state.dart';

class BusinessQrScreen extends ConsumerWidget {
  const BusinessQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final colors = Theme.of(context).colorScheme;

    return bizAsync.when(
      data: (biz) {
        if (biz == null) {
          return const EmptyState(icon: Icons.storefront_outlined, message: 'Sin negocio');
        }

        final bizId = biz['id'] as String;
        final bizName = biz['name'] as String? ?? 'Mi Salon';
        final qrUrl = 'https://beautycita.com/cita-express/$bizId?utm_source=qr';

        return _QrContent(
          qrUrl: qrUrl,
          businessName: bizName,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(color: colors.error)),
      ),
    );
  }
}

class _QrContent extends StatefulWidget {
  final String qrUrl;
  final String businessName;

  const _QrContent({
    required this.qrUrl,
    required this.businessName,
  });

  @override
  State<_QrContent> createState() => _QrContentState();
}

class _QrContentState extends State<_QrContent> {
  final _repaintKey = GlobalKey();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      child: Column(
        children: [
          const SizedBox(height: AppConstants.paddingMD),

          // QR display card
          RepaintBoundary(
            key: _repaintKey,
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colors.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Business name
                    Text(
                      widget.businessName,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cita Express - Escanea para reservar',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // QR Code
                    QrImageView(
                      data: widget.qrUrl,
                      version: QrVersions.auto,
                      size: 220,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: colors.primary,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: colors.onSurface,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // URL display
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.qrUrl,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // BeautyCita branding
                    Text(
                      'BeautyCita',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _saveQrImage,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Descargar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _shareQr,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: const Text('Compartir'),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // Info card
          Card(
            elevation: 0,
            color: colors.primary.withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 20,
                      color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Imprime este codigo QR y colocalo en tu salon. '
                      'Los clientes pueden escanearlo para reservar directamente contigo.',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingXL),
        ],
      ),
    );
  }

  Future<File?> _captureQrToFile() async {
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Could not capture QR');

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Could not convert to PNG');

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/beautycita_qr.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _saveQrImage() async {
    setState(() => _saving = true);
    try {
      final file = await _captureQrToFile();
      if (file == null) throw Exception('Could not capture QR');

      // Share the image file so the user can save it to gallery or files
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR de ${widget.businessName} - BeautyCita',
      );
      ToastService.showInfo('QR listo para guardar');
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareQr() async {
    setState(() => _saving = true);
    try {
      await Share.share('Escanea para reservar: ${widget.qrUrl}');
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
