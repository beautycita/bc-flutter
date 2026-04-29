import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';

/// Web equivalent of the mobile QR program (free-tier) screen. Two QRs:
///   * Internal — registers a salon's existing walk-in clientele on
///     beautycita.com/registro/{slug}. Salon owner is solely responsible
///     for SAT reporting on these transactions (no commission, no
///     ISR/IVA withholding by BC).
///   * External — beautycita.com/expresscita/{biz_slug}; what BC promotes
///     and what new clients book through. Standard 3% commission +
///     ISR/IVA withholdings apply on this path.
///
/// Designed for desktop (side-by-side QRs); collapses to a single column
/// under 900px. Includes the activation modal with 4 consent checkboxes,
/// one of which is the explicit SAT-responsibility acknowledgement.
class BizQrProgramPage extends ConsumerWidget {
  const BizQrProgramPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _QrProgramBody(biz: biz);
      },
    );
  }
}

class _QrProgramBody extends ConsumerStatefulWidget {
  const _QrProgramBody({required this.biz});
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_QrProgramBody> createState() => _QrProgramBodyState();
}

class _QrProgramBodyState extends ConsumerState<_QrProgramBody> {
  bool _busy = false;

  String get _bizId => widget.biz['id'] as String;
  String? get _internalSlug => widget.biz['internal_qr_slug'] as String?;
  String get _externalRef =>
      (widget.biz['slug'] as String?) ?? _bizId;
  bool get _isActive => widget.biz['free_tier_agreements_accepted_at'] != null;

  String get _internalUrl =>
      'https://beautycita.com/registro/${_internalSlug ?? ''}';
  String get _externalUrl => 'https://beautycita.com/expresscita/$_externalRef';

  Future<void> _activate() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ActivationDialog(),
    );
    if (accepted != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // Generate slug if missing (8-char URL-safe)
      String? slugToSet;
      if (_internalSlug == null || _internalSlug!.isEmpty) {
        slugToSet = _generateSlug();
      }
      final patch = <String, dynamic>{
        'free_tier_agreements_accepted_at': DateTime.now().toUtc().toIso8601String(),
        if (slugToSet != null) 'internal_qr_slug': slugToSet,
      };
      await BCSupabase.client
          .from(BCTables.businesses)
          .update(patch)
          .eq('id', _bizId);
      ref.invalidate(currentBusinessProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Programa QR activado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _generateSlug() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = math.Random.secure();
    return List.generate(8, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado')),
    );
  }

  void _openPoster(String posterType) {
    // Defer to the same edge function the mobile app uses. The poster
    // route is whitelisted as public-readable; we just open it in a new
    // tab and let the user print/save as PDF.
    final url = Uri.parse(
      'https://beautycita.com/supabase/functions/v1/generate-qr-poster'
      '?business_id=$_bizId&poster_type=$posterType',
    );
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = WebBreakpoints.isMobile(constraints.maxWidth);
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? BCSpacing.md : BCSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(isMobile),
                  const SizedBox(height: BCSpacing.lg),
                  if (!_isActive)
                    _buildActivateCard()
                  else
                    _buildActiveBanner(),
                  const SizedBox(height: BCSpacing.lg),
                  if (isMobile || constraints.maxWidth < 900)
                    Column(
                      children: [
                        _qrCard(_internalCardData()),
                        const SizedBox(height: BCSpacing.md),
                        _qrCard(_externalCardData()),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _qrCard(_internalCardData())),
                        const SizedBox(width: BCSpacing.md),
                        Expanded(child: _qrCard(_externalCardData())),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Programa QR — Tier gratuito',
          style: TextStyle(
            fontSize: isMobile ? 22 : 28,
            fontWeight: FontWeight.w700,
            color: kWebTextPrimary,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Dos QRs: uno interno para registrar a tus clientes existentes (sin comisión), y uno externo de BeautyCita para clientes nuevos (3% de comisión + retenciones).',
          style: TextStyle(
            fontSize: isMobile ? 13 : 14,
            color: kWebTextSecondary,
            fontFamily: 'system-ui',
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActivateCard() {
    return Container(
      padding: const EdgeInsets.all(BCSpacing.lg),
      decoration: BoxDecoration(
        color: kWebPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
        border: Border.all(color: kWebPrimary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_2_outlined, size: 32, color: kWebPrimary),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Activa el programa QR para empezar a recibir clientes vía BeautyCita y registrar a los tuyos en tu propia cuenta.',
              style: TextStyle(
                fontSize: 14,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _busy ? null : _activate,
            child: const Text('Activar programa'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green),
          SizedBox(width: 10),
          Text(
            'Programa activo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.green,
              fontFamily: 'system-ui',
            ),
          ),
        ],
      ),
    );
  }

  _QrCardData _internalCardData() => _QrCardData(
        title: 'QR Interno — Registro de clientes',
        subtitle:
            'Pon este QR en un lugar visible dentro del salón. Tus clientes lo escanean para registrarse en BeautyCita usando tu salón.',
        icon: Icons.badge_rounded,
        url: _internalUrl,
        urlReady: _internalSlug != null && _internalSlug!.isNotEmpty,
        accent: kWebPrimary,
        onPoster: _isActive ? () => _openPoster('internal') : null,
        onCopy: _internalSlug != null
            ? () => _copy(_internalUrl, 'Enlace interno')
            : null,
      );

  _QrCardData _externalCardData() => _QrCardData(
        title: 'QR Externo — BeautyCita',
        subtitle:
            'Este QR debe estar en la entrada de tu salón (mínimo 10×10 cm, visible desde afuera). Requisito para mantener el programa gratuito activo.',
        icon: Icons.storefront_rounded,
        url: _externalUrl,
        urlReady: true,
        accent: kWebSecondary,
        onPoster: _isActive ? () => _openPoster('external') : null,
        onCopy: () => _copy(_externalUrl, 'Enlace externo'),
      );

  Widget _qrCard(_QrCardData d) {
    return Container(
      padding: const EdgeInsets.all(BCSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
        border: Border.all(color: kWebCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(d.icon, color: d.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  d.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kWebTextPrimary,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d.subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: kWebTextSecondary,
              fontFamily: 'system-ui',
              height: 1.45,
            ),
          ),
          const SizedBox(height: BCSpacing.md),
          if (d.urlReady)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kWebCardBorder),
              ),
              child: QrImageView(
                data: d.url,
                version: QrVersions.auto,
                size: 220,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: d.accent,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: kWebTextPrimary,
                ),
              ),
            )
          else
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kWebCardBorder),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Activa el programa para generar este QR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: kWebTextSecondary,
                      fontFamily: 'system-ui',
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (d.urlReady)
            SelectableText(
              d.url,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: kWebTextSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          const SizedBox(height: BCSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: d.onCopy,
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Copiar enlace'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: d.onPoster,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Imprimir póster'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String url;
  final bool urlReady;
  final Color accent;
  final VoidCallback? onPoster;
  final VoidCallback? onCopy;
  const _QrCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.url,
    required this.urlReady,
    required this.accent,
    required this.onPoster,
    required this.onCopy,
  });
}

// ── Activation modal — 4 consent checkboxes ─────────────────────────────────

class _ActivationDialog extends StatefulWidget {
  const _ActivationDialog();
  @override
  State<_ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<_ActivationDialog> {
  bool _tos = false;
  bool _privacy = false;
  bool _cookies = false;
  bool _satResponsible = false;

  bool get _canSubmit => _tos && _privacy && _cookies && _satResponsible;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Activación del programa'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Al activar el programa QR de BeautyCita aceptas:\n\n'
                '1. Mostrar el QR externo (con marca BeautyCita) en la entrada de tu salón, '
                'en tamaño mínimo 10×10 cm, visible desde el exterior durante el horario de operación.\n\n'
                '2. Usar el QR interno para registrar a tus clientes preexistentes. Las reservas hechas '
                'por el QR interno son transacciones externas: BeautyCita no cobra comisión, no aplica '
                'retenciones de ISR o IVA, y no las incluye en reportes al SAT emitidos por BeautyCita. '
                'Tu salón es el único responsable del tratamiento fiscal de estos ingresos.\n\n'
                '3. Las reservas hechas a través de la aplicación o sitio web de BeautyCita están sujetas '
                'a la comisión estándar del 3% sobre el monto del servicio, más las retenciones fiscales '
                'que la ley nos obliga a aplicar: ISR 2.5% e IVA 8%. Las retenciones se enteran al SAT '
                'en tu nombre y no son ingreso de BeautyCita.\n\n'
                '4. BeautyCita se reserva el derecho de revocar el acceso al programa si detecta '
                'incumplimiento verificable de las condiciones anteriores.\n\n'
                'El detalle completo está en los Términos y Condiciones (sección 4g), el Aviso de Privacidad y la '
                'Política de Cookies publicados en beautycita.com.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Color(0xFF374151),
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _tos,
                onChanged: (v) => setState(() => _tos = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text('Acepto los Términos y Condiciones'),
              ),
              CheckboxListTile(
                value: _privacy,
                onChanged: (v) => setState(() => _privacy = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text('Acepto el Aviso de Privacidad'),
              ),
              CheckboxListTile(
                value: _cookies,
                onChanged: (v) => setState(() => _cookies = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text('Acepto la Política de Cookies'),
              ),
              CheckboxListTile(
                value: _satResponsible,
                onChanged: (v) => setState(() => _satResponsible = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text(
                  'Entiendo que soy responsable de los pagos al SAT por todas las transacciones del tier gratuito',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? () => Navigator.pop(context, true) : null,
          child: const Text('Acepto y activar'),
        ),
      ],
    );
  }
}

