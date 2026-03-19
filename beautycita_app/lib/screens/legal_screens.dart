import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Terminos y Politicas',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
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
            lastUpdated: '17 de marzo de 2026',
            sections: _termsSections,
          ),
          _LegalTab(
            icon: Icons.privacy_tip_outlined,
            subtitle: 'Aviso de Privacidad Integral (LFPDPPP)',
            lastUpdated: '17 de marzo de 2026',
            sections: _privacySections,
          ),
          _LegalTab(
            icon: Icons.storage_outlined,
            subtitle: 'Que guardamos en tu dispositivo',
            lastUpdated: '17 de marzo de 2026',
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

class _LegalTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Gradient sub-header ──
        Container(
          decoration: BoxDecoration(gradient: ext.primaryGradient),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Content ──
        Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Last updated badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Actualizado: $lastUpdated',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sections
              for (final section in sections) ...[
                if (section.heading != null) ...[
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: ext.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          section.heading!,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  section.body,
                  style: GoogleFonts.nunito(
                    fontSize: 13.5,
                    height: 1.65,
                    color: colors.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ── Divider ──
              const SizedBox(height: 12),
              Divider(color: colors.onSurface.withValues(alpha: 0.08)),
              const SizedBox(height: 24),

              // ── Contact section ──
              const _ContactSection(),

              const SizedBox(height: 32),

              // ── Footer ──
              Center(
                child: Column(
                  children: [
                    Text(
                      'BeautyCita',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Puerto Vallarta, Jalisco, Mexico',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contacto y soporte',
          style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Estamos para ayudarte. Elige como prefieras comunicarte.',
          style: GoogleFonts.nunito(
            fontSize: 13, color: colors.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 20),

        // ── Eros AI support card ──
        GestureDetector(
          onTap: () async {
            final thread = await ref.read(erosThreadProvider.future);
            if (thread != null && context.mounted) {
              context.push('/chat/${thread.id}');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🏹', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat con Eros',
                        style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                      ),
                      Text(
                        'Soporte inteligente — respuesta instantanea',
                        style: GoogleFonts.nunito(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'AI',
                    style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Human support card ──
        GestureDetector(
          onTap: () async {
            final thread = await ref.read(supportThreadProvider.future);
            if (thread != null && context.mounted) {
              context.push('/chat/${thread.id}');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1038), Color(0xFFC2185B)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC2185B).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soporte humano',
                        style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                      ),
                      Text(
                        'Habla con una persona de nuestro equipo',
                        style: GoogleFonts.nunito(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF90EE90),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: GoogleFonts.nunito(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: Text(
            'O escribe a ${AppConstants.supportEmail}',
            style: GoogleFonts.nunito(
              fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35),
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
    heading: '3. Reservas',
    body:
        'Al confirmar una reserva aceptas los terminos del salon, incluyendo '
        'politicas de cancelacion y depositos. BeautyCita no es responsable por '
        'la calidad o resultado de los servicios del salon.\n\n'
        'Cancelaciones gratuitas hasta 24 horas antes de la cita. '
        'Cancelaciones tardias pueden resultar en cargo del deposito.',
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
        'el monto neto despues de la comision de plataforma del 10% por cada '
        'reserva completada y las retenciones.\n\n'
        'BeautyCita entera las retenciones al SAT (Servicio de Administracion '
        'Tributaria) mediante declaraciones informativas mensuales y pone a '
        'disposicion de los proveedores un desglose de retenciones en su panel.',
  ),
  _Section(
    heading: '4b. Pagos en efectivo y obligaciones fiscales del proveedor',
    body:
        'Cuando el servicio se paga en efectivo directamente al proveedor '
        '(incluyendo pagos mediante OXXO o QR de walk-in), BeautyCita actua '
        'unicamente como intermediario de la reserva y no procesa el pago.\n\n'
        'En estos casos, BeautyCita NO tiene obligacion de retener ISR ni IVA '
        'sobre dichos montos. El proveedor de servicios es el unico responsable '
        'de declarar y enterar los impuestos correspondientes a los ingresos '
        'recibidos en efectivo o por medios directos, conforme a su regimen '
        'fiscal aplicable.\n\n'
        'Al registrarse como proveedor en la plataforma, el estilista o salon '
        'acepta esta responsabilidad fiscal sobre transacciones en efectivo.',
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
    heading: '8. Disputas',
    body:
        'En conflictos entre cliente y salon, BeautyCita puede mediar y emitir '
        'reembolsos parciales o totales cuando lo considere justo.',
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
        'Responsable: BeautyCita S.A. de C.V.\n'
        'Domicilio: Plaza Caracol local 27, Puerto Vallarta, Jalisco, '
        'C.P. 48330, Mexico.\n'
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
        'Fecha de ultima actualizacion: 17 de marzo de 2026.',
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
