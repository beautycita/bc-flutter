import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import 'admin_shell_screen.dart';
import 'recent_activity_screen.dart';

/// Index mapping from stat tile to admin tab index.
/// Admin tabs order: Dashboard(0), Usuarios(1), Solicitudes(2), Citas(3),
///   Disputas(4), Salones(5), Analitica(6), Resenas(7)
const _tileTabMapping = <String, int>{
  'Usuarios': 1,
  'Estilistas': 5, // Salones tab
  'Citas Hoy': 3, // Citas tab
  'Ingresos Mes': 6, // Analitica tab
  'Solicitudes': 2,
  'Disputas': 4,
};

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashStatsProvider);
    final activityAsync = ref.watch(adminRecentActivityProvider);
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashStatsProvider);
        ref.invalidate(adminRecentActivityProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        children: [
          Text(
            'Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // Stats grid
          statsAsync.when(
            data: (stats) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppConstants.paddingSM,
              crossAxisSpacing: AppConstants.paddingSM,
              childAspectRatio: 1.6,
              children: [
                _StatCard(
                  icon: Icons.people,
                  label: 'Usuarios',
                  value: '${stats.totalUsers}',
                  color: colors.primary,
                  onTap: () => _goToTab(ref, 'Usuarios'),
                ),
                _StatCard(
                  icon: Icons.content_cut,
                  label: 'Estilistas',
                  value: '${stats.activeStylists}',
                  color: Colors.teal,
                  onTap: () => _goToTab(ref, 'Estilistas'),
                ),
                _StatCard(
                  icon: Icons.calendar_today,
                  label: 'Citas Hoy',
                  value: '${stats.bookingsToday}',
                  color: Colors.orange,
                  onTap: () => _goToTab(ref, 'Citas Hoy'),
                ),
                _StatCard(
                  icon: Icons.attach_money,
                  label: 'Ingresos Mes',
                  value: '\$${stats.revenueMonth.toStringAsFixed(0)}',
                  color: Colors.green,
                  onTap: () => _goToTab(ref, 'Ingresos Mes'),
                ),
                _StatCard(
                  icon: Icons.assignment,
                  label: 'Solicitudes',
                  value: '${stats.pendingApplications}',
                  color: Colors.deepPurple,
                  onTap: () => _goToTab(ref, 'Solicitudes'),
                ),
                _StatCard(
                  icon: Icons.gavel,
                  label: 'Disputas',
                  value: '${stats.openDisputes}',
                  color: Colors.red,
                  onTap: () => _goToTab(ref, 'Disputas'),
                ),
              ],
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppConstants.paddingXL),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: GoogleFonts.nunito(color: colors.error)),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // Recent activity header — tappable link
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RecentActivityScreen(),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Actividad Reciente',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.primary.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: colors.primary),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),

          activityAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingLG),
                    child: Center(
                      child: Text(
                        'Sin actividad reciente',
                        style: GoogleFonts.nunito(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                );
              }
              // Show only first 5 items
              final displayItems = items.take(5).toList();
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMD),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = displayItems[i];
                    final type = item['type'] as String;
                    final icon = type == 'booking'
                        ? Icons.calendar_today
                        : type == 'dispute'
                            ? Icons.gavel
                            : Icons.person_add;
                    return ListTile(
                      leading: Icon(icon,
                          color: colors.primary, size: 20),
                      title: Text(
                        item['description'] as String,
                        style: GoogleFonts.nunito(fontSize: 13),
                      ),
                      trailing: Text(
                        _timeAgo(item['created_at'] as String?),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color:
                              colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppConstants.paddingMD),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  void _goToTab(WidgetRef ref, String label) {
    final tabIndex = _tileTabMapping[label];
    if (tabIndex != null) {
      ref.read(adminTabProvider.notifier).state = tabIndex;
    }
  }

  static String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'ahora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 30) return '${diff.inDays}d';
      return '${(diff.inDays / 30).floor()}mo';
    } catch (_) {
      return '';
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(AppConstants.paddingSM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
