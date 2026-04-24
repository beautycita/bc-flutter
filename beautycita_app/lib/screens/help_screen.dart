import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../providers/chat_provider.dart';

// ── Data model ──────────────────────────────────────────────────────────────

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}

class _FaqCategory {
  final String title;
  final IconData icon;
  final List<_FaqItem> items;

  const _FaqCategory({
    required this.title,
    required this.icon,
    required this.items,
  });
}

const _faqCategories = [
  _FaqCategory(
    title: 'Reservas',
    icon: Icons.calendar_month_outlined,
    items: [
      _FaqItem(
        question: '¿Como reservo una cita?',
        answer:
            'Selecciona el servicio que deseas, y BeautyCita te mostrara los 3 mejores salones cerca de ti con el mejor horario disponible. Solo confirma con un toque.',
      ),
      _FaqItem(
        question: '¿Puedo cancelar una cita?',
        answer:
            'Si, puedes cancelar hasta 24 horas antes sin cargo. Cancelaciones dentro de las 24 horas pueden generar un cargo por cancelacion.',
      ),
      _FaqItem(
        question: '¿Que pasa si no me presento?',
        answer:
            'El salon puede cobrar el monto completo del servicio por inasistencia.',
      ),
    ],
  ),
  _FaqCategory(
    title: 'Pagos',
    icon: Icons.credit_card_outlined,
    items: [
      _FaqItem(
        question: '¿Que metodos de pago aceptan?',
        answer:
            'Tarjeta de credito/debito (via Stripe, certificado PCI-DSS Nivel 1) y efectivo directamente en el salon.',
      ),
      _FaqItem(
        question: '¿Como funcionan los reembolsos?',
        answer:
            'Los reembolsos se procesan en 5-7 dias habiles al metodo de pago original.',
      ),
      _FaqItem(
        question: '¿Mis datos de pago estan seguros?',
        answer:
            'Si. Nunca almacenamos numeros de tarjeta. Los pagos los procesa Stripe, certificado PCI-DSS Nivel 1.',
      ),
    ],
  ),
  _FaqCategory(
    title: 'Cuenta',
    icon: Icons.person_outline,
    items: [
      _FaqItem(
        question: '¿Como funciona el registro?',
        answer:
            'Te registras con la autenticacion biometrica de tu dispositivo (huella o rostro). Se te asigna un nombre de usuario automatico. No necesitas contrasena.',
      ),
      _FaqItem(
        question: '¿Puedo vincular mi correo o telefono?',
        answer:
            'Si, desde Ajustes > Seguridad puedes vincular correo, telefono o Google.',
      ),
      _FaqItem(
        question: '¿Como elimino mi cuenta?',
        answer:
            'Desde Ajustes > Seguridad > Eliminar cuenta, o escribe a soporte@beautycita.com.',
      ),
    ],
  ),
  _FaqCategory(
    title: 'Para profesionales',
    icon: Icons.storefront_outlined,
    items: [
      _FaqItem(
        question: '¿Como registro mi salon?',
        answer:
            'Desde Ajustes > Registra tu salon. Necesitas verificar tu telefono y correo primero.',
      ),
      _FaqItem(
        question: '¿Cuanto cobra BeautyCita?',
        answer:
            'En reservas del marketplace: 3% de cargo por procesamiento de transacciones (no reembolsable). En ventas POS: 7% de comision (reembolsable en devoluciones) + 3% de procesamiento = 10% total. El 3% es el cargo universal de BeautyCita que cubre los costos operativos de cada transaccion.',
      ),
    ],
  ),
];

// ── Screen ───────────────────────────────────────────────────────────────────

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  Future<void> _launch(String uri) async {
    final url = Uri.parse(uri);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (kDebugMode) debugPrint('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Ayuda y Contacto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          bottom: AppConstants.paddingXXL,
        ),
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          _HeroSection(gradient: ext.primaryGradient),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Eros AI — Big prominent card ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: _ErosCard(
              onTap: () async {
                final thread =
                    await ref.read(erosThreadProvider.future);
                if (thread != null && context.mounted) {
                  context.push('/chat/${thread.id}');
                }
              },
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── FAQ Section header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: Text(
              'Preguntas frecuentes',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingSM),

          // ── FAQ Categories ────────────────────────────────────────────────
          ..._faqCategories.map(
            (category) => _FaqCategorySection(
              category: category,
              ext: ext,
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Human support card (smaller, secondary) ─────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: _HumanSupportCard(
              onTap: () async {
                final thread =
                    await ref.read(supportThreadProvider.future);
                if (thread != null && context.mounted) {
                  context.push('/chat/${thread.id}');
                }
              },
              colorScheme: colorScheme,
              ext: ext,
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── "Still need help?" expandable contact section ───────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: _ContactAccordion(
              ext: ext,
              colorScheme: colorScheme,
              onLaunch: _launch,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final LinearGradient gradient;

  const _HeroSection({required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingHorizontal,
        AppConstants.paddingXL,
        AppConstants.screenPaddingHorizontal,
        AppConstants.paddingXL,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.help_center_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 38,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            '¿Como podemos ayudarte?',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            'Respuestas rapidas, IA inteligente, o contacto directo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Eros AI Card — Big, prominent, first thing they see ──────────────────────

class _ErosCard extends StatefulWidget {
  final VoidCallback onTap;

  const _ErosCard({required this.onTap});

  @override
  State<_ErosCard> createState() => _ErosCardState();
}

class _ErosCardState extends State<_ErosCard> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await Future.microtask(widget.onTap);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.smart_toy_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 30,
                    ),
            ),
            const SizedBox(width: AppConstants.paddingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habla con Eros',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tu forma mas rapida de obtener ayuda. Disponible 24/7.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.paddingSM),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Human Support Card (smaller, secondary) ──────────────────────────────────

class _HumanSupportCard extends StatefulWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final BCThemeExtension ext;

  const _HumanSupportCard({
    required this.onTap,
    required this.colorScheme,
    required this.ext,
  });

  @override
  State<_HumanSupportCard> createState() => _HumanSupportCardState();
}

class _HumanSupportCardState extends State<_HumanSupportCard> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await Future.microtask(widget.onTap);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        decoration: BoxDecoration(
          color: widget.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: widget.ext.cardBorderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFAD1457), Color(0xFFEC407A)],
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.headset_mic_outlined,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    ),
            ),
            const SizedBox(width: AppConstants.paddingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Soporte humano',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Agente en vivo en horario de oficina',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: widget.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: widget.colorScheme.onSurface.withValues(alpha: 0.35),
              size: AppConstants.iconSizeMD,
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAQ Category Section ──────────────────────────────────────────────────────

class _FaqCategorySection extends StatelessWidget {
  final _FaqCategory category;
  final BCThemeExtension ext;

  const _FaqCategorySection({
    required this.category,
    required this.ext,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.screenPaddingHorizontal,
        right: AppConstants.screenPaddingHorizontal,
        top: AppConstants.paddingMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Row(
            children: [
              Icon(
                category.icon,
                size: AppConstants.iconSizeMD,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Text(
                category.title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingSM),

          // FAQ items
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(
                color: ext.cardBorderColor,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < category.items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppConstants.paddingMD,
                      endIndent: AppConstants.paddingMD,
                      color: ext.cardBorderColor,
                    ),
                  _FaqExpansionTile(item: category.items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── FAQ Expansion Tile ────────────────────────────────────────────────────────

class _FaqExpansionTile extends StatelessWidget {
  final _FaqItem item;

  const _FaqExpansionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMD,
          vertical: AppConstants.paddingXS,
        ),
        childrenPadding: const EdgeInsets.only(
          left: AppConstants.paddingMD,
          right: AppConstants.paddingMD,
          bottom: AppConstants.paddingMD,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        title: Text(
          item.question,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
            height: 1.35,
          ),
        ),
        children: [
          Text(
            item.answer,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact Accordion ("Still need help?") ───────────────────────────────────

class _ContactAccordion extends StatelessWidget {
  final BCThemeExtension ext;
  final ColorScheme colorScheme;
  final Future<void> Function(String uri) onLaunch;

  const _ContactAccordion({
    required this.ext,
    required this.colorScheme,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: ext.cardBorderColor, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: AppConstants.paddingSM,
          ),
          childrenPadding: const EdgeInsets.only(
            left: AppConstants.paddingMD,
            right: AppConstants.paddingMD,
            bottom: AppConstants.paddingLG,
          ),
          iconColor: colorScheme.primary,
          collapsedIconColor: colorScheme.onSurfaceVariant,
          leading: Icon(
            Icons.contact_support_outlined,
            size: 28,
            color: colorScheme.primary,
          ),
          title: Text(
            '¿Aun necesitas ayuda?',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            'Contacto directo con nuestro equipo',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            const SizedBox(height: AppConstants.paddingSM),

            // Phone
            _ContactTile(
              icon: Icons.phone_rounded,
              label: 'Telefono',
              value: '+52 (720) 677-7800',
              onTap: () => onLaunch('tel:+527206777800'),
              colorScheme: colorScheme,
            ),
            const SizedBox(height: AppConstants.paddingSM),

            // General email
            _ContactTile(
              icon: Icons.email_rounded,
              label: 'General',
              value: 'hello@beautycita.com',
              onTap: () => onLaunch('mailto:hello@beautycita.com'),
              colorScheme: colorScheme,
            ),
            const SizedBox(height: AppConstants.paddingSM),

            // Support email
            _ContactTile(
              icon: Icons.support_agent_rounded,
              label: 'Soporte',
              value: 'soporte@beautycita.com',
              onTap: () => onLaunch('mailto:soporte@beautycita.com'),
              colorScheme: colorScheme,
            ),

            const SizedBox(height: AppConstants.paddingLG),

            // Department emails
            Text(
              'DEPARTAMENTOS',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            _DeptRow(
              dept: 'Legal',
              email: 'legal@beautycita.com',
              onTap: () => onLaunch('mailto:legal@beautycita.com'),
              colorScheme: colorScheme,
            ),
            _DeptRow(
              dept: 'Alianzas',
              email: 'partnerships@beautycita.com',
              onTap: () => onLaunch('mailto:partnerships@beautycita.com'),
              colorScheme: colorScheme,
            ),
            _DeptRow(
              dept: 'Prensa',
              email: 'press@beautycita.com',
              onTap: () => onLaunch('mailto:press@beautycita.com'),
              colorScheme: colorScheme,
            ),
            _DeptRow(
              dept: 'Empleo',
              email: 'careers@beautycita.com',
              onTap: () => onLaunch('mailto:careers@beautycita.com'),
              colorScheme: colorScheme,
            ),

            const SizedBox(height: AppConstants.paddingLG),

            // Business hours
            Text(
              'HORARIO DE ATENCION',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: Text(
                    'L-V: 9:00 AM — 6:00 PM  |  S-D: 10:00 AM — 4:00 PM',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.paddingMD),

            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_rounded,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: Text(
                    'Plaza Caracol local 27, Puerto Vallarta, Jalisco, C.P. 48330',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 18),
              ),
              const SizedBox(width: AppConstants.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeptRow extends StatelessWidget {
  final String dept;
  final String email;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _DeptRow({
    required this.dept,
    required this.email,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                size: 16,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Text(
                dept,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                email,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
