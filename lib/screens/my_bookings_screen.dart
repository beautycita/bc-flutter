import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/providers/booking_provider.dart';
import 'package:go_router/go_router.dart';

/// Filter tabs for the user's bookings list.
enum _BookingTab { proximas, pasadas, canceladas }

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  _BookingTab _activeTab = _BookingTab.proximas;

  /// Return label text for each tab.
  String _tabLabel(_BookingTab tab) {
    switch (tab) {
      case _BookingTab.proximas:
        return 'Próximas';
      case _BookingTab.pasadas:
        return 'Pasadas';
      case _BookingTab.canceladas:
        return 'Canceladas';
    }
  }

  bool _isCancelled(String status) =>
      status == 'cancelled_customer' || status == 'cancelled_business';

  /// Filter bookings client-side based on the active tab.
  List<Booking> _filterBookings(List<Booking> bookings) {
    final now = DateTime.now();

    switch (_activeTab) {
      case _BookingTab.proximas:
        return bookings
            .where((b) =>
                !_isCancelled(b.status) &&
                b.scheduledAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      case _BookingTab.pasadas:
        return bookings
            .where((b) =>
                !_isCancelled(b.status) &&
                (b.scheduledAt.isBefore(now) || b.status == 'completed'))
            .toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      case _BookingTab.canceladas:
        return bookings
            .where((b) => _isCancelled(b.status))
            .toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    }
  }

  /// Format a DateTime in Spanish, e.g. "Lunes 3 de febrero, 14:00".
  String _formatDate(DateTime dt) {
    final formatter = DateFormat("EEEE d 'de' MMMM, HH:mm", 'es');
    final formatted = formatter.format(dt);
    // Capitalize the first letter (day name).
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// Color for a status chip.
  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber.shade700;
      case 'confirmed':
        return Colors.green.shade600;
      case 'completed':
        return Colors.blue.shade600;
      case 'cancelled_customer':
      case 'cancelled_business':
        return Colors.red.shade600;
      case 'no_show':
        return Colors.grey.shade600;
      default:
        return BeautyCitaTheme.textLight;
    }
  }

  /// Display label for a status.
  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmada';
      case 'completed':
        return 'Completada';
      case 'cancelled_customer':
        return 'Cancelada';
      case 'cancelled_business':
        return 'Cancelada por salon';
      case 'no_show':
        return 'No asistio';
      default:
        return status;
    }
  }

  /// Empty-state message per tab.
  String _emptyMessage() {
    switch (_activeTab) {
      case _BookingTab.proximas:
        return 'No tienes citas próximas';
      case _BookingTab.pasadas:
        return 'No tienes citas pasadas';
      case _BookingTab.canceladas:
        return 'No tienes citas canceladas';
    }
  }

  /// Show a confirmation dialog before cancelling.
  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Estás seguro de que deseas cancelar tu cita de ${booking.serviceName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(bookingRepositoryProvider);
        await repo.cancelBooking(booking.id);

        // Refresh data.
        ref.invalidate(userBookingsProvider);
        ref.invalidate(upcomingBookingsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(AppConstants.successBookingCancelled),
              backgroundColor: Colors.green.shade600,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cancelar: $e'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(userBookingsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Mis Citas'),
      ),
      body: Column(
        children: [
          // -- Filter Chips --
          _buildFilterChips(textTheme),

          // -- Booking List --
          Expanded(
            child: bookingsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingLG),
                  child: Text(
                    'Error al cargar citas: $err',
                    style: textTheme.bodyLarge?.copyWith(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (allBookings) {
                final filtered = _filterBookings(allBookings);

                if (filtered.isEmpty) {
                  return _buildEmptyState(textTheme);
                }

                return RefreshIndicator(
                  color: BeautyCitaTheme.primaryRose,
                  onRefresh: () async {
                    ref.invalidate(userBookingsProvider);
                    // Wait for the provider to reload.
                    await ref.read(userBookingsProvider.future);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.screenPaddingHorizontal,
                      vertical: BeautyCitaTheme.spaceMD,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: BeautyCitaTheme.spaceSM),
                    itemBuilder: (context, index) {
                      return _buildBookingCard(filtered[index], textTheme);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
        vertical: BeautyCitaTheme.spaceSM,
      ),
      child: Row(
        children: _BookingTab.values.map((tab) {
          final isSelected = tab == _activeTab;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BeautyCitaTheme.spaceXS,
              ),
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = tab),
                child: AnimatedContainer(
                  duration: AppConstants.shortAnimation,
                  height: AppConstants.minTouchHeight - 8,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? BeautyCitaTheme.primaryRose
                        : BeautyCitaTheme.surfaceCream,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: BeautyCitaTheme.primaryRose
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _tabLabel(tab),
                    style: textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : BeautyCitaTheme.textDark,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: AppConstants.iconSizeXXL,
              color: BeautyCitaTheme.textLight.withValues(alpha: 0.4),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceMD),
            Text(
              _emptyMessage(),
              style: textTheme.bodyLarge?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, TextTheme textTheme) {
    final canCancel =
        booking.status == 'pending' || booking.status == 'confirmed';

    return GestureDetector(
      onTap: () => context.push('/appointment/${booking.id}'),
      child: Container(
      decoration: BoxDecoration(
        color: BeautyCitaTheme.surfaceCream,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: BeautyCitaTheme.dividerLight,
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
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: provider name + status chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.providerName ?? 'Proveedor',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: BeautyCitaTheme.spaceSM),
                _buildStatusChip(booking.status, textTheme),
              ],
            ),

            const SizedBox(height: BeautyCitaTheme.spaceXS),

            // Service name
            Text(
              booking.serviceName,
              style: textTheme.bodyMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: BeautyCitaTheme.spaceSM),

            // Date formatted in Spanish
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: AppConstants.iconSizeSM,
                  color: BeautyCitaTheme.primaryRose,
                ),
                const SizedBox(width: BeautyCitaTheme.spaceXS),
                Expanded(
                  child: Text(
                    _formatDate(booking.scheduledAt),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Price if available
            if (booking.price != null) ...[
              const SizedBox(height: BeautyCitaTheme.spaceXS),
              Row(
                children: [
                  const Icon(
                    Icons.attach_money_rounded,
                    size: AppConstants.iconSizeSM,
                    color: BeautyCitaTheme.primaryRose,
                  ),
                  Text(
                    '\$${booking.price!.toStringAsFixed(0)} MXN',
                    style: textTheme.bodyMedium?.copyWith(
                      color: BeautyCitaTheme.primaryRose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            // Cancel button for pending / confirmed
            if (canCancel) ...[
              const SizedBox(height: BeautyCitaTheme.spaceSM),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancelBooking(booking),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: AppConstants.iconSizeSM,
                  ),
                  label: const Text('Cancelar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingSM,
                    ),
                    minimumSize: const Size(0, AppConstants.minTouchHeight - 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildStatusChip(String status, TextTheme textTheme) {
    final color = _statusColor(status);
    final label = _statusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM + 4,
        vertical: AppConstants.paddingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
