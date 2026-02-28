import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';

/// Business QR Walk-in page — displays/downloads the salon's walk-in QR code.
class BizQrPage extends ConsumerWidget {
  const BizQrPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _QrContent(biz: biz);
      },
    );
  }
}

class _QrContent extends ConsumerStatefulWidget {
  const _QrContent({required this.biz});
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_QrContent> createState() => _QrContentState();
}

class _QrContentState extends ConsumerState<_QrContent> {
  final _repaintKey = GlobalKey();
  bool _saving = false;
  late bool _acceptWalkins;

  String get _bizId => widget.biz['id'] as String;
  String get _bizName => widget.biz['name'] as String? ?? 'Mi Salon';
  String get _qrUrl => 'https://beautycita.com/cita-express/$_bizId';

  @override
  void initState() {
    super.initState();
    _acceptWalkins = widget.biz['accept_walkins'] as bool? ?? true;
  }

  Future<void> _toggleWalkins(bool value) async {
    setState(() => _acceptWalkins = value);
    try {
      await BCSupabase.client
          .from(BCTables.businesses)
          .update({'accept_walkins': value}).eq('id', _bizId);
      ref.invalidate(currentBusinessProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _acceptWalkins = !value);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _downloadQr() async {
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not capture QR');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Could not convert to PNG');

      final bytes = byteData.buffer.asUint8List();
      final base64 = base64Encode(bytes);
      final anchor = html.AnchorElement(
        href: 'data:image/png;base64,$base64',
      )
        ..setAttribute('download', 'qr-walkin-$_bizId.png')
        ..click();
      anchor.remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR descargado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
        final isMobile = WebBreakpoints.isMobile(constraints.maxWidth);
        final padding = isMobile ? 16.0 : 24.0;
        final maxWidth = isDesktop ? 600.0 : double.infinity;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Walk-in',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los clientes escanean este codigo para reservar directamente contigo.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // QR Card
                  RepaintBoundary(
                    key: _repaintKey,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _bizName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cita Express - Escanea para reservar',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // QR Code
                          QrImageView(
                            data: _qrUrl,
                            version: QrVersions.auto,
                            size: isMobile ? 200 : 260,
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
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.onSurface
                                  .withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              _qrUrl,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface
                                    .withValues(alpha: 0.5),
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Business ID
                          Text(
                            'Codigo: $_bizId',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  colors.onSurface.withValues(alpha: 0.35),
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // BeautyCita branding
                          Text(
                            'BeautyCita',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.primary.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Download button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _downloadQr,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(_saving ? 'Descargando...' : 'Descargar QR'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Walk-in toggle
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.qr_code_2_outlined,
                                size: 20, color: colors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Walk-in',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Aceptar walk-ins'),
                          subtitle: const Text(
                            'Los clientes pueden escanear tu QR para reservar cita al momento',
                          ),
                          value: _acceptWalkins,
                          onChanged: _toggleWalkins,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 20, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Imprime este codigo y colocalo en tu salon. '
                            'Los clientes lo escanean con su celular para '
                            'reservar directamente contigo.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface
                                  .withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
