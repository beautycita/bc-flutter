import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../widgets/bc_button.dart';
import '../services/toast_service.dart';

// ---------------------------------------------------------------------------
// WhatsApp support number (no phone display — chat only)
// ---------------------------------------------------------------------------
const _waNumber = '523221215551';
const _waSupportUrl = 'https://wa.me/$_waNumber?text=Hola%20BeautyCita%2C%20necesito%20ayuda%20con...';

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
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

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
            lastUpdated: '22 de febrero de 2026',
            sections: _termsSections,
          ),
          _LegalTab(
            icon: Icons.privacy_tip_outlined,
            subtitle: 'Como protegemos tus datos',
            lastUpdated: '22 de febrero de 2026',
            sections: _privacySections,
          ),
          _LegalTab(
            icon: Icons.storage_outlined,
            subtitle: 'Que guardamos en tu dispositivo',
            lastUpdated: '22 de febrero de 2026',
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
// Fancy contact section — form + WhatsApp live chat
// ---------------------------------------------------------------------------

class _ContactSection extends StatefulWidget {
  const _ContactSection();

  @override
  State<_ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends State<_ContactSection> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (message.isEmpty) {
      ToastService.showError('Escribe tu mensaje');
      return;
    }

    setState(() => _sending = true);

    final parts = <String>[];
    parts.add('Mensaje desde la app BeautyCita:');
    if (name.isNotEmpty) parts.add('Nombre: $name');
    if (email.isNotEmpty) parts.add('Contacto: $email');
    parts.add('');
    parts.add(message);

    final text = Uri.encodeComponent(parts.join('\n'));
    final url = Uri.parse('https://wa.me/$_waNumber?text=$text');

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) {
        setState(() {
          _sent = true;
          _sending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ToastService.showError('No se pudo abrir WhatsApp');
      }
    }
  }

  void _openLiveChat() {
    HapticFeedback.lightImpact();
    final url = Uri.parse(_waSupportUrl);
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  static InputDecoration _styledInput(
    String label,
    ColorScheme colors, {
    Widget? prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    final gray = colors.onSurface.withValues(alpha: 0.12);
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: gray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: gray.withValues(alpha: 0.06), width: 1),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_sent) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF25D366).withValues(alpha: 0.08),
              const Color(0xFF25D366).withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF25D366), size: 48),
            const SizedBox(height: 12),
            Text(
              'Mensaje enviado',
              style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Te responderemos por WhatsApp lo antes posible.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

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

        // ── WhatsApp live chat card ──
        GestureDetector(
          onTap: _openLiveChat,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF075E54), Color(0xFF25D366)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withValues(alpha: 0.3),
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
                  child: const Icon(Icons.chat_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat en vivo',
                        style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                      ),
                      Text(
                        'Respuesta inmediata por WhatsApp',
                        style: GoogleFonts.nunito(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        'En linea',
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

        const SizedBox(height: 20),

        // ── OR divider ──
        Row(
          children: [
            Expanded(child: Divider(color: colors.onSurface.withValues(alpha: 0.1))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'o envia un mensaje',
                style: GoogleFonts.nunito(
                  fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ),
            Expanded(child: Divider(color: colors.onSurface.withValues(alpha: 0.1))),
          ],
        ),

        const SizedBox(height: 20),

        // ── Contact form card ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(
              color: colors.onSurface.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: _styledInput(
                  'Nombre (opcional)',
                  colors,
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: _styledInput(
                  'Correo o telefono (opcional)',
                  colors,
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageCtrl,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: _styledInput(
                  'Tu mensaje...',
                  colors,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              BCButton(
                label: _sending ? 'Enviando...' : 'Enviar mensaje',
                icon: Icons.send_rounded,
                onPressed: _sending ? null : _sendMessage,
                loading: _sending,
                fullWidth: true,
              ),
            ],
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
        'la calidad o resultado de los servicios del salon.',
  ),
  _Section(
    heading: '4. Pagos',
    body:
        'Procesamos pagos con tarjeta via Stripe (certificado PCI-DSS) y Bitcoin '
        'via BTCPay Server. No almacenamos numeros completos de tarjeta. '
        'Pagos en efectivo se coordinan directamente con el salon.',
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
  _Section(
    body:
        'BeautyCita se compromete a proteger tu privacidad. Este aviso describe '
        'como recopilamos, usamos y protegemos tu informacion.',
  ),
  _Section(
    heading: '1. Responsable',
    body:
        'BeautyCita, con domicilio en Puerto Vallarta, Jalisco, Mexico, es responsable '
        'del tratamiento de tus datos personales.',
  ),
  _Section(
    heading: '2. Datos que recopilamos',
    body:
        'Cuenta: nombre de usuario (auto-generado), nombre, correo, telefono, genero '
        'y fecha de nacimiento — todos opcionales.\n\n'
        'Ubicacion: GPS (con tu permiso) para buscar salones cercanos.\n\n'
        'Reservas: historial, preferencias de busqueda y resenas.\n\n'
        'Pagos: ultimos 4 digitos de tarjeta (via Stripe), direcciones Bitcoin '
        '(via BTCPay). Nunca almacenamos numeros completos.\n\n'
        'Medios: fotos que subas o generes con herramientas de IA.\n\n'
        'Tecnicos: token de notificaciones push y plataforma de registro.',
  ),
  _Section(
    heading: '3. Autenticacion biometrica',
    body:
        'Tu huella o rostro se procesan exclusivamente en tu dispositivo. '
        'BeautyCita nunca recibe ni almacena datos biometricos.',
  ),
  _Section(
    heading: '4. Uso de tus datos',
    body:
        'Usamos tu informacion para gestionar tu cuenta, buscar salones, '
        'procesar reservas y pagos, enviar notificaciones de citas, '
        'coordinar transporte, procesar imagenes del estudio virtual '
        'y cumplir obligaciones legales.',
  ),
  _Section(
    heading: '5. Terceros',
    body:
        'Compartimos datos solo con: Stripe (pagos), BTCPay (Bitcoin, auto-hospedado), '
        'Firebase (notificaciones), Google Places (direcciones), Uber (transporte) '
        'y LightX (procesamiento de imagenes).\n\n'
        'No vendemos ni comercializamos tus datos.',
  ),
  _Section(
    heading: '6. Seguridad',
    body:
        'Encriptacion HTTPS/TLS, control de acceso por roles (RLS), autenticacion '
        'JWT, pagos delegados a servicios certificados PCI-DSS. Conservamos datos '
        'mientras tu cuenta este activa; al solicitar eliminacion, los borramos '
        'en 30 dias.',
  ),
  _Section(
    heading: '7. Tus derechos (ARCO)',
    body:
        'Conforme a la LFPDPPP tienes derecho a acceder, rectificar, cancelar u '
        'oponerte al tratamiento de tus datos. Envia solicitud a '
        'soporte@beautycita.com con asunto "Derechos ARCO". '
        'Respondemos en maximo 20 dias habiles.',
  ),
  _Section(
    heading: '8. Menores',
    body:
        'La app no esta dirigida a menores de 16 anos. Si descubrimos datos '
        'de un menor, los eliminaremos de inmediato.',
  ),
  _Section(
    heading: '9. Cambios',
    body:
        'Podemos actualizar este aviso. Te notificaremos de cambios significativos '
        'dentro de la app.',
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
