import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/breakpoints.dart';
import '../../config/router.dart';
import '../../providers/admin_engine_provider.dart';
import '../../widgets/kpi_card.dart';

/// Engine overview page — `/app/admin/engine`
///
/// Shows engine health KPIs and link cards to sub-pages:
/// - Profiles (per-service-type weights)
/// - Categories (service hierarchy)
/// - Time (time inference rules)
class EnginePage extends ConsumerWidget {
  const EnginePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(width);
        final isMobile = WebBreakpoints.isMobile(width);
        final horizontalPadding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(isMobile: isMobile),
              const SizedBox(height: 24),
              _HealthKpis(ref: ref, isDesktop: isDesktop, isMobile: isMobile),
              const SizedBox(height: 32),
              _SubPageLinks(isDesktop: isDesktop, isMobile: isMobile),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Motor de Curacion',
          style: (isMobile
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Rendimiento del motor y configuracion de perfiles, categorias y reglas de tiempo.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ── Health KPIs ────────────────────────────────────────────────────────────

class _HealthKpis extends StatelessWidget {
  const _HealthKpis({
    required this.ref,
    required this.isDesktop,
    required this.isMobile,
  });

  final WidgetRef ref;
  final bool isDesktop;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(engineHealthProvider);

    return healthAsync.when(
      loading: () => _loadingGrid(context),
      error: (_, __) => _loadingGrid(context),
      data: (health) {
        final cards = [
          KpiCard(
            icon: Icons.speed,
            label: 'Tiempo promedio de respuesta',
            value: '${health.avgResponseMs.toStringAsFixed(0)}ms',
            iconColor: const Color(0xFF2196F3),
          ),
          KpiCard(
            icon: Icons.cached,
            label: 'Cache hit rate',
            value: '${health.cacheHitRate.toStringAsFixed(1)}%',
            iconColor: const Color(0xFF4CAF50),
          ),
          KpiCard(
            icon: Icons.auto_awesome,
            label: 'Curaciones hoy',
            value: health.curationsToday.toString(),
            iconColor: const Color(0xFF9C27B0),
          ),
        ];

        if (isMobile) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                if (card != cards.last) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return GridView.count(
          crossAxisCount: isDesktop ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 2.0 : 1.6,
          children: cards,
        );
      },
    );
  }

  Widget _loadingGrid(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.0,
      children: List.generate(3, (_) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Sub-page link cards ────────────────────────────────────────────────────

class _SubPageLinks extends StatelessWidget {
  const _SubPageLinks({required this.isDesktop, required this.isMobile});
  final bool isDesktop;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final links = [
      _LinkData(
        title: 'Perfiles de servicio',
        subtitle: 'Pesos de calidad, distancia, precio y disponibilidad por tipo de servicio',
        icon: Icons.tune,
        color: const Color(0xFF2196F3),
        route: WebRoutes.adminEngineProfiles,
      ),
      _LinkData(
        title: 'Categorias',
        subtitle: 'Arbol de categorias, subcategorias y servicios del motor',
        icon: Icons.account_tree,
        color: const Color(0xFF4CAF50),
        route: WebRoutes.adminEngineCategories,
      ),
      _LinkData(
        title: 'Reglas de tiempo',
        subtitle: 'Ventanas de reserva por tipo de servicio y dia de la semana',
        icon: Icons.schedule,
        color: const Color(0xFFFF9800),
        route: WebRoutes.adminEngineTime,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configuracion',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (isMobile)
          Column(
            children: [
              for (final link in links) ...[
                _LinkCard(data: link),
                if (link != links.last) const SizedBox(height: 12),
              ],
            ],
          )
        else
          GridView.count(
            crossAxisCount: isDesktop ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 2.2 : 1.8,
            children: links.map((l) => _LinkCard(data: l)).toList(),
          ),
      ],
    );
  }
}

class _LinkData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const _LinkData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _LinkCard extends StatefulWidget {
  const _LinkCard({required this.data});
  final _LinkData data;

  @override
  State<_LinkCard> createState() => _LinkCardState();
}

class _LinkCardState extends State<_LinkCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(widget.data.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering
                  ? widget.data.color.withValues(alpha: 0.4)
                  : colors.outlineVariant,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: widget.data.color.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.data.icon,
                  size: 20,
                  color: widget.data.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.data.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.data.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: _hovering
                        ? widget.data.color
                        : colors.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
