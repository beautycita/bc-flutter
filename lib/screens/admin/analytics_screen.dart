import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

/// Placeholder analytics dashboard — will be populated with real metrics
/// once sufficient booking data exists.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
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
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      margin: const EdgeInsets.only(bottom: BeautyCitaTheme.spaceMD),
      child: Padding(
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: BeautyCitaTheme.primaryRose, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BeautyCitaTheme.spaceMD),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: BeautyCitaTheme.textLight,
                        ),
                      ),
                      Text(
                        item.value,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: BeautyCitaTheme.textDark,
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
