import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
            'Tarjeta de credito/debito (via Stripe), Bitcoin (via BTCPay), y efectivo directamente en el salon.',
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
            'Una comision del 10% por cada reserva completada. Los profesionales conservan el 90%.',
      ),
    ],
  ),
];

// ── Screen ───────────────────────────────────────────────────────────────────

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Centro de Ayuda',
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

          // ── Quick Actions ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    label: 'Chat con Eros',
                    sublabel: 'Asistente con IA',
                    icon: Icons.smart_toy_outlined,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    ),
                    onTap: () async {
                      final thread =
                          await ref.read(erosThreadProvider.future);
                      if (thread != null && context.mounted) {
                        context.push('/chat/${thread.id}');
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppConstants.paddingMD),
                Expanded(
                  child: _QuickActionCard(
                    label: 'Soporte humano',
                    sublabel: 'Agente en vivo',
                    icon: Icons.headset_mic_outlined,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFAD1457), Color(0xFFEC407A)],
                    ),
                    onTap: () async {
                      final thread =
                          await ref.read(supportThreadProvider.future);
                      if (thread != null && context.mounted) {
                        context.push('/chat/${thread.id}');
                      }
                    },
                  ),
                ),
              ],
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

          // ── Contact Footer ────────────────────────────────────────────────
          _ContactFooter(ext: ext),
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
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_center_rounded,
              color: Colors.white,
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
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            'Encuentra respuestas rapidas o contactanos directamente.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Card ─────────────────────────────────────────────────────────

class _QuickActionCard extends StatefulWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
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
        height: AppConstants.largeTouchHeight * 1.4,
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          boxShadow: [
            BoxShadow(
              color: widget.gradient.colors.first.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(widget.icon, color: Colors.white, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                Text(
                  widget.sublabel,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
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
      // Remove the default dividers injected by ExpansionTile
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

// ── Contact Footer ────────────────────────────────────────────────────────────

class _ContactFooter extends StatelessWidget {
  final BCThemeExtension ext;

  const _ContactFooter({required this.ext});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(color: ext.cardBorderColor, width: 1),
        ),
        child: Column(
          children: [
            Icon(
              Icons.contact_support_outlined,
              size: 36,
              color: colorScheme.primary,
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              '¿No encontraste lo que buscabas?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'Estamos aqui para ayudarte.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            _ContactRow(
              icon: Icons.email_outlined,
              label: 'soporte@beautycita.com',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: AppConstants.paddingSM),
            _ContactRow(
              icon: Icons.phone_outlined,
              label: '+52 (720) 677-7800',
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: AppConstants.paddingXS),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
