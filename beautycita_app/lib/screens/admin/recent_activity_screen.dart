import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';

class RecentActivityScreen extends ConsumerWidget {
  const RecentActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(adminFullActivityProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          'Actividad Reciente',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF000000),
          ),
        ),
        iconTheme: IconThemeData(color: colors.primary),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminFullActivityProvider),
        child: activityAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Text(
                  'Sin actividad reciente',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return _ActivityTile(item: item);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Error: $e',
                style: GoogleFonts.nunito(color: colors.error)),
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['type'] as String;
    final colors = Theme.of(context).colorScheme;

    final IconData icon;
    final Color iconColor;
    switch (type) {
      case 'booking':
        icon = Icons.calendar_today;
        iconColor = Colors.orange;
        break;
      case 'dispute':
        icon = Icons.gavel;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.person_add;
        iconColor = colors.primary;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['description'] as String,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(item['created_at'] as String?),
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: colors.onSurface.withValues(alpha: 0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final detail = item['detail'] as String? ?? 'Sin detalles';
    final type = item['type'] as String;

    final String title;
    switch (type) {
      case 'booking':
        title = 'Detalle de Cita';
        break;
      case 'dispute':
        title = 'Detalle de Disputa';
        break;
      default:
        title = 'Detalle de Usuario';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeAgo(item['created_at'] as String?),
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            ...detail.split('\n').map((line) {
              final parts = line.split(':');
              if (parts.length >= 2) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${parts[0].trim()}:',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          parts.sublist(1).join(':').trim(),
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line, style: GoogleFonts.nunito(fontSize: 14)),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'ahora';
      if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'hace ${diff.inHours}h';
      if (diff.inDays < 30) return 'hace ${diff.inDays}d';
      return 'hace ${(diff.inDays / 30).floor()} meses';
    } catch (_) {
      return '';
    }
  }
}
