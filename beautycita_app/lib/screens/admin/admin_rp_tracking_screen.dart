import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/constants.dart';
import '../../providers/admin_provider.dart';

/// Admin screen showing RP (Public Relations) performance metrics.
class AdminRpTrackingScreen extends ConsumerWidget {
  const AdminRpTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rpStatsAsync = ref.watch(rpTrackingProvider);

    return rpStatsAsync.when(
      data: (stats) {
        if (stats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline,
                    size: 48,
                    color: const Color(0xFF757575).withValues(alpha: 0.4)),
                const SizedBox(height: AppConstants.paddingMD),
                Text(
                  'No hay RPs registrados',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF757575),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(rpTrackingProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            itemCount: stats.length,
            itemBuilder: (context, index) => _RpCard(rp: stats[index]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Text(
            'Error cargando datos RP: $e',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: const Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _RpCard extends StatelessWidget {
  final Map<String, dynamic> rp;

  const _RpCard({required this.rp});

  @override
  Widget build(BuildContext context) {
    final name = (rp['full_name'] as String?) ??
        (rp['username'] as String?) ??
        'Sin nombre';
    final avatarUrl = rp['avatar_url'] as String?;
    final assignedCount = rp['assigned_count'] as int? ?? 0;
    final convertedCount = rp['converted_count'] as int? ?? 0;
    final positiveVisits = rp['positive_visits'] as int? ?? 0;
    final firstAssignment = rp['first_assignment'] as String?;

    int daysActive = 0;
    if (firstAssignment != null) {
      final firstDate = DateTime.tryParse(firstAssignment);
      if (firstDate != null) {
        daysActive = DateTime.now().difference(firstDate).inDays;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(
          color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  backgroundColor: const Color(0xFFEC4899).withValues(alpha: 0.15),
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEC4899),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMD),
            // 2x2 stat grid
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Asignados',
                    value: assignedCount.toString(),
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: _MetricTile(
                    label: 'Registrados',
                    value: convertedCount.toString(),
                    color: const Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Dias activo',
                    value: daysActive.toString(),
                    color: const Color(0xFF757575),
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: _MetricTile(
                    label: 'Feedback+',
                    value: positiveVisits.toString(),
                    color: const Color(0xFFF59E0B),
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

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.paddingSM,
        horizontal: AppConstants.paddingMD,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
