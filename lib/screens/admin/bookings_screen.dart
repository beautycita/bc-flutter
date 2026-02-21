import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(adminBookingsProvider);
    final colors = Theme.of(context).colorScheme;

    return bookingsAsync.when(
      data: (bookings) {
        int pending = 0,
            confirmed = 0,
            completed = 0,
            cancelled = 0,
            noShow = 0;
        for (final b in bookings) {
          final s = b['status'] as String? ?? 'pending';
          switch (s) {
            case 'pending':
              pending++;
            case 'confirmed':
              confirmed++;
            case 'completed':
              completed++;
            case 'cancelled_customer' || 'cancelled_business':
              cancelled++;
            case 'no_show':
              noShow++;
          }
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminBookingsProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppConstants.paddingSM,
                crossAxisSpacing: AppConstants.paddingSM,
                childAspectRatio: 1.8,
                children: [
                  _StatusChip(
                    label: 'Total',
                    count: bookings.length,
                    icon: Icons.calendar_month,
                    color: colors.primary,
                    onTap: () => _showBookings(
                        context, 'Todas las Citas', bookings),
                  ),
                  _StatusChip(
                    label: 'Pendiente',
                    count: pending,
                    icon: Icons.hourglass_empty,
                    color: Colors.orange,
                    onTap: () => _showBookings(context, 'Pendientes',
                        bookings.where((b) => b['status'] == 'pending').toList()),
                  ),
                  _StatusChip(
                    label: 'Confirmada',
                    count: confirmed,
                    icon: Icons.check_circle_outline,
                    color: Colors.blue,
                    onTap: () => _showBookings(context, 'Confirmadas',
                        bookings.where((b) => b['status'] == 'confirmed').toList()),
                  ),
                  _StatusChip(
                    label: 'Completada',
                    count: completed,
                    icon: Icons.done_all,
                    color: Colors.green,
                    onTap: () => _showBookings(context, 'Completadas',
                        bookings.where((b) => b['status'] == 'completed').toList()),
                  ),
                  _StatusChip(
                    label: 'Cancelada',
                    count: cancelled,
                    icon: Icons.cancel_outlined,
                    color: Colors.red,
                    onTap: () => _showBookings(
                        context,
                        'Canceladas',
                        bookings
                            .where((b) =>
                                b['status'] == 'cancelled_customer' ||
                                b['status'] == 'cancelled_business')
                            .toList()),
                  ),
                  _StatusChip(
                    label: 'No Show',
                    count: noShow,
                    icon: Icons.person_off_outlined,
                    color: Colors.deepOrange,
                    onTap: () => _showBookings(context, 'No Show',
                        bookings.where((b) => b['status'] == 'no_show').toList()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
      ),
    );
  }

  void _showBookings(BuildContext context, String title,
      List<Map<String, dynamic>> bookings) {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusMD)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          )),
                      const Spacer(),
                      Text('${bookings.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          )),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: bookings.isEmpty
                      ? Center(
                          child: Text('Sin citas',
                              style: GoogleFonts.nunito(
                                  color: colors.onSurface
                                      .withValues(alpha: 0.5))))
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: bookings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _BookingTile(booking: bookings[i]),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Status chip tile
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
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
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const Spacer(),
                  Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Booking tile inside the popup
// ---------------------------------------------------------------------------

class _BookingTile extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = booking['status'] as String? ?? 'pending';
    final serviceName = booking['service_name'] as String? ?? 'Servicio';
    final price = booking['price'] as num?;
    final startsAt = booking['starts_at'] as String?;
    final businessName =
        (booking['businesses'] as Map?)?['name'] as String? ?? '';

    String dateStr = '';
    if (startsAt != null) {
      final dt = DateTime.tryParse(startsAt);
      if (dt != null) {
        dateStr =
            '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        serviceName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(status),
                  ],
                ),
                if (businessName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    businessName,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    const Spacer(),
                    if (price != null)
                      Text(
                        '\$${price.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'pending' => Colors.orange,
      'confirmed' => Colors.blue,
      'completed' => Colors.green,
      'cancelled_customer' || 'cancelled_business' => Colors.red,
      'no_show' => Colors.deepOrange,
      _ => Colors.grey,
    };
    final label = switch (status) {
      'pending' => 'Pendiente',
      'confirmed' => 'Confirmada',
      'completed' => 'Completada',
      'cancelled_customer' => 'Cancelada',
      'cancelled_business' => 'Cancelada',
      'no_show' => 'No Show',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusXS),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
