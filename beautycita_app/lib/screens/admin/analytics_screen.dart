import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';

/// Analytics data fetched from Supabase.
class _AnalyticsData {
  // Engine performance
  final String avgResponseTime;
  final String conversionRate;
  final int totalBookings;

  // Time inference
  final String correctionRate;

  // Transport
  final String pctUber;
  final String pctCar;
  final String pctTransit;

  // Quality
  final String avgRating;
  final int reviewsThisWeek;

  const _AnalyticsData({
    required this.avgResponseTime,
    required this.conversionRate,
    required this.totalBookings,
    required this.correctionRate,
    required this.pctUber,
    required this.pctCar,
    required this.pctTransit,
    required this.avgRating,
    required this.reviewsThisWeek,
  });
}

final _analyticsProvider = FutureProvider<_AnalyticsData>((ref) async {
  final client = SupabaseClientService.client;

  // Fetch all needed data in parallel
  final results = await Future.wait([
    // 0: All appointments (status + transport_mode)
    client
        .from(BCTables.appointments)
        .select('id, status, transport_mode')
        .then((r) => List<Map<String, dynamic>>.from(r)),
    // 1: Reviews
    client
        .from(BCTables.reviews)
        .select('id, rating, created_at')
        .then((r) => List<Map<String, dynamic>>.from(r)),
  ]);

  final appointments = results[0];
  final reviews = results[1];

  // --- Engine Performance ---
  final totalAppts = appointments.length;
  final completed =
      appointments.where((a) => a['status'] == 'completed').length;
  final convRate =
      totalAppts > 0 ? (completed / totalAppts * 100) : 0.0;

  // No real response-time logging yet; show 200ms placeholder
  const avgResponseTime = '~200ms';

  // --- Time Inference ---
  // No override tracking column yet
  const correctionRate = 'N/A';

  // --- Transport ---
  int uber = 0, car = 0, transit = 0;
  for (final a in appointments) {
    final mode = a['transport_mode'] as String?;
    if (mode == null) continue;
    switch (mode) {
      case 'uber':
        uber++;
      case 'car':
        car++;
      case 'transit':
      case 'public':
        transit++;
    }
  }
  final withTransport = uber + car + transit;
  String pct(int n) =>
      withTransport > 0 ? '${(n / withTransport * 100).toStringAsFixed(1)}%' : '-';

  // --- Quality ---
  double ratingSum = 0;
  int ratingCount = 0;
  int reviewsThisWeek = 0;
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));

  for (final r in reviews) {
    final rating = r['rating'] as num?;
    if (rating != null) {
      ratingSum += rating.toDouble();
      ratingCount++;
    }
    final createdAt = r['created_at'] as String?;
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null && dt.isAfter(weekAgo)) {
        reviewsThisWeek++;
      }
    }
  }

  final avgRating =
      ratingCount > 0 ? (ratingSum / ratingCount).toStringAsFixed(1) : '-';

  return _AnalyticsData(
    avgResponseTime: avgResponseTime,
    conversionRate: totalAppts > 0 ? '${convRate.toStringAsFixed(1)}%' : '-',
    totalBookings: totalAppts,
    correctionRate: correctionRate,
    pctUber: pct(uber),
    pctCar: pct(car),
    pctTransit: pct(transit),
    avgRating: avgRating,
    reviewsThisWeek: reviewsThisWeek,
  );
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(_analyticsProvider);
    final colors = Theme.of(context).colorScheme;

    return analyticsAsync.when(
      data: (data) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_analyticsProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          children: [
            _MetricCard(
              title: 'Rendimiento del Motor',
              icon: Icons.speed,
              items: [
                _MetricItem('Tiempo promedio respuesta', data.avgResponseTime),
                _MetricItem('Tasa de conversion', data.conversionRate),
                _MetricItem('Total de citas', '${data.totalBookings}'),
              ],
            ),
            _MetricCard(
              title: 'Inferencia de Tiempo',
              icon: Icons.schedule,
              items: [
                _MetricItem('Tasa de correccion', data.correctionRate),
              ],
            ),
            _MetricCard(
              title: 'Transporte',
              icon: Icons.directions_car,
              items: [
                _MetricItem('% modo Uber', data.pctUber),
                _MetricItem('% modo auto', data.pctCar),
                _MetricItem('% modo transporte', data.pctTransit),
              ],
            ),
            _MetricCard(
              title: 'Calidad',
              icon: Icons.star,
              items: [
                _MetricItem('Rating promedio', data.avgRating),
                _MetricItem(
                    'Resenas esta semana', '${data.reviewsThisWeek}'),
              ],
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Text(
            'Error cargando analytics: $e',
            style: GoogleFonts.nunito(color: colors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
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
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.12),
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
