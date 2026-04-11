import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../providers/chat_provider.dart';

// ---------------------------------------------------------------------------
// Combined Terms & Policy screen with tabs
// ---------------------------------------------------------------------------

class TermsAndPolicyScreen extends StatefulWidget {
  final int initialTab;
  const TermsAndPolicyScreen({super.key, this.initialTab = 0});

  @override
  State<TermsAndPolicyScreen> createState() => _TermsAndPolicyScreenState();
}

class _TermsAndPolicyScreenState extends State<TermsAndPolicyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Terminos y Politicas'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: colors.primary,
          indicatorWeight: 2.5,
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurface.withValues(alpha: 0.45),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Terminos'),
            Tab(text: 'Privacidad'),
            Tab(text: 'Datos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _LegalTab(
            icon: Icons.description_outlined,
            subtitle: 'Reglas de uso de la plataforma',
            lastUpdated: '19 de marzo de 2026',
            sections: _termsSections,
          ),
          _LegalTab(
            icon: Icons.privacy_tip_outlined,
            subtitle: 'Aviso de Privacidad Integral (LFPDPPP)',
            lastUpdated: '19 de marzo de 2026',
            sections: _privacySections,
          ),
          _LegalTab(
            icon: Icons.storage_outlined,
            subtitle: 'Que guardamos en tu dispositivo',
            lastUpdated: '19 de marzo de 2026',
            sections: _storageSections,
          ),
        ],
      ),
    );
  }
}

// Keep old class names as redirects for any lingering references
class TermsOfServiceScreen extends TermsAndPolicyScreen {
  const TermsOfServiceScreen({super.key}) : super(initialTab: 0);
}

class PrivacyPolicyScreen extends TermsAndPolicyScreen {
  const PrivacyPolicyScreen({super.key}) : super(initialTab: 1);
}

class CookiesPolicyScreen extends TermsAndPolicyScreen {
  const CookiesPolicyScreen({super.key}) : super(initialTab: 2);
}

// ---------------------------------------------------------------------------
// Single tab content — scrollable sections + contact footer
// ---------------------------------------------------------------------------

class _LegalTab extends StatefulWidget {
  final IconData icon;
  final String subtitle;
  final String lastUpdated;
  final List<_Section> sections;

  const _LegalTab({
    required this.icon,
    required this.subtitle,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  State<_LegalTab> createState() => _LegalTabState();
}

class _LegalTabState extends State<_LegalTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    const count = 4; // hero banner, sections card, contact section, footer
    _fadeAnims = List.generate(count, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });
    _slideAnims = List.generate(count, (i) {
      final start = i * 0.12;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnims[index],
      child: SlideTransition(
        position: _slideAnims[index],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
        vertical: AppConstants.paddingMD,
      ),
      children: [
        // ── Hero banner (rounded card inside page) ──
        _animated(0, Container(
          decoration: BoxDecoration(
            gradient: ext.primaryGradient,
            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Actualizado: ${widget.lastUpdated}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),

        const SizedBox(height: AppConstants.paddingLG),

        // ── Sections in approved card style ──
        _animated(1, Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(color: ext.cardBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < widget.sections.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(height: AppConstants.paddingSM),
                  Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
                  const SizedBox(height: AppConstants.paddingSM),
                ],
                if (widget.sections[i].heading != null) ...[
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.sections[i].heading!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  widget.sections[i].body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: colors.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ],
          ),
        )),

        const SizedBox(height: AppConstants.paddingLG),

        // ── Contact section ──
        _animated(2, const _ContactSection()),

        const SizedBox(height: AppConstants.paddingLG),

        // ── Footer ──
        _animated(3, Center(
          child: Column(
            children: [
              Text(
                'BeautyCita',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.primary.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Puerto Vallarta, Jalisco, Mexico',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: AppConstants.paddingXXL),
      ],
    );
  }
}

class _Section {
  final String? heading;
  final String body;
  const _Section({this.heading, required this.body});
}

// ---------------------------------------------------------------------------
// Contact section — Eros AI support + human escalation
// ---------------------------------------------------------------------------

class _ContactSection extends ConsumerWidget {
  const _ContactSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header style
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
          child: Text(
            'CONTACTO Y SOPORTE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),

        // ── Support cards in approved card container ──
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(color: ext.cardBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Eros AI support row ──
              InkWell(
                onTap: () async {
                  final thread = await ref.read(erosThreadProvider.future);
                  if (thread != null && context.mounted) {
                    context.push('/chat/${thread.id}');
                  }
                },
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusMD),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingMD),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.smart_toy_outlined, size: 20, color: colors.secondary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat con Eros',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface),
                            ),
                            Text(
                              'Soporte inteligente — respuesta instantanea',
                              style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                        ),
                        child: Text(
                          'AI',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),

              // ── Human support row ──
              InkWell(
                onTap: () async {
                  final thread = await ref.read(supportThreadProvider.future);
                  if (thread != null && context.mounted) {
                    context.push('/chat/${thread.id}');
                  }
                },
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppConstants.radiusMD),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingMD),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.support_agent_outlined, size: 20, color: colors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Soporte humano',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface),
                            ),
                            Text(
                              'Habla con una persona de nuestro equipo',
                              style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.paddingSM),

        Center(
          child: Text(
            'O escribe a ${AppConstants.supportEmail}',
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section content data
// ---------------------------------------------------------------------------

const _termsSections = [
  _Section(
    body:
        'Al usar BeautyCita aceptas estos terminos. Si no estas de acuerdo, '
        'no utilices la aplicacion.',
  ),
  _Section(
    heading: '1. Que es BeautyCita',
    body:
        'BeautyCita es un agente inteligente de reservas de belleza que conecta '
        'clientes con salones y profesionales. Actuamos como intermediario '
        'tecnologico — no prestamos servicios de belleza directamente.',
  ),
  _Section(
    heading: '2. Tu cuenta',
    body:
        'Te registras con autenticacion biometrica de tu dispositivo. Se te asigna '
        'un nombre de usuario automatico. Opcionalmente puedes vincular Google, '
        'correo o telefono.\n\n'
        'Eres responsable de la seguridad de tu dispositivo y la actividad en tu cuenta.',
  ),
  _Section(
    heading: '3. Reservas y derecho de desistimiento',
    body:
        'Al confirmar una reserva aceptas los terminos del salon, incluyendo '
        'politicas de cancelacion y depositos. BeautyCita no es responsable por '
        'la calidad o resultado de los servicios del salon.\n\n'
        'DERECHO DE DESISTIMIENTO (PROFECO): Conforme a la legislacion mexicana '
        'de proteccion al consumidor (LPCAC), tienes derecho a cancelar '
        'cualquier reserva de servicio o compra de producto realizada en linea '
        'dentro de los 5 (cinco) dias habiles posteriores al pago y obtener un '
        'reembolso completo a tu saldo en la plataforma, sin necesidad de '
        'justificacion. Para ejercer este derecho, contacta a '
        'legal@beautycita.com o usa la opcion de cancelacion en la app.\n\n'
        'Cancelaciones fuera del periodo de 5 dias: gratuitas hasta 24 horas '
        'antes de la cita. Cancelaciones tardias pueden resultar en cargo '
        'del deposito segun la politica del salon.\n\n'
        'Todos los reembolsos se acreditan a tu saldo en BeautyCita.',
  ),
  _Section(
    heading: '4. Pagos',
    body:
        'Procesamos pagos con tarjeta via Stripe (certificado PCI-DSS Nivel 1). '
        'No almacenamos numeros completos de tarjeta. '
        'Pagos en efectivo se coordinan directamente con el salon.',
  ),
  _Section(
    heading: '4a. Retenciones fiscales',
    body:
        'Como plataforma digital de intermediacion, BeautyCita esta obligada por '
        'ley mexicana (LISR Art. 113-A, LIVA Art. 18-J) a retener Impuesto '
        'Sobre la Renta (ISR) e Impuesto al Valor Agregado (IVA) de los pagos '
        'a proveedores de servicios.\n\n'
        'Tasas de retencion:\n'
        '- Con RFC registrado: ISR 2.5% + IVA 8% del monto bruto.\n'
        '- Sin RFC: ISR 20% + IVA 16% del monto bruto.\n\n'
        'Las retenciones se deducen automaticamente del pago al proveedor. '
        'El cliente paga el precio publicado sin cambio. El proveedor recibe '
        'el monto neto despues de la comision de plataforma (3% por servicios, '
        '10% por productos) y las retenciones fiscales.\n\n'
        'BeautyCita entera las retenciones al SAT (Servicio de Administracion '
        'Tributaria) mediante declaraciones informativas mensuales y pone a '
        'disposicion de los proveedores un desglose de retenciones en su panel.',
  ),
  _Section(
    heading: '4b. Pagos en efectivo registrados en la plataforma',
    body:
        'Toda transaccion registrada en BeautyCita — incluyendo pagos en '
        'efectivo, OXXO, y walk-ins registrados via Cita Express o '
        'calendario manual — esta sujeta a:\n\n'
        '- Comision BeautyCita del 3% sobre el monto del servicio.\n'
        '- Retencion de ISR (2.5%) e IVA (8%) conforme a LISR Art. 113-A '
        'y LIVA Art. 18-J.\n\n'
        'Cuando el pago es en efectivo, el salon cobra directamente al '
        'cliente. La comision del 3% y las retenciones fiscales se cargan '
        'a la cuenta del salon en BeautyCita y se deducen del proximo pago '
        'via Stripe o se acumulan como saldo pendiente.\n\n'
        'Las obligaciones fiscales se liquidan inmediatamente al registrar '
        'la transaccion. BeautyCita entera al SAT las retenciones '
        'correspondientes independientemente del metodo de pago.\n\n'
        'Transacciones en efectivo NO registradas en la plataforma son '
        'responsabilidad exclusiva del proveedor.',
  ),
  _Section(
    heading: '4c. Punto de Venta (POS)',
    body:
        'BeautyCita ofrece un sistema de Punto de Venta integrado que permite '
        'a los salones vender productos a traves de la plataforma.\n\n'
        'Categorias permitidas: Los productos ofrecidos deben pertenecer '
        'exclusivamente a las categorias de belleza y cuidado personal '
        '(cosmeticos, productos para cabello, cuidado de piel, accesorios '
        'de belleza y productos relacionados). Queda prohibida la venta de '
        'productos ajenos a estas categorias.\n\n'
        'Comision: BeautyCita cobra una comision del 10% sobre cada venta de '
        'producto completada a traves del POS, igual que la comision por '
        'servicios de reserva.\n\n'
        'Acuerdo de vendedor: Para activar el POS, el salon debe aceptar '
        'los terminos del acuerdo de vendedor, que incluyen las restricciones '
        'de categorias de producto, politicas de devolucion y obligaciones '
        'fiscales aplicables.\n\n'
        'Derecho de remocion: BeautyCita se reserva el derecho de remover '
        'cualquier producto que no cumpla con las categorias permitidas, '
        'que viole derechos de propiedad intelectual, o que sea considerado '
        'inapropiado. En caso de incumplimiento reiterado, BeautyCita podra '
        'revocar el acceso al sistema POS del salon.\n\n'
        'Desactivacion: El salon puede desactivar su POS en cualquier '
        'momento desde la configuracion de su negocio. Los pedidos '
        'pendientes seran completados antes de la desactivacion.',
  ),
  _Section(
    heading: '4d. Tarjetas de regalo',
    body:
        'BeautyCita permite a los salones crear y distribuir tarjetas de regalo '
        'digitales canjeables por servicios o productos.\n\n'
        'TERMINOS DE USO:\n'
        '- Vigencia: Las tarjetas de regalo tienen una vigencia maxima de 3 '
        '(tres) anos a partir de su fecha de emision, conforme a la '
        'legislacion mexicana. El salon puede establecer una vigencia menor.\n'
        '- Canje: El codigo de la tarjeta se canjea en la app y se acredita '
        'al saldo del usuario. El saldo puede usarse para reservar servicios '
        'o comprar productos.\n'
        '- Reembolso: El saldo no utilizado de una tarjeta de regalo puede ser '
        'reembolsado al comprador original previa solicitud a '
        'legal@beautycita.com.\n'
        '- No transferible: La tarjeta es personal del destinatario una vez '
        'canjeada.\n'
        '- Tarjetas perdidas: BeautyCita no es responsable por codigos '
        'perdidos o compartidos con terceros. El salon emisor puede verificar '
        'el estado del codigo.\n'
        '- Sin valor en efectivo: Las tarjetas no son convertibles a efectivo '
        'ni canjeables en establecimientos fisicos fuera de la plataforma.',
  ),
  _Section(
    heading: '4e. Programa de lealtad',
    body:
        'BeautyCita ofrece un programa de lealtad por salon que permite a los '
        'clientes acumular puntos con cada visita.\n\n'
        'TERMINOS:\n'
        '- Acumulacion: 1 punto por cada \$10 MXN gastados en servicios pagados '
        'a traves de la plataforma. Los puntos se otorgan automaticamente al '
        'completar la cita.\n'
        '- Canje: 100 puntos pueden canjearse por \$50 MXN de credito al saldo '
        'del usuario. El canje se realiza desde la ficha del cliente en la app.\n'
        '- Vigencia: Los puntos no tienen fecha de expiracion mientras la '
        'cuenta del usuario permanezca activa.\n'
        '- Cuenta inactiva: Si la cuenta se elimina, los puntos acumulados se '
        'pierden y no son reembolsables.\n'
        '- No transferible: Los puntos son personales y no pueden transferirse '
        'entre usuarios.\n'
        '- Modificacion: BeautyCita se reserva el derecho de modificar las '
        'tasas de acumulacion y canje con previo aviso de 30 dias.',
  ),
  _Section(
    heading: '4f. Acuerdo de vendedor (proveedores de servicios)',
    body:
        'Al registrarse como proveedor de servicios en BeautyCita, el salon '
        'o profesional acepta los siguientes terminos:\n\n'
        'COMISIONES:\n'
        '- Servicios: BeautyCita cobra una comision del 3% sobre cada reserva '
        'de servicio completada y pagada a traves de la plataforma.\n'
        '- Productos (POS): Comision del 10% sobre cada venta de producto.\n'
        '- La comision se deduce automaticamente del pago antes de la '
        'transferencia al proveedor.\n\n'
        'PAGOS:\n'
        '- Pagos por tarjeta/saldo: procesados por Stripe, transferidos al '
        'proveedor segun el calendario de Stripe Connect (tipicamente 2-7 '
        'dias habiles).\n'
        '- Pagos en efectivo: el proveedor cobra directamente al cliente.\n\n'
        'OBLIGACIONES FISCALES:\n'
        '- BeautyCita retiene ISR (2.5%) e IVA (8%) conforme a LISR Art. '
        '113-A y LIVA Art. 18-J.\n'
        '- El proveedor es responsable de pagar la otra mitad de sus '
        'obligaciones fiscales directamente al SAT.\n'
        '- El proveedor debe declarar ingresos en efectivo en su regimen '
        'fiscal correspondiente.\n\n'
        'DATOS DE CLIENTES:\n'
        '- El salon accede a nombre y telefono del cliente para coordinar la '
        'cita. Esta informacion es confidencial y no puede usarse para fines '
        'de marketing fuera de BeautyCita.\n\n'
        'TERMINACION:\n'
        '- El proveedor puede cerrar su cuenta en cualquier momento desde '
        'Configuracion.\n'
        '- BeautyCita puede suspender o cerrar la cuenta del proveedor por '
        'incumplimiento de estos terminos, con aviso previo de 15 dias '
        'habiles, excepto en casos de fraude o abuso.\n'
        '- Los pedidos y citas pendientes se completaran antes de la '
        'desactivacion.',
  ),
  _Section(
    heading: '5. Transporte',
    body:
        'La integracion con Uber es opcional. Al vincular tu cuenta, autorizas a '
        'BeautyCita a solicitar estimados y programar viajes en tu nombre. '
        'Uber cobra directamente segun sus propios terminos.',
  ),
  _Section(
    heading: '6. Estudio virtual',
    body:
        'Las herramientas de prueba virtual usan IA para transformaciones de '
        'imagen. Tus fotos se procesan a traves de servidores seguros y no se '
        'usan para entrenar modelos. Puedes eliminarlas cuando quieras.',
  ),
  _Section(
    heading: '7. Tu contenido',
    body:
        'Conservas la propiedad de fotos y resenas que subas. Nos otorgas licencia '
        'limitada para mostrarlas dentro de la plataforma. No esta permitido subir '
        'contenido ilegal u ofensivo.',
  ),
  _Section(
    heading: '8. Disputas y resolucion de conflictos',
    body:
        'En conflictos entre cliente y salon, BeautyCita media la resolucion:\n\n'
        '1. El cliente presenta la disputa desde la app o via legal@beautycita.com.\n'
        '2. BeautyCita notifica al salon y solicita su respuesta.\n'
        '3. Plazo de respuesta: BeautyCita respondera dentro de 10 (diez) dias '
        'habiles a partir de la recepcion de la disputa.\n'
        '4. Plazo de resolucion: La resolucion final se emitira dentro de 20 '
        '(veinte) dias habiles.\n'
        '5. Reembolsos: parciales o totales, acreditados al saldo del cliente.\n\n'
        'ESCALAMIENTO A PROFECO: Si no estas satisfecho con la resolucion de '
        'BeautyCita, puedes presentar una queja ante la Procuraduria Federal '
        'del Consumidor (PROFECO) en www.gob.mx/profeco o llamando al '
        'telefono del consumidor 55 5568 8722.',
  ),
  _Section(
    heading: '9. Propiedad intelectual',
    body:
        'La app, diseno, codigo y marcas son propiedad de BeautyCita. '
        'No esta permitido copiar o realizar ingenieria inversa.',
  ),
  _Section(
    heading: '10. Limitaciones',
    body:
        'BeautyCita se proporciona "tal como esta". No garantizamos disponibilidad '
        'continua. Nuestra responsabilidad maxima se limita al monto pagado en '
        'los ultimos 12 meses.',
  ),
  _Section(
    heading: '11. Cambios y terminacion',
    body:
        'Podemos actualizar estos terminos y te notificaremos de cambios '
        'significativos. Nos reservamos el derecho de suspender cuentas que '
        'violen estos terminos.',
  ),
  _Section(
    heading: '12. Jurisdiccion',
    body:
        'Estos terminos se rigen por las leyes de Mexico. Controversias se '
        'resuelven ante tribunales de Puerto Vallarta, Jalisco.',
  ),
];

const _privacySections = [
  // ── Intro ──
  _Section(
    body:
        'AVISO DE PRIVACIDAD INTEGRAL\n\n'
        'En cumplimiento de la Ley Federal de Proteccion de Datos Personales en '
        'Posesion de los Particulares (LFPDPPP), su Reglamento, y los '
        'Lineamientos del Aviso de Privacidad publicados en el Diario Oficial '
        'de la Federacion, ponemos a su disposicion el presente Aviso de '
        'Privacidad Integral.',
  ),

  // ── 1. Responsable ──
  _Section(
    heading: '1. Identidad y domicilio del responsable',
    body:
        'Responsable: BEAUTYCITA, Sociedad Anonima de Capital Variable\n'
        'RFC: BEA260313MI8\n'
        'Domicilio fiscal: Avenida Manuel Corona, Alazan 11A, '
        'C.P. 48290, Jalisco, Mexico.\n'
        'Correo del departamento de datos personales: legal@beautycita.com\n'
        'Telefono: +52 (720) 677-7800\n\n'
        'BeautyCita opera como plataforma digital de intermediacion de '
        'servicios de belleza conforme a los articulos 113-A LISR y 18-J LIVA.',
  ),

  // ── 2. Datos personales recabados ──
  _Section(
    heading: '2. Datos personales que recabamos',
    body:
        'A) Datos de identificacion: nombre de usuario (generado automaticamente), '
        'nombre y apellidos (opcional), correo electronico, numero telefonico, '
        'genero, fecha de nacimiento y direccion de domicilio.\n\n'
        'B) Datos de contacto: correo electronico, numero de telefono.\n\n'
        'B-1) Datos de lista de contactos: BeautyCita accede a los numeros de '
        'telefono de tu lista de contactos para identificar salones registrados. '
        'Solo se comparan numeros de telefono; no se almacenan ni transmiten '
        'nombres ni otros datos de contactos.\n\n'
        'C) Datos de ubicacion: coordenadas GPS (solo con su consentimiento '
        'explicito a traves del permiso de ubicacion de su dispositivo).\n\n'
        'D) Datos de transacciones: historial de reservas, preferencias de '
        'busqueda, resenas, montos pagados, metodo de pago utilizado, y '
        'ultimos 4 digitos de tarjeta bancaria (nunca el numero completo).\n\n'
        'E) Datos fiscales de proveedores de servicios: RFC (Registro Federal '
        'de Contribuyentes) y regimen fiscal, proporcionados voluntariamente '
        'para el calculo de retenciones de impuestos.\n\n'
        'F) Datos de imagen: fotografias que usted suba o genere mediante '
        'nuestras herramientas de inteligencia artificial (estudio virtual). '
        'Las fotografias de portafolio, incluyendo imagenes de antes y despues, '
        'pueden ser visibles publicamente en beautycita.com/p/salon-slug.\n\n'
        'G) Datos tecnicos: token de notificaciones push, identificador de '
        'dispositivo, sistema operativo y version de la aplicacion.\n\n'
        'H) Datos de navegacion y uso: pantallas visitadas, acciones realizadas '
        'dentro de la app, y registros de errores para mejora del servicio.',
  ),

  // ── 3. Datos sensibles ──
  _Section(
    heading: '3. Datos sensibles',
    body:
        'AUTENTICACION BIOMETRICA: La app utiliza la huella digital o '
        'reconocimiento facial de su dispositivo exclusivamente para '
        'autenticacion local. Estos datos biometricos son procesados '
        'unicamente por el hardware de su dispositivo (Secure Enclave / TEE). '
        'BeautyCita NUNCA recibe, transmite ni almacena datos biometricos '
        'en sus servidores. No se requiere consentimiento expreso adicional '
        'ya que el tratamiento es realizado integramente por su dispositivo.\n\n'
        'FOTOGRAFIAS FACIALES: Las fotos procesadas por el estudio virtual '
        'pueden contener rasgos fisicos. Estas imagenes se transmiten a '
        'servidores seguros de LightX (procesamiento de IA) exclusivamente '
        'para generar la transformacion solicitada y no se utilizan para '
        'entrenar modelos de inteligencia artificial. Usted puede eliminar '
        'estas imagenes en cualquier momento desde la app.',
  ),

  // ── 4. Finalidades primarias ──
  _Section(
    heading: '4. Finalidades del tratamiento',
    body:
        'FINALIDADES PRIMARIAS (necesarias para la relacion juridica):\n'
        '• Crear y gestionar su cuenta de usuario.\n'
        '• Buscar salones y profesionales de belleza cercanos a su ubicacion.\n'
        '• Procesar reservas de servicios de belleza.\n'
        '• Procesar pagos con tarjeta (via Stripe, certificado PCI-DSS Nivel 1).\n'
        '• Calcular y retener ISR e IVA conforme a los articulos 113-A LISR '
        'y 18-J LIVA (aplica a proveedores de servicios).\n'
        '• Enviar notificaciones de confirmacion, recordatorio y seguimiento '
        'de citas.\n'
        '• Coordinar transporte hacia el salon (integracion con Uber).\n'
        '• Procesar imagenes en el estudio virtual de prueba.\n'
        '• Mediar y resolver disputas entre clientes y salones.\n'
        '• Cumplir obligaciones legales y fiscales ante el SAT.\n\n'
        'FINALIDADES SECUNDARIAS (no necesarias pero beneficiosas):\n'
        '• Enviar recomendaciones personalizadas de salones y servicios.\n'
        '• Mostrar contenido relevante en el feed de inspiracion.\n'
        '• Realizar analisis estadisticos anonimos para mejorar el servicio.\n'
        '• Enviar comunicaciones promocionales sobre funciones nuevas.\n\n'
        'Si usted no desea que sus datos sean tratados para las finalidades '
        'secundarias, puede enviar su negativa a legal@beautycita.com con '
        'el asunto "Negativa finalidades secundarias". La negativa no '
        'afectara su uso de la plataforma.',
  ),

  // ── 5. Fundamento legal ──
  _Section(
    heading: '5. Base legal del tratamiento',
    body:
        'Tratamos sus datos con fundamento en:\n'
        '• Consentimiento (Art. 8 LFPDPPP): al registrarse y aceptar este aviso.\n'
        '• Relacion contractual (Art. 12 Reglamento): necesario para prestar '
        'el servicio de intermediacion de reservas.\n'
        '• Obligacion legal (Art. 10, fraccion IV LFPDPPP): retenciones '
        'fiscales al SAT, declaraciones informativas, y cumplimiento de '
        'requerimientos de autoridades competentes.\n'
        '• Interes legitimo (Art. 12 Reglamento): prevencion de fraude, '
        'seguridad de la plataforma, y mejora del servicio.',
  ),

  // ── 6. Transferencias ──
  _Section(
    heading: '6. Transferencias de datos personales',
    body:
        'Sus datos pueden ser transferidos a los siguientes terceros:\n\n'
        'A) PROVEEDORES DE SERVICIOS DE BELLEZA: nombre, telefono y '
        'detalles de la reserva, para que puedan atender su cita.\n\n'
        'B) STRIPE, INC. (EE.UU.): datos de pago para procesamiento de '
        'transacciones con tarjeta. Stripe es certificado PCI-DSS Nivel 1. '
        'Transferencia internacional amparada por clausulas contractuales '
        'que garantizan nivel adecuado de proteccion (Art. 36 LFPDPPP).\n\n'
        'C) GOOGLE LLC (EE.UU.): token de dispositivo para notificaciones '
        'push (Firebase Cloud Messaging), y datos de ubicacion para '
        'busqueda de direcciones (Google Places). Transferencia internacional '
        'con clausulas contractuales.\n\n'
        'D) OPENAI, INC. (EE.UU.): texto de conversaciones con nuestro '
        'asistente de IA (Eros) para generar respuestas de soporte. No se '
        'envian datos de pago ni datos fiscales. Transferencia internacional '
        'con clausulas contractuales.\n\n'
        'E) LIGHTX (INDIA): fotografias del estudio virtual para '
        'procesamiento de IA. No se envian datos de identificacion personal. '
        'Transferencia internacional con clausulas contractuales.\n\n'
        'F) UBER TECHNOLOGIES (EE.UU.): nombre y ubicacion cuando usted '
        'elige la opcion de transporte. Solo con su autorizacion explicita. '
        'Transferencia internacional con clausulas contractuales.\n\n'
        'G) SAT — SERVICIO DE ADMINISTRACION TRIBUTARIA (MEXICO): montos '
        'de transacciones, retenciones de ISR e IVA, y RFC de proveedores. '
        'Transferencia obligatoria por ley (Art. 37 LFPDPPP). El SAT tiene '
        'acceso a registros de transacciones conforme a la '
        'legislacion fiscal vigente.\n\n'
        'H) WHATSAPP BUSINESS API (META): envio de notificaciones, '
        'verificacion de telefono y comunicacion con salones via WhatsApp. '
        'Transferencia internacional con clausulas contractuales.\n\n'
        'I) SUPABASE (INFRAESTRUCTURA): base de datos, autenticacion y '
        'almacenamiento de archivos. Transferencia internacional con '
        'clausulas contractuales.\n\n'
        'J) GOOGLE CALENDAR: sincronizacion de citas con el calendario del '
        'usuario (solo si el usuario conecta su cuenta de Google). '
        'Transferencia internacional con clausulas contractuales.\n\n'
        'K) CLOUDFLARE R2: almacenamiento de archivos multimedia. '
        'Transferencia internacional con clausulas contractuales.\n\n'
        'L) SENTRY, INC. (EE.UU.): reportes de errores y estabilidad de la '
        'plataforma. Sentry no recibe informacion personal identificable — '
        'solo datos tecnicos anonimizados (tipo de error, version de app, '
        'modelo de dispositivo). Transferencia internacional con clausulas '
        'contractuales.\n\n'
        'BeautyCita NO vende, comercializa ni renta sus datos personales '
        'a terceros bajo ninguna circunstancia.',
  ),

  // ── 7. ARCO ──
  _Section(
    heading: '7. Derechos ARCO',
    body:
        'Conforme a los articulos 28 al 35 de la LFPDPPP, usted tiene '
        'derecho a:\n\n'
        'A) ACCESO: conocer que datos personales tenemos y como los tratamos.\n'
        'R) RECTIFICACION: corregir datos inexactos o incompletos.\n'
        'C) CANCELACION: solicitar la eliminacion de sus datos.\n'
        'O) OPOSICION: oponerse al tratamiento para finalidades especificas.\n\n'
        'PROCEDIMIENTO:\n'
        '1. Envie solicitud a legal@beautycita.com con asunto "Derechos ARCO".\n'
        '2. Incluya: nombre completo, nombre de usuario en BeautyCita, '
        'descripcion clara del derecho que desea ejercer, y correo '
        'electronico para notificaciones.\n'
        '3. Si solicita rectificacion, adjunte documentacion de soporte.\n'
        '4. Recibiremos su solicitud y responderemos sobre su procedencia '
        'en un plazo maximo de 20 dias habiles contados desde la recepcion.\n'
        '5. Si la solicitud es procedente, la haremos efectiva dentro de '
        'los 15 dias habiles siguientes a la respuesta.\n'
        '6. Los plazos pueden ampliarse una sola vez por un periodo igual, '
        'previa notificacion justificada.\n\n'
        'Alternativamente, puede ejercer su derecho de cancelacion '
        'directamente desde Ajustes > Eliminar cuenta dentro de la app.',
  ),

  // ── 8. Revocacion de consentimiento ──
  _Section(
    heading: '8. Revocacion del consentimiento',
    body:
        'Usted puede revocar su consentimiento para el tratamiento de sus '
        'datos en cualquier momento, sin efectos retroactivos, enviando '
        'solicitud a legal@beautycita.com con asunto "Revocacion de '
        'consentimiento".\n\n'
        'La revocacion del consentimiento para finalidades primarias '
        'implicara la imposibilidad de seguir prestando el servicio, por '
        'lo que su cuenta sera cancelada.\n\n'
        'La revocacion para finalidades secundarias no afecta su acceso '
        'al servicio.\n\n'
        'Responderemos en un plazo maximo de 20 dias habiles.',
  ),

  // ── 9. Limitacion de uso ──
  _Section(
    heading: '9. Opciones para limitar el uso o divulgacion',
    body:
        'Ademas de los derechos ARCO, usted puede:\n\n'
        '• Desactivar notificaciones push desde la configuracion de su '
        'dispositivo o desde Ajustes dentro de la app.\n'
        '• Revocar el permiso de ubicacion en cualquier momento desde la '
        'configuracion de su dispositivo.\n'
        '• Solicitar la exclusion de comunicaciones promocionales enviando '
        'correo a legal@beautycita.com con asunto "No promociones".\n'
        '• Eliminar fotografias del estudio virtual desde la seccion '
        'correspondiente dentro de la app.',
  ),

  // ── 10. Seguridad ──
  _Section(
    heading: '10. Medidas de seguridad',
    body:
        'Implementamos medidas de seguridad administrativas, tecnicas y '
        'fisicas para proteger sus datos:\n\n'
        '• Cifrado TLS/HTTPS en todas las comunicaciones.\n'
        '• Control de acceso por roles (Row Level Security) a nivel de '
        'base de datos.\n'
        '• Autenticacion JWT con tokens de sesion.\n'
        '• Cifrado TLS 1.2+ con conjuntos de cifrado modernos (ECDHE/AES-GCM/CHACHA20).\n'
        '• Pagos delegados a procesadores certificados PCI-DSS Nivel 1.\n'
        '• Respaldos diarios cifrados con almacenamiento redundante.\n'
        '• Firewall (UFW), Fail2ban, y monitoreo continuo del servidor.\n'
        '• Ofuscacion de codigo R8 en la aplicacion movil.\n'
        '• Datos biometricos procesados exclusivamente en hardware seguro '
        'del dispositivo (nunca transmitidos).\n\n'
        'En caso de vulneracion de seguridad que afecte significativamente '
        'sus derechos patrimoniales o morales, le notificaremos de forma '
        'inmediata por los medios disponibles (notificacion en la app y '
        'correo electronico) para que pueda tomar las medidas necesarias '
        'para la defensa de sus intereses, conforme al articulo 20 de la '
        'LFPDPPP.',
  ),

  // ── 11. Periodos de retencion ──
  _Section(
    heading: '11. Periodos de retencion',
    body:
        'Conservamos sus datos personales durante los siguientes periodos:\n\n'
        '• Datos de cuenta: mientras su cuenta este activa. Tras solicitar '
        'eliminacion, los datos se borran en un plazo de 30 dias.\n'
        '• Historial de reservas: 5 anos desde la ultima transaccion '
        '(obligacion fiscal, Art. 30 Codigo Fiscal de la Federacion).\n'
        '• Datos fiscales de proveedores: 5 anos (obligacion fiscal).\n'
        '• Registros de retenciones: 5 anos (obligacion fiscal).\n'
        '• Fotografias del estudio virtual: hasta que usted las elimine '
        'o cierre su cuenta.\n'
        '• Datos tecnicos y de uso: 12 meses para analisis y mejora, '
        'despues se anonimizan.\n'
        '• Registros de soporte (chats): 2 anos.\n\n'
        'Al cumplirse los periodos de retencion, los datos se eliminan '
        'de forma segura o se anonimizan irreversiblemente.',
  ),

  // ── 12. Decisiones automatizadas ──
  _Section(
    heading: '12. Decisiones automatizadas',
    body:
        'BeautyCita utiliza algoritmos de inteligencia artificial para:\n\n'
        '• Seleccionar y ordenar los tres mejores salones para su servicio '
        'solicitado (motor de recomendacion).\n'
        '• Inferir el horario preferido de su cita basandose en el dia, '
        'hora actual, tipo de servicio e historial.\n'
        '• Generar transformaciones de imagen en el estudio virtual.\n'
        '• Proveer soporte automatizado via el asistente Eros.\n\n'
        'Ninguna de estas decisiones produce efectos juridicos adversos '
        'ni le afecta significativamente. Usted siempre confirma '
        'manualmente la reserva antes de que se procese.\n\n'
        'Puede solicitar informacion sobre la logica de estas decisiones '
        'enviando correo a legal@beautycita.com.',
  ),

  // ── 13. Menores ──
  _Section(
    heading: '13. Menores de edad',
    body:
        'BeautyCita no esta dirigida a menores de 16 anos y no recopilamos '
        'intencionalmente datos de menores. Si detectamos que un menor de '
        '16 anos ha proporcionado datos personales, los eliminaremos de '
        'inmediato y cancelaremos la cuenta correspondiente.\n\n'
        'Los mayores de 16 y menores de 18 deben contar con el '
        'consentimiento de su padre, madre o tutor.',
  ),

  // ── 14. Quejas ante el INAI ──
  _Section(
    heading: '14. Derecho a presentar queja ante el INAI',
    body:
        'Si usted considera que su derecho a la proteccion de datos '
        'personales ha sido vulnerado, tiene derecho a acudir al '
        'Instituto Nacional de Transparencia, Acceso a la Informacion '
        'y Proteccion de Datos Personales (INAI) para hacer valer sus '
        'derechos.\n\n'
        'Sitio web: www.inai.org.mx\n'
        'Telefono ATENEA: 800-835-4324',
  ),

  // ── 15. Cambios al aviso ──
  _Section(
    heading: '15. Modificaciones al aviso de privacidad',
    body:
        'Nos reservamos el derecho de modificar este aviso de privacidad '
        'en cualquier momento. Cualquier cambio sustancial sera notificado '
        'mediante notificacion push dentro de la aplicacion y se publicara '
        'la version actualizada en esta seccion con la nueva fecha de '
        'actualizacion.\n\n'
        'El uso continuado de BeautyCita despues de la notificacion de '
        'cambios constituye aceptacion del aviso actualizado.',
  ),

  // ── 16. Consentimiento ──
  _Section(
    heading: '16. Consentimiento',
    body:
        'Al registrarse en BeautyCita y aceptar el presente Aviso de '
        'Privacidad, usted otorga su consentimiento para el tratamiento '
        'de sus datos personales conforme a los terminos aqui descritos.\n\n'
        'Para datos sensibles (fotografias con rasgos fisicos), su '
        'consentimiento expreso se obtiene al momento de utilizar la '
        'funcion de estudio virtual, mediante confirmacion explicita '
        'en pantalla antes del procesamiento.\n\n'
        'Fecha de ultima actualizacion: 30 de marzo de 2026.',
  ),
];

const _storageSections = [
  _Section(
    body:
        'BeautyCita no usa cookies HTTP. Usamos almacenamiento local del '
        'dispositivo para el funcionamiento de la app.',
  ),
  _Section(
    heading: '1. Datos de sesion',
    body:
        'Identificador de usuario, token de sesion y nombre de usuario. '
        'Necesarios para mantenerte autenticado.',
  ),
  _Section(
    heading: '2. Preferencias',
    body:
        'Modo de transporte, configuracion de notificaciones, radio de busqueda '
        'y estado del onboarding. Para personalizar tu experiencia.',
  ),
  _Section(
    heading: '3. Servicios integrados',
    body:
        'Firebase almacena un token para notificaciones push. '
        'Stripe y Google Sign-In usan sus propios tokens de sesion, '
        'regidos por sus respectivas politicas.',
  ),
  _Section(
    heading: '4. Como eliminar datos',
    body:
        'Cerrar sesion elimina datos de sesion. Desde ajustes de Android '
        'puedes borrar todos los datos de la app. Desinstalar elimina '
        'todo automaticamente.\n\n'
        'Para eliminar datos del servidor, solicita cancelacion de cuenta a '
        'soporte@beautycita.com.',
  ),
];
