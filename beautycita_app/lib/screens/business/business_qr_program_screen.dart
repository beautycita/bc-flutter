// =============================================================================
// BusinessQrProgramScreen — Free-tier QR program management
// =============================================================================
// Two surfaces:
//   1. Agreement acceptance (ToS + Privacy + Cookies checkboxes, disclosure of
//      3% + ISR 2.5% + IVA 8% on BC-platform bookings; external free).
//   2. Post-acceptance: poster downloads for Internal QR + External QR.
//
// The 90-day clock is NOT surfaced per BC directive — only mentioned in ToS.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class BusinessQrProgramScreen extends ConsumerStatefulWidget {
  const BusinessQrProgramScreen({super.key});

  @override
  ConsumerState<BusinessQrProgramScreen> createState() =>
      _BusinessQrProgramScreenState();
}

class _BusinessQrProgramScreenState extends ConsumerState<BusinessQrProgramScreen> {
  bool _loading = true;
  Map<String, dynamic>? _biz;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      setState(() {
        _biz = biz;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando negocio: $e';
        _loading = false;
      });
    }
  }

  bool get _acceptedAgreement =>
      _biz?['free_tier_agreements_accepted_at'] != null;

  Future<void> _acceptAgreement() async {
    if (_biz == null) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _AgreementSheet(),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      // Generate internal_qr_slug if missing (short opaque code)
      final existingSlug = _biz!['internal_qr_slug'] as String?;
      String slug = existingSlug ?? _generateSlug();

      await SupabaseClientService.client.from('businesses').update({
        'free_tier_agreements_accepted_at': DateTime.now().toIso8601String(),
        if (existingSlug == null) 'internal_qr_slug': slug,
      }).eq('id', _biz!['id']);

      if (!mounted) return;
      ToastService.showSuccess('Programa activado');
      ref.invalidate(currentBusinessProvider);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ToastService.showErrorWithDetails('No se pudo activar', e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _generateSlug() {
    // Short opaque code: 10 lowercase alphanumerics (no vowels to avoid words)
    const chars = 'bcdfghjklmnpqrstvwxyz23456789';
    final buf = StringBuffer();
    final rand = DateTime.now().microsecondsSinceEpoch;
    var seed = rand;
    for (int i = 0; i < 10; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buf.write(chars[seed % chars.length]);
    }
    return buf.toString();
  }

  Future<void> _openPoster(String posterType) async {
    if (_biz == null) return;
    final token = SupabaseClientService.client.auth.currentSession?.accessToken;
    if (token == null) {
      ToastService.showError('Sesion expirada');
      return;
    }
    // The edge function returns HTML with a print button. Open in a new
    // external browser tab so the user can print / save as PDF.
    final supabaseUrl = SupabaseClientService.client.rest.url;
    final base = supabaseUrl.endsWith('/rest/v1')
        ? supabaseUrl.substring(0, supabaseUrl.length - 8)
        : supabaseUrl;
    final url = Uri.parse(
      '$base/functions/v1/generate-qr-poster'
      '?business_id=${_biz!['id']}&poster_type=$posterType',
    );

    // For a print-to-pdf HTML response, we ideally want to open in a
    // system browser. url_launcher handles that on Android.
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: copy link
      await Clipboard.setData(ClipboardData(text: url.toString()));
      ToastService.showInfo('Enlace copiado al portapapeles');
    }
  }

  Future<void> _copyInternalUrl() async {
    final slug = _biz?['internal_qr_slug'] as String?;
    if (slug == null) return;
    await Clipboard.setData(ClipboardData(text: 'https://beautycita.com/registro/$slug'));
    if (!mounted) return;
    ToastService.showInfo('Enlace copiado');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Programa QR (Gratis)',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingLG),
                  child: _acceptedAgreement
                      ? _buildActiveView(colors)
                      : _buildAgreementIntro(colors),
                ),
    );
  }

  Widget _buildAgreementIntro(ColorScheme colors) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 72, color: colors.primary),
          const SizedBox(height: 16),
          Text(
            'Gratis para siempre',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Activa el programa QR y registra a tus clientes sin pagar comision. '
            'Ellos escanean, llenan un formulario, y tu confirmas el horario.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 14, height: 1.5, color: Colors.grey[700]),
          ),
          const SizedBox(height: 32),
          _BenefitRow(
            icon: Icons.check_circle_outline,
            color: Colors.green,
            title: 'QR Interno',
            body: 'Tus clientes se registran escaneando un QR en tu salon. No pagas comision sobre estas citas.',
          ),
          const SizedBox(height: 12),
          _BenefitRow(
            icon: Icons.storefront_rounded,
            color: colors.primary,
            title: 'QR Externo (BeautyCita)',
            body: 'Muestra un codigo QR de BeautyCita en la entrada (10×10cm minimo, visible desde afuera). '
                'Es parte del acuerdo del programa gratuito.',
          ),
          const SizedBox(height: 12),
          _BenefitRow(
            icon: Icons.percent_rounded,
            color: Colors.orange,
            title: 'Reservas via BeautyCita',
            body: 'Cuando un cliente reserva a traves de la app o sitio, aplicamos 3% de comision + '
                'retenciones ISR 2.5% + IVA 8%. Las retenciones se entran al SAT en tu nombre.',
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saving ? null : _acceptAgreement,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Activar programa',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(ColorScheme colors) {
    final slug = _biz?['internal_qr_slug'] as String?;
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Programa activo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.green),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _PosterCard(
          title: 'QR Interno — Registro de clientes',
          body: 'Pon este QR en un lugar visible dentro del salon. Tus clientes lo escanean para registrarse.',
          icon: Icons.badge_rounded,
          iconColor: colors.primary,
          primaryAction: 'Descargar / Imprimir',
          onPrimary: () => _openPoster('internal'),
          secondaryAction: 'Copiar enlace',
          onSecondary: slug != null ? _copyInternalUrl : null,
        ),
        const SizedBox(height: 16),
        _PosterCard(
          title: 'QR Externo — BeautyCita',
          body: 'Este QR debe estar en la entrada de tu salon (minimo 10×10 cm, visible desde afuera). '
              'Requisito para mantener el programa gratuito activo.',
          icon: Icons.storefront_rounded,
          iconColor: colors.primary,
          primaryAction: 'Descargar / Imprimir',
          onPrimary: () => _openPoster('external'),
        ),
        const SizedBox(height: 32),
        Text(
          'Enlace directo al formulario:',
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        SelectableText(
          slug != null
              ? 'https://beautycita.com/registro/$slug'
              : '(sin slug aun)',
          style: GoogleFonts.firaCode(fontSize: 12, color: Colors.grey[800]),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _BenefitRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(body,
                    style: GoogleFonts.nunito(fontSize: 12, height: 1.4, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color iconColor;
  final String primaryAction;
  final VoidCallback onPrimary;
  final String? secondaryAction;
  final VoidCallback? onSecondary;

  const _PosterCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.iconColor,
    required this.primaryAction,
    required this.onPrimary,
    this.secondaryAction,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: GoogleFonts.nunito(fontSize: 12, height: 1.4, color: Colors.grey[700])),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPrimary,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(primaryAction, style: GoogleFonts.poppins(fontSize: 13)),
                ),
              ),
              if (secondaryAction != null && onSecondary != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onSecondary,
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: Text(secondaryAction!, style: GoogleFonts.poppins(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AgreementSheet extends StatefulWidget {
  const _AgreementSheet();

  @override
  State<_AgreementSheet> createState() => _AgreementSheetState();
}

class _AgreementSheetState extends State<_AgreementSheet> {
  bool _tos = false;
  bool _privacy = false;
  bool _cookies = false;
  bool _satResponsible = false;

  bool get _canSubmit => _tos && _privacy && _cookies && _satResponsible;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Activacion del programa',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: [
                    _agreementBody(),
                  ],
                ),
              ),
              CheckboxListTile(
                value: _tos,
                onChanged: (v) => setState(() => _tos = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('Acepto los Terminos y Condiciones', style: GoogleFonts.nunito(fontSize: 13)),
              ),
              CheckboxListTile(
                value: _privacy,
                onChanged: (v) => setState(() => _privacy = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('Acepto el Aviso de Privacidad', style: GoogleFonts.nunito(fontSize: 13)),
              ),
              CheckboxListTile(
                value: _cookies,
                onChanged: (v) => setState(() => _cookies = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('Acepto la Politica de Cookies', style: GoogleFonts.nunito(fontSize: 13)),
              ),
              CheckboxListTile(
                value: _satResponsible,
                onChanged: (v) => setState(() => _satResponsible = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(
                  'Entiendo que soy responsable de los pagos al SAT por todas las transacciones del tier gratuito',
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSubmit ? () => Navigator.pop(ctx, true) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.primary,
                        foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                      ),
                      child: const Text('Acepto y activar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _agreementBody() {
    return Text(
      'Al activar el programa QR de BeautyCita aceptas:\n\n'
      '1. Mostrar el QR externo (con marca BeautyCita) en la entrada de tu salon, '
      'en tamano minimo 10×10 cm, visible desde el exterior durante el horario de operacion.\n\n'
      '2. Usar el QR interno para registrar a tus clientes preexistentes. Las reservas hechas '
      'por el QR interno son transacciones externas: BeautyCita no cobra comision, no aplica '
      'retenciones de ISR o IVA, y no las incluye en reportes al SAT emitidos por BeautyCita. '
      'Tu salon es el unico responsable del tratamiento fiscal de estos ingresos.\n\n'
      '3. Las reservas hechas a traves de la aplicacion o sitio web de BeautyCita estan sujetas '
      'a la comision estandar del 3% sobre el monto del servicio, mas las retenciones fiscales '
      'que la ley nos obliga a aplicar: ISR 2.5% e IVA 8%. Las retenciones se entran al SAT '
      'en tu nombre y no son ingreso de BeautyCita.\n\n'
      '4. BeautyCita se reserva el derecho de revocar el acceso al programa si detecta '
      'incumplimiento verificable de las condiciones anteriores.\n\n'
      'El detalle completo esta en los Terminos y Condiciones (seccion 4g), el Aviso de Privacidad y la '
      'Politica de Cookies publicados en beautycita.com.',
      style: GoogleFonts.nunito(fontSize: 12, height: 1.5, color: Colors.grey[800]),
    );
  }
}
