import 'package:flutter/material.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';
import 'package:beautycita/widgets/gyro_reflection_hero.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<BCThemeExtension>()!;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Sobre Nosotros',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeroSection(gradient: ext.primaryGradient),
          const SizedBox(height: AppConstants.paddingXL),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OurStorySection(colorScheme: colorScheme),
                const SizedBox(height: AppConstants.paddingXL),
                _ValuesSection(
                  colorScheme: colorScheme,
                  gradient: ext.primaryGradient,
                ),
                const SizedBox(height: AppConstants.paddingXL),
                _CareersSection(colorScheme: colorScheme),
                const SizedBox(height: AppConstants.paddingXL),
                _FooterSection(colorScheme: colorScheme),
                const SizedBox(height: AppConstants.paddingXXL),
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
    final cs = Theme.of(context).colorScheme;
    return GyroReflectionHero(
      borderRadius: BorderRadius.zero,
      child: Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.fromLTRB(
        AppConstants.screenPaddingHorizontal,
        AppConstants.paddingXXL,
        AppConstants.screenPaddingHorizontal,
        AppConstants.paddingXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingXS,
            ),
            decoration: BoxDecoration(
              color: cs.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              border: Border.all(
                color: cs.onPrimary.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Text(
              'Hecho con amor en Mexico',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            'BeautyCita',
            style: GoogleFonts.poppins(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: cs.onPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Text(
            'Tu agente de belleza inteligente,\nconstruido desde Puerto Vallarta\npara todo Mexico.',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onPrimary.withValues(alpha: 0.88),
              height: 1.55,
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ── Our Story Section ─────────────────────────────────────────────────────────

class _OurStorySection extends StatelessWidget {
  final ColorScheme colorScheme;

  const _OurStorySection({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nuestra Historia',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.paddingMD),
        _StoryCard(
          colorScheme: colorScheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BeautyCita nacio en 2023 en Puerto Vallarta — no en Silicon Valley, '
                'no en un acelerador de startups. Comenzo con una laptop y visitas '
                'puerta a puerta hablando con duenos de salones.',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              Text(
                'Sin fondos de VC, sin influencers pagados. Solo una mision: '
                'conectar a las personas con los mejores profesionales de belleza '
                'cerca de ellos.',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.paddingMD),
        Row(
          children: [
            Expanded(
              child: _HighlightChip(
                icon: Icons.music_note_rounded,
                label: 'Cancion propia',
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: AppConstants.paddingSM),
            Expanded(
              child: _HighlightChip(
                icon: Icons.percent_rounded,
                label: 'Solo 3% comision',
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final Widget child;

  const _StoryCard({required this.colorScheme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _HighlightChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: AppConstants.paddingSM + 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppConstants.iconSizeSM,
            color: colorScheme.primary,
          ),
          const SizedBox(width: AppConstants.paddingXS + 2),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Values Section ────────────────────────────────────────────────────────────

class _ValuesSection extends StatelessWidget {
  final ColorScheme colorScheme;
  final LinearGradient gradient;

  const _ValuesSection({
    required this.colorScheme,
    required this.gradient,
  });

  static const _values = [
    (
      icon: Icons.eco_rounded,
      title: 'Crecimiento\nde Base',
      body: 'Crecemos barrio por barrio, salon por salon.',
    ),
    (
      icon: Icons.favorite_rounded,
      title: 'Autenticidad',
      body: 'Conexiones reales, resenas honestas.',
    ),
    (
      icon: Icons.people_rounded,
      title: 'Comunidad\nPrimero',
      body: 'Cada decision pone a la comunidad primero.',
    ),
    (
      icon: Icons.handshake_rounded,
      title: 'Ganar\nJuntos',
      body: 'Los profesionales conservan el 97% de cada reserva.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nuestros Valores',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.paddingMD),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppConstants.gridSpacing,
          mainAxisSpacing: AppConstants.gridSpacing,
          childAspectRatio: 1.0,
          children: _values
              .map(
                (v) => _ValueCard(
                  icon: v.icon,
                  title: v.title,
                  body: v.body,
                  colorScheme: colorScheme,
                  gradient: gradient,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ValueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final ColorScheme colorScheme;
  final LinearGradient gradient;

  const _ValueCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.colorScheme,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Icon(
              icon,
              size: AppConstants.iconSizeMD,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM + 2),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Expanded(
            child: Text(
              body,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Careers Section ───────────────────────────────────────────────────────────

class _CareersSection extends StatelessWidget {
  final ColorScheme colorScheme;

  const _CareersSection({required this.colorScheme});

  static const _positions = [
    (
      title: 'Marketer de Crecimiento (Regional)',
      type: 'Comision / Medio tiempo',
      typeColor: Color(0xFF7B61FF),
      description:
          'Impulsa el crecimiento local a traves de marketing en redes sociales y '
          'relaciones con la comunidad en tu ciudad.',
    ),
    (
      title: 'Lider de Exito del Cliente',
      type: 'Tiempo completo / Remoto',
      typeColor: Color(0xFF00A878),
      description:
          'Brinda atencion excepcional a clientes y profesionales de la industria de belleza. '
          'Experiencia en salones es un plus.',
    ),
    (
      title: 'Coordinador de Operaciones',
      type: 'Tiempo completo / Ciudad de Mexico',
      typeColor: Color(0xFFE8614D),
      description:
          'Gestiona logistica operacional, coordina equipos multidisciplinarios y '
          'mantiene procesos eficientes. Multitarea esencial.',
    ),
    (
      title: 'Especialista de Belleza (Asesor)',
      type: 'Medio tiempo / Contrato / Remoto',
      typeColor: Color(0xFFE5A000),
      description:
          'Comparte tu expertise del sector. Licencia de belleza requerida, '
          '5+ anos de experiencia en la industria.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unete al equipo',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXS),
        Text(
          'Construimos BeautyCita desde cero. Si compartes nuestra mision, '
          'hay un lugar para ti.',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
            height: 1.55,
          ),
        ),
        const SizedBox(height: AppConstants.paddingMD),
        ...(_positions.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.cardSpacing),
            child: _JobCard(
              title: p.title,
              type: p.type,
              typeColor: p.typeColor,
              description: p.description,
              colorScheme: colorScheme,
            ),
          ),
        )),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  final String title;
  final String type;
  final Color typeColor;
  final String description;
  final ColorScheme colorScheme;

  const _JobCard({
    required this.title,
    required this.type,
    required this.typeColor,
    required this.description,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Icon(
                Icons.open_in_new_rounded,
                size: AppConstants.iconSizeSM,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingXS + 2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingSM + 2,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: Text(
              type,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD - 2),
          Text(
            description,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          Row(
            children: [
              Icon(
                Icons.mail_outline_rounded,
                size: AppConstants.iconSizeSM,
                color: colorScheme.primary.withValues(alpha: 0.75),
              ),
              const SizedBox(width: AppConstants.paddingXS),
              Text(
                'careers@beautycita.com',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Footer Section ────────────────────────────────────────────────────────────

class _FooterSection extends StatelessWidget {
  final ColorScheme colorScheme;

  const _FooterSection({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'BeautyCita S.A. de C.V.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            'RFC: BEA260313MI8',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppConstants.paddingXS),
              Text(
                'Puerto Vallarta, Jalisco, Mexico',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
