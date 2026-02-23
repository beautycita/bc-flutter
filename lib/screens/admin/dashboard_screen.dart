import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import 'admin_shell_screen.dart';

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

          // Recent activity header — tappable link opens popup
          GestureDetector(
            onTap: () => _showFullActivity(context, ref),
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
                Icon(Icons.open_in_new_rounded,
                    size: 14, color: colors.primary),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),

          activityAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                    border: Border.all(
                      color: colors.onSurface.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(AppConstants.paddingLG),
                  child: Center(
                    child: Text(
                      'Sin actividad reciente',
                      style: GoogleFonts.nunito(
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                );
              }
              // Show only first 5 items
              final displayItems = items.take(5).toList();
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  border: Border.all(
                    color: colors.onSurface.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
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

  void _showFullActivity(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F3FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar + header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Actividad Reciente',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Activity list
              Expanded(
                child: Consumer(
                  builder: (ctx, ref, _) {
                    final activityAsync = ref.watch(adminFullActivityProvider);
                    return activityAsync.when(
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
                          controller: scrollController,
                          padding: const EdgeInsets.all(AppConstants.paddingMD),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _FullActivityTile(item: items[i]),
                        );
                      },
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text('Error: $e',
                            style: GoogleFonts.nunito(color: colors.error)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 30) return '${diff.inDays}d';
      return '${(diff.inDays / 30).floor()}mo';
    } catch (_) {
      return '';
    }
  }
}

class _FullActivityTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _FullActivityTile({required this.item});

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
      case 'dispute':
        icon = Icons.gavel;
        iconColor = Colors.red;
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(
              color: colors.onSurface.withValues(alpha: 0.08),
            ),
          ),
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
      case 'dispute':
        title = 'Detalle de Disputa';
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
