import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launch(String uri) async {
    final url = Uri.parse(uri);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Contacto',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppConstants.paddingXXL),
        children: [
          // ── Hero Section ──────────────────────────────────────────────────
          _HeroSection(gradient: ext.primaryGradient),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Primary Contact Cards ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(label: 'CONTACTO DIRECTO', colorScheme: colorScheme),
                const SizedBox(height: AppConstants.paddingSM),
                _ContactCard(
                  icon: Icons.phone_rounded,
                  label: 'Teléfono',
                  value: '+52 (720) 677-7800',
                  onTap: () => _launch('tel:+527206777800'),
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: AppConstants.paddingSM),
                _ContactCard(
                  icon: Icons.email_rounded,
                  label: 'General',
                  value: 'hello@beautycita.com',
                  onTap: () => _launch('mailto:hello@beautycita.com'),
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: AppConstants.paddingSM),
                _ContactCard(
                  icon: Icons.support_agent_rounded,
                  label: 'Soporte',
                  value: 'soporte@beautycita.com',
                  onTap: () => _launch('mailto:soporte@beautycita.com'),
                  colorScheme: colorScheme,
                ),

                const SizedBox(height: AppConstants.paddingLG),

                // ── Department Emails ─────────────────────────────────────
                _SectionLabel(label: 'DEPARTAMENTOS', colorScheme: colorScheme),
                const SizedBox(height: AppConstants.paddingSM),
                _DepartmentTile(
                  email: 'legal@beautycita.com',
                  department: 'Departamento legal',
                  onTap: () => _launch('mailto:legal@beautycita.com'),
                  colorScheme: colorScheme,
                ),
                _DepartmentTile(
                  email: 'partnerships@beautycita.com',
                  department: 'Alianzas comerciales',
                  onTap: () => _launch('mailto:partnerships@beautycita.com'),
                  colorScheme: colorScheme,
                ),
                _DepartmentTile(
                  email: 'press@beautycita.com',
                  department: 'Prensa y medios',
                  onTap: () => _launch('mailto:press@beautycita.com'),
                  colorScheme: colorScheme,
                ),
                _DepartmentTile(
                  email: 'careers@beautycita.com',
                  department: 'Oportunidades de empleo',
                  onTap: () => _launch('mailto:careers@beautycita.com'),
                  colorScheme: colorScheme,
                ),

                const SizedBox(height: AppConstants.paddingLG),

                // ── Business Hours ────────────────────────────────────────
                _SectionLabel(label: 'HORARIO DE ATENCIÓN', colorScheme: colorScheme),
                const SizedBox(height: AppConstants.paddingSM),
                _InfoCard(
                  colorScheme: colorScheme,
                  child: Column(
                    children: [
                      _HoursRow(
                        day: 'Lunes a Viernes',
                        hours: '9:00 AM — 6:00 PM',
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      Divider(
                        height: AppConstants.paddingMD * 2,
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      _HoursRow(
                        day: 'Sábado y Domingo',
                        hours: '10:00 AM — 4:00 PM',
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppConstants.paddingLG),

                // ── Address ───────────────────────────────────────────────
                _SectionLabel(label: 'UBICACIÓN', colorScheme: colorScheme),
                const SizedBox(height: AppConstants.paddingSM),
                _InfoCard(
                  colorScheme: colorScheme,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: AppConstants.iconTouchTarget,
                        height: AppConstants.iconTouchTarget,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: colorScheme.primary,
                          size: AppConstants.iconSizeMD,
                        ),
                      ),
                      const SizedBox(width: AppConstants.paddingMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plaza Caracol local 27',
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Puerto Vallarta, Jalisco, México',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'C.P. 48330',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppConstants.paddingXL),

                // ── Footer ────────────────────────────────────────────────
                Center(
                  child: Text(
                    'BeautyCita S.A. de C.V.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final LinearGradient gradient;

  const _HeroSection({required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingLG,
        AppConstants.paddingXL,
        AppConstants.paddingLG,
        AppConstants.paddingXL,
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.contact_support_rounded,
              size: AppConstants.iconSizeXXL,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            'Estamos para ayudarte',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            'Nuestro equipo responde en horario de oficina',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const _SectionLabel({required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

// ── Contact Card ──────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _ContactCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: AppConstants.paddingMD,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AppConstants.iconTouchTarget,
                height: AppConstants.iconTouchTarget,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                ),
                child: Icon(
                  icon,
                  color: colorScheme.primary,
                  size: AppConstants.iconSizeMD,
                ),
              ),
              const SizedBox(width: AppConstants.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.35),
                size: AppConstants.iconSizeMD,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Department Tile ───────────────────────────────────────────────────────────

class _DepartmentTile extends StatelessWidget {
  final String email;
  final String department;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _DepartmentTile({
    required this.email,
    required this.department,
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
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.paddingSM + 2,
            horizontal: 4,
          ),
          child: Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                size: AppConstants.iconSizeSM,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppConstants.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info Card (generic container for hours / address) ─────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  final ColorScheme colorScheme;

  const _InfoCard({required this.child, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}

// ── Hours Row ─────────────────────────────────────────────────────────────────

class _HoursRow extends StatelessWidget {
  final String day;
  final String hours;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _HoursRow({
    required this.day,
    required this.hours,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppConstants.iconTouchTarget,
          height: AppConstants.iconTouchTarget,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          ),
          child: Icon(
            Icons.schedule_rounded,
            color: colorScheme.primary,
            size: AppConstants.iconSizeMD,
          ),
        ),
        const SizedBox(width: AppConstants.paddingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hours,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
