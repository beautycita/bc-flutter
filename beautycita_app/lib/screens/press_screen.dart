import 'package:flutter/material.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';

class PressScreen extends StatelessWidget {
  const PressScreen({super.key});

  Future<void> _launchEmail(String address) async {
    final uri = Uri(scheme: 'mailto', path: address);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accentColor = colorScheme.primary;
    final surfaceColor = isDark ? const Color(0xFF1E1E2A) : colorScheme.surface;
    final borderColor = ext.cardBorderColor;
    final subtleText = isDark ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.54) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Prensa y medios',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppConstants.paddingXXL),
        children: [
          // ── Hero / Gradient Header ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingXL,
              AppConstants.paddingLG,
              AppConstants.paddingXL,
            ),
            decoration: BoxDecoration(gradient: ext.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingSM,
                    vertical: AppConstants.paddingXS,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'SALA DE PRENSA',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Text(
                  'La historia de\nBeautyCita',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'Transformando la industria de la belleza en Mexico.',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Company Overview Card ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: _ElevatedCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acerca de BeautyCita',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  Text(
                    'BeautyCita es la plataforma lider en Mexico que conecta a clientes con los mejores profesionales de belleza. Fundada en 2023 en Puerto Vallarta, nacimos de la pasion por hacer accesible la belleza profesional para todos.',
                    style: GoogleFonts.nunito(
                      fontSize: 14.5,
                      height: 1.65,
                      color: isDark ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingLG),
                  // Stats row
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        _StatCell(
                          value: '2023',
                          label: 'Fundada',
                          accentColor: accentColor,
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: borderColor,
                        ),
                        _StatCell(
                          value: '50+',
                          label: 'Ciudades',
                          accentColor: accentColor,
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: borderColor,
                        ),
                        _StatCell(
                          value: '4.9',
                          label: 'Calificacion',
                          accentColor: accentColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Timeline Section ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nuestra historia',
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                _Timeline(
                  accentColor: accentColor,
                  subtleText: subtleText,
                  isDark: isDark,
                  entries: const [
                    _TimelineEntry(
                      period: '2023',
                      description:
                          'Fundacion en Puerto Vallarta. Visitas puerta a puerta a salones locales.',
                    ),
                    _TimelineEntry(
                      period: '2024 · Q1',
                      description:
                          'Lanzamiento del MVP. Primeros 50 profesionales verificados.',
                    ),
                    _TimelineEntry(
                      period: '2024 · Q3',
                      description:
                          'Expansion mas alla de Puerto Vallarta a nivel nacional.',
                    ),
                    _TimelineEntry(
                      period: '2025 · Q2',
                      description:
                          'Tema musical original y produccion de video/arte propia.',
                    ),
                    _TimelineEntry(
                      period: '2025 · Q4',
                      description:
                          'Acercandose a 10,000 reservas realizadas.',
                    ),
                    _TimelineEntry(
                      period: '2026 · Q1',
                      description:
                          'Constitucion como BeautyCita S.A. de C.V. Lanzamiento de marketplace y pagos en linea.',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Press Kit Card ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: _ElevatedCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSM),
                        ),
                        child: Icon(
                          Icons.folder_zip_outlined,
                          color: accentColor,
                          size: AppConstants.iconSizeMD,
                        ),
                      ),
                      const SizedBox(width: AppConstants.paddingMD),
                      Text(
                        'Kit de prensa',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  Text(
                    'Para logotipos, imagenes y materiales de marca, contacta a nuestro equipo de prensa.',
                    style: GoogleFonts.nunito(
                      fontSize: 14.5,
                      height: 1.6,
                      color: isDark ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  GestureDetector(
                    onTap: () => _launchEmail('press@beautycita.com'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingMD,
                        vertical: AppConstants.paddingSM + 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSM),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            size: 16,
                            color: accentColor,
                          ),
                          const SizedBox(width: AppConstants.paddingXS + 2),
                          Text(
                            'press@beautycita.com',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Contact Card ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: _ElevatedCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSM),
                        ),
                        child: Icon(
                          Icons.contact_mail_outlined,
                          color: accentColor,
                          size: AppConstants.iconSizeMD,
                        ),
                      ),
                      const SizedBox(width: AppConstants.paddingMD),
                      Text(
                        'Contacto de prensa',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.paddingMD),
                  _ContactRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'press@beautycita.com',
                    accentColor: accentColor,
                    onTap: () => _launchEmail('press@beautycita.com'),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: AppConstants.bcContactPhone,
                    accentColor: accentColor,
                    onTap: () => _launchPhone(AppConstants.bcContactPhone),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingXL),

          // ── Footer ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: Column(
              children: [
                Divider(color: borderColor, height: 1),
                const SizedBox(height: AppConstants.paddingMD),
                Text(
                  'BeautyCita S.A. de C.V.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: subtleText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Puerto Vallarta, Jalisco, Mexico',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: subtleText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingMD),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal Widgets ──────────────────────────────────────────────────────────

class _ElevatedCard extends StatelessWidget {
  final Widget child;
  final Color surfaceColor;
  final Color borderColor;

  const _ElevatedCard({
    required this.child,
    required this.surfaceColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;

  const _StatCell({
    required this.value,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSM,
          vertical: AppConstants.paddingXS,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.54)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
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
  final Color accentColor;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: AppConstants.paddingSM),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: accentColor,
              decoration: TextDecoration.underline,
              decorationColor: accentColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _TimelineEntry {
  final String period;
  final String description;

  const _TimelineEntry({required this.period, required this.description});
}

class _Timeline extends StatelessWidget {
  final Color accentColor;
  final Color subtleText;
  final bool isDark;
  final List<_TimelineEntry> entries;

  const _Timeline({
    required this.accentColor,
    required this.subtleText,
    required this.isDark,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final isLast = index == entries.length - 1;
        return _TimelineRow(
          entry: entry,
          isLast: isLast,
          accentColor: accentColor,
          subtleText: subtleText,
          isDark: isDark,
        );
      }),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEntry entry;
  final bool isLast;
  final Color accentColor;
  final Color subtleText;
  final bool isDark;

  const _TimelineRow({
    required this.entry,
    required this.isLast,
    required this.accentColor,
    required this.subtleText,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const double dotSize = 12.0;
    const double lineWidth = 2.0;
    const double gutterWidth = 36.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left gutter: line + dot
          SizedBox(
            width: gutterWidth,
            child: Column(
              children: [
                // Top half-line (hidden for first entry)
                Expanded(
                  child: Center(
                    child: Container(
                      width: lineWidth,
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                // Dot
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                // Bottom half-line (hidden for last entry)
                Expanded(
                  child: Center(
                    child: Container(
                      width: lineWidth,
                      color: isLast
                          ? Colors.transparent
                          : accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppConstants.paddingMD),

          // Right content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.paddingMD,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.period,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.description,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      height: 1.55,
                      color: isDark ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
