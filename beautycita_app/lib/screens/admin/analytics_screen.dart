import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';

/// Placeholder analytics dashboard — will be populated with real metrics
/// once sufficient booking data exists.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        _MetricCard(
          title: 'Rendimiento del Motor',
          icon: Icons.speed,
          items: const [
            _MetricItem('Tiempo promedio respuesta', '-'),
            _MetricItem('Tasa de conversión', '-'),
            _MetricItem('Expansiones de radio', '-'),
          ],
        ),
        _MetricCard(
          title: 'Inferencia de Tiempo',
          icon: Icons.schedule,
          items: const [
            _MetricItem('Tasa de corrección', '-'),
            _MetricItem('Regla más corregida', '-'),
            _MetricItem('Servicio más corregido', '-'),
          ],
        ),
        _MetricCard(
          title: 'Transporte',
          icon: Icons.directions_car,
          items: const [
            _MetricItem('% modo Uber', '-'),
            _MetricItem('% modo auto', '-'),
            _MetricItem('% modo transporte', '-'),
          ],
        ),
        _MetricCard(
          title: 'Calidad',
          icon: Icons.star,
          items: const [
            _MetricItem('Rating promedio', '-'),
            _MetricItem('Snippet coverage', '-'),
            _MetricItem('Reseñas esta semana', '-'),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_MetricItem> items;

  const _MetricCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMD),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        item.value,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  final String label;
  final String value;
  const _MetricItem(this.label, this.value);
}
