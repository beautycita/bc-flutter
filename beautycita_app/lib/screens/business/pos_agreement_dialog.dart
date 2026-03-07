import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';

/// Shows the POS seller agreement bottom sheet.
/// Returns true if the user accepted, false/null if dismissed.
Future<bool?> showPosAgreementDialog(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _PosAgreementSheet(),
  );
}

class _PosAgreementSheet extends StatefulWidget {
  const _PosAgreementSheet();

  @override
  State<_PosAgreementSheet> createState() => _PosAgreementSheetState();
}

class _PosAgreementSheetState extends State<_PosAgreementSheet> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.paddingMD),
              child: Container(
                width: AppConstants.bottomSheetDragHandleWidth,
                height: AppConstants.bottomSheetDragHandleHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(
                    AppConstants.bottomSheetDragHandleRadius,
                  ),
                ),
              ),
            ),

            // Title + version
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.paddingLG,
                AppConstants.paddingMD,
                AppConstants.paddingLG,
                AppConstants.paddingXS,
              ),
              child: Column(
                children: [
                  Text(
                    'Acuerdo de Vendedor',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXS),
                  Text(
                    'Version 1.0',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Scrollable legal text
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLG,
                  vertical: AppConstants.paddingMD,
                ),
                children: const [
                  _AgreementSection(
                    number: '1',
                    title: 'Responsabilidad de Envio',
                    body:
                        'El vendedor es responsable de enviar los productos dentro de 3 dias habiles despues de recibir el pedido. BeautyCita no se hace responsable por retrasos o problemas de envio.',
                  ),
                  _AgreementSection(
                    number: '2',
                    title: 'Calidad del Producto',
                    body:
                        'Los productos deben corresponder a la descripcion y fotos publicadas. Productos defectuosos o que no coincidan con la descripcion seran sujetos a reembolso.',
                  ),
                  _AgreementSection(
                    number: '3',
                    title: 'Reembolso Automatico',
                    body:
                        'Si un pedido no es marcado como enviado dentro de 14 dias, el pago sera reembolsado automaticamente al comprador.',
                  ),
                  _AgreementSection(
                    number: '4',
                    title: 'Comision',
                    body:
                        'BeautyCita retiene una comision del 10% sobre cada venta. Esta comision cubre el procesamiento de pagos, la plataforma, y soporte al cliente.',
                  ),
                  _AgreementSection(
                    number: '5',
                    title: 'Productos Prohibidos',
                    body:
                        'No se permite la venta de productos falsificados, caducados, regulados, o ilegales. La violacion de esta politica resultara en la suspension inmediata de la cuenta.',
                  ),
                  _AgreementSection(
                    number: '6',
                    title: 'Datos del Cliente',
                    body:
                        'La informacion de envio del comprador debe ser utilizada unicamente para cumplir con el pedido. Queda prohibido contactar a los compradores fuera de la plataforma.',
                  ),
                  _AgreementSection(
                    number: '7',
                    title: 'Disputas',
                    body:
                        'En caso de disputa entre vendedor y comprador, BeautyCita actuara como mediador. La decision de BeautyCita sera final.',
                  ),
                  _AgreementSection(
                    number: '8',
                    title: 'Modificaciones',
                    body:
                        'BeautyCita se reserva el derecho de modificar estos terminos. Se notificara a los vendedores de cualquier cambio significativo.',
                  ),
                  SizedBox(height: AppConstants.paddingSM),
                ],
              ),
            ),

            const Divider(height: 1),

            // Checkbox + accept button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.paddingMD,
                AppConstants.paddingMD,
                AppConstants.paddingMD,
                AppConstants.paddingLG,
              ),
              child: Column(
                children: [
                  // Checkbox row
                  InkWell(
                    onTap: () => setState(() => _accepted = !_accepted),
                    borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.paddingXS,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _accepted,
                            onChanged: (value) =>
                                setState(() => _accepted = value ?? false),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: AppConstants.paddingXS),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: AppConstants.paddingXS,
                              ),
                              child: Text(
                                'He leido y acepto los terminos del Acuerdo de Vendedor',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingMD),

                  // Accept button
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.minTouchHeight,
                    child: ElevatedButton(
                      onPressed: _accepted
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        disabledBackgroundColor:
                            colorScheme.primary.withOpacity(
                          AppConstants.opacityDisabled,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSM,
                          ),
                        ),
                      ),
                      child: Text(
                        'Aceptar y Continuar',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
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
}

class _AgreementSection extends StatelessWidget {
  const _AgreementSection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$number. ',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            body,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
