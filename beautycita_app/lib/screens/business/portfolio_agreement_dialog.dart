import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/portfolio_service.dart';

/// Portfolio agreement version — bump when legal text changes.
/// Salons must re-accept when a new version is released.
const kPortfolioAgreementVersion = '1.0';
const kPortfolioAgreementType = 'portfolio_usage';

/// Shows the portfolio agreement dialog. Returns true if the user accepted.
Future<bool> showPortfolioAgreementDialog(
  BuildContext context,
  String businessId,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PortfolioAgreementSheet(businessId: businessId),
  );
  return result ?? false;
}

class _PortfolioAgreementSheet extends StatefulWidget {
  final String businessId;
  const _PortfolioAgreementSheet({required this.businessId});

  @override
  State<_PortfolioAgreementSheet> createState() =>
      _PortfolioAgreementSheetState();
}

class _PortfolioAgreementSheetState extends State<_PortfolioAgreementSheet> {
  bool _accepted = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Acuerdo de Portafolio',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version $kPortfolioAgreementVersion',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),

            // Agreement text
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildSection(
                    null,
                    'Para publicar tu portafolio en BeautyCita, debes aceptar los '
                    'siguientes terminos. Lee cuidadosamente antes de continuar.',
                    colors,
                  ),
                  _buildSection(
                    '1. Uso de fotos',
                    'Al subir fotos a tu portafolio, confirmas que:\n\n'
                    '- Tienes el derecho de usar y publicar esas imagenes.\n'
                    '- Obtuviste el consentimiento de cualquier persona identificable '
                    'en las fotos (especialmente fotos del "antes").\n'
                    '- Las fotos representan trabajo real realizado por ti o tu equipo.\n\n'
                    'Conservas la propiedad de tus fotos. Nos otorgas una licencia '
                    'limitada, no exclusiva y revocable para mostrarlas en tu portafolio '
                    'publico y en la plataforma BeautyCita.',
                    colors,
                  ),
                  _buildSection(
                    '2. Estandares de contenido',
                    'Tu portafolio debe contener unicamente contenido profesional '
                    'relacionado con servicios de belleza. No esta permitido:\n\n'
                    '- Contenido sexualmente explicito o inapropiado\n'
                    '- Contenido discriminatorio u ofensivo\n'
                    '- Informacion falsa o enganosa\n'
                    '- Fotos manipuladas de forma enganosa (filtros profesionales '
                    'son aceptables, alteraciones que misrepresenten resultados no lo son)',
                    colors,
                  ),
                  _buildSection(
                    '3. Consentimiento de clientes',
                    'Eres el unico responsable de obtener el consentimiento verbal o '
                    'escrito de tus clientes antes de fotografiarlos. BeautyCita no '
                    'es responsable si publicas fotos sin autorizacion del cliente.\n\n'
                    'Recomendamos obtener consentimiento verbal antes de cada sesion '
                    'de fotos y documentarlo cuando sea posible.',
                    colors,
                  ),
                  _buildSection(
                    '4. Moderacion',
                    'BeautyCita se reserva el derecho de:\n\n'
                    '- Ocultar o eliminar contenido que viole estos estandares\n'
                    '- Desactivar temporalmente un portafolio si recibimos quejas '
                    'verificadas\n'
                    '- Solicitar evidencia de consentimiento del cliente si se disputa '
                    'el uso de una foto',
                    colors,
                  ),
                  _buildSection(
                    '5. Revocacion',
                    'Puedes desactivar tu portafolio publico en cualquier momento '
                    'desde la configuracion de tu negocio. Al desactivarlo, tu pagina '
                    'dejara de ser visible inmediatamente.\n\n'
                    'BeautyCita puede revocar el acceso al portafolio si detecta '
                    'violaciones repetidas a estos terminos.',
                    colors,
                  ),
                  _buildSection(
                    '6. Uso en feed de inspiracion',
                    'Las fotos publicadas en tu portafolio podran aparecer en el feed '
                    'global de inspiracion de BeautyCita, una galeria publica de '
                    'transformaciones de belleza. Esto aumenta la visibilidad de tu '
                    'trabajo. Si no deseas participar en el feed, puedes desactivar '
                    'esta opcion en el futuro cuando este disponible.',
                    colors,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Accept checkbox + button
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _accepted = !_accepted),
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _accepted,
                          onChanged: (v) =>
                              setState(() => _accepted = v ?? false),
                          activeColor: colors.primary,
                        ),
                        Expanded(
                          child: Text(
                            'He leido y acepto el Acuerdo de Portafolio',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _accepted && !_saving ? _onAccept : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Aceptar y publicar portafolio',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection(String? heading, String body, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null) ...[
            Text(
              heading,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            body,
            style: GoogleFonts.nunito(
              fontSize: 13,
              height: 1.6,
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAccept() async {
    setState(() => _saving = true);
    try {
      await PortfolioService.acceptAgreement(
        widget.businessId,
        kPortfolioAgreementType,
        kPortfolioAgreementVersion,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }
}
