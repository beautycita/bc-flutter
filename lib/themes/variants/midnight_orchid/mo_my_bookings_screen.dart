import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../config/constants.dart';
import '../../../config/theme_extension.dart';
import '../../../models/booking.dart';
import '../../../providers/booking_provider.dart';
import 'mo_widgets.dart';

// ─── Filter tabs ────────────────────────────────────────────────────────────
enum _BookingTab { proximas, pasadas, canceladas }

/// Midnight Orchid variant of the My Bookings screen.
/// Rounded cards with orchid glow borders, Quicksand font, orchid gradient tab
/// indicator, soft purple status pills, MOOrchidGlow effects.
class MOMyBookingsScreen extends ConsumerStatefulWidget {
  const MOMyBookingsScreen({super.key});

  @override
  ConsumerState<MOMyBookingsScreen> createState() =>
      _MOMyBookingsScreenState();
}

class _MOMyBookingsScreenState extends ConsumerState<MOMyBookingsScreen> {
  _BookingTab _activeTab = _BookingTab.proximas;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _tabLabel(_BookingTab tab) {
    switch (tab) {
      case _BookingTab.proximas:
        return 'Proximas';
      case _BookingTab.pasadas:
        return 'Pasadas';
      case _BookingTab.canceladas:
        return 'Canceladas';
    }
  }

  bool _isCancelled(String status) =>
      status == 'cancelled_customer' || status == 'cancelled_business';

  List<Booking> _filterBookings(List<Booking> bookings) {
    final now = DateTime.now();
    switch (_activeTab) {
      case _BookingTab.proximas:
        return bookings
            .where((b) =>
                !_isCancelled(b.status) && b.scheduledAt.isAfter(now))
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
        return bookings.where((b) => _isCancelled(b.status)).toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    }
  }

  String _formatDate(DateTime dt) {
    final formatter = DateFormat("EEEE d 'de' MMMM, HH:mm", 'es');
    final formatted = formatter.format(dt);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  Color _statusColor(String status, BCThemeExtension ext) {
    switch (status) {
      case 'pending':
        return ext.statusPending;
      case 'confirmed':
        return ext.statusConfirmed;
      case 'completed':
        return ext.statusCompleted;
      case 'cancelled_customer':
      case 'cancelled_business':
        return ext.statusCancelled;
      case 'no_show':
        return Colors.grey.shade600;
      default:
        return Colors.grey;
    }
  }

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

  String _emptyMessage() {
    switch (_activeTab) {
      case _BookingTab.proximas:
        return 'No tienes citas proximas';
      case _BookingTab.pasadas:
        return 'No tienes citas pasadas';
      case _BookingTab.canceladas:
        return 'No tienes citas canceladas';
    }
  }

  // ── Cancel flow ───────────────────────────────────────────────────────────

  Future<void> _cancelBooking(Booking booking) async {
    final c = MOColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle — orchid gradient
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: c.orchidGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                MOOrchidGlow(
                  blurRadius: 30,
                  child: Icon(
                    Icons.cancel_outlined,
                    size: AppConstants.iconSizeXL,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'Cancelar esta cita?',
                  style: GoogleFonts.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Text(
                  'Se cancelara tu cita de ${booking.serviceName}.'
                  '${booking.transportMode == 'uber' ? ' Tambien se cancelaran tus viajes de Uber.' : ''}',
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    color: c.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingLG),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: AppConstants.minTouchHeight,
                          decoration: BoxDecoration(
                            color: c.orchidDeep.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLG),
                            border: Border.all(
                              color: c.orchidPurple.withValues(alpha: 0.3),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'No, mantener',
                            style: GoogleFonts.quicksand(
                              color: c.orchidPink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          height: AppConstants.minTouchHeight,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLG),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.red.shade700.withValues(alpha: 0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Si, cancelar',
                            style: GoogleFonts.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(bookingRepositoryProvider);
        await repo.cancelBooking(booking.id);
        ref.invalidate(userBookingsProvider);
        ref.invalidate(upcomingBookingsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppConstants.successBookingCancelled),
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: c.surface,
      body: Stack(
        children: [
          // Background particles
          const Positioned.fill(
            child: MOFloatingParticles(count: 12, seedOffset: 200),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── App bar ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.screenPaddingHorizontal,
                    vertical: AppConstants.paddingSM,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: c.orchidDeep,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_rounded,
                            color: c.orchidPink,
                            size: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      MOGradientText(
                        text: 'Mis Citas',
                        style: GoogleFonts.quicksand(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40), // Balance back button
                    ],
                  ),
                ),

                // ── Tab Bar ──────────────────────────────────────────────
                _buildTabBar(c),

                const MOOrchidDivider(),

                // ── List ─────────────────────────────────────────────────
                Expanded(
                  child: bookingsAsync.when(
                    loading: () =>
                        const Center(child: MOLoadingDots()),
                    error: (err, _) => Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppConstants.paddingLG),
                        child: Text(
                          'Error al cargar citas: $err',
                          style: GoogleFonts.quicksand(
                              color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    data: (allBookings) {
                      final filtered = _filterBookings(allBookings);
                      if (filtered.isEmpty) {
                        return _buildEmptyState(c);
                      }
                      return RefreshIndicator(
                        color: c.orchidPink,
                        backgroundColor: c.card,
                        onRefresh: () async {
                          ref.invalidate(userBookingsProvider);
                          await ref.read(userBookingsProvider.future);
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal:
                                AppConstants.screenPaddingHorizontal,
                            vertical: AppConstants.paddingMD,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(
                              height: AppConstants.paddingSM),
                          itemBuilder: (_, i) =>
                              _buildBookingCard(filtered[i], c, ext),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(MOColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
        vertical: AppConstants.paddingSM,
      ),
      child: Row(
        children: _BookingTab.values.map((tab) {
          final isSelected = tab == _activeTab;
          return Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppConstants.paddingXS),
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = tab),
                child: Container(
                  height: AppConstants.minTouchHeight - 8,
                  decoration: BoxDecoration(
                    gradient: isSelected ? c.orchidGradient : null,
                    color: isSelected ? null : c.card,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusLG),
                    border: isSelected
                        ? null
                        : Border.all(color: c.orchidDeep, width: 1),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  c.orchidPink.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _tabLabel(tab),
                    style: GoogleFonts.quicksand(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : c.textSecondary,
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

  // ── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(MOColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MOOrchidGlow(
              blurRadius: 40,
              child: Icon(
                Icons.calendar_today_rounded,
                size: AppConstants.iconSizeXXL,
                color: c.orchidPurple.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              _emptyMessage(),
              style: GoogleFonts.quicksand(
                fontSize: 16,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Booking Card ──────────────────────────────────────────────────────────

  Widget _buildBookingCard(Booking booking, MOColors c, BCThemeExtension ext) {
    final canCancel =
        booking.status == 'pending' || booking.status == 'confirmed';

    return GestureDetector(
      onTap: () => context.push('/appointment/${booking.id}'),
      child: MOGlowCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        glowIntensity: 0.10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider name + status pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.providerName ?? 'Proveedor',
                    style: GoogleFonts.quicksand(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                _buildStatusPill(booking.status, c, ext),
              ],
            ),

            const SizedBox(height: AppConstants.paddingXS),

            // Service name
            Text(
              booking.serviceName,
              style: GoogleFonts.quicksand(
                fontSize: 14,
                color: c.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: AppConstants.paddingSM),

            // Date
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: AppConstants.iconSizeSM,
                  color: c.orchidPink,
                ),
                const SizedBox(width: AppConstants.paddingXS),
                Expanded(
                  child: Text(
                    _formatDate(booking.scheduledAt),
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Price
            if (booking.price != null) ...[
              const SizedBox(height: AppConstants.paddingXS),
              Row(
                children: [
                  Icon(
                    Icons.attach_money_rounded,
                    size: AppConstants.iconSizeSM,
                    color: c.orchidPurple,
                  ),
                  Text(
                    '\$${booking.price!.toStringAsFixed(0)} MXN',
                    style: GoogleFonts.quicksand(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.orchidPurple,
                    ),
                  ),
                ],
              ),
            ],

            // Cancel button
            if (canCancel) ...[
              const SizedBox(height: AppConstants.paddingSM),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => _cancelBooking(booking),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingSM + 4,
                      vertical: AppConstants.paddingXS + 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusFull),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cancelar',
                          style: GoogleFonts.quicksand(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Status Pill ───────────────────────────────────────────────────────────

  Widget _buildStatusPill(String status, MOColors c, BCThemeExtension ext) {
    final color = _statusColor(status, ext);
    final label = _statusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM + 4,
        vertical: AppConstants.paddingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.quicksand(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
