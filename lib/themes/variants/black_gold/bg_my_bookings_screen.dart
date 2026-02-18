import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../config/constants.dart';
import '../../../config/theme_extension.dart';
import '../../../models/booking.dart';
import '../../../providers/booking_provider.dart';
import 'bg_widgets.dart';

// ─── Filter tabs ────────────────────────────────────────────────────────────
enum _BookingTab { proximas, pasadas, canceladas }

/// Black Gold variant of the My Bookings screen.
/// Dark surfaces, gold gradient tab bar and dividers, Playfair Display / Lato
/// fonts, BGGoldShimmer on active tab, gold-bordered booking cards.
class BGMyBookingsScreen extends ConsumerStatefulWidget {
  const BGMyBookingsScreen({super.key});

  @override
  ConsumerState<BGMyBookingsScreen> createState() =>
      _BGMyBookingsScreenState();
}

class _BGMyBookingsScreenState extends ConsumerState<BGMyBookingsScreen> {
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
    final c = BGColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface1,
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
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: c.goldGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Icon(
                  Icons.cancel_outlined,
                  size: AppConstants.iconSizeXL,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'Cancelar esta cita?',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Text(
                  'Se cancelara tu cita de ${booking.serviceName}.'
                  '${booking.transportMode == 'uber' ? ' Tambien se cancelaran tus viajes de Uber.' : ''}',
                  style: GoogleFonts.lato(
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
                            color: c.surface2,
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusLG),
                            border: Border.all(
                              color: c.goldMid.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'No, mantener',
                            style: GoogleFonts.lato(
                              color: c.goldMid,
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
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Si, cancelar',
                            style: GoogleFonts.lato(
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
              content: Text(
                AppConstants.successBookingCancelled,
                style: GoogleFonts.lato(color: Colors.white),
              ),
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
    final c = BGColors.of(context);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: c.surface0,
      appBar: AppBar(
        backgroundColor: c.surface0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: BGGoldShimmer(
          child: Text(
            'MIS CITAS',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: Colors.white,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: c.goldMid, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  c.goldMid.withValues(alpha: 0.0),
                  c.goldMid.withValues(alpha: 0.4),
                  c.goldMid.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Filter Tab Bar ──────────────────────────────────────────────
          _buildTabBar(c, ext),

          const BGGoldDivider(),

          // ── Booking list ────────────────────────────────────────────────
          Expanded(
            child: bookingsAsync.when(
              loading: () => const Center(child: BGGoldDots()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingLG),
                  child: Text(
                    'Error al cargar citas: $err',
                    style: GoogleFonts.lato(color: Colors.red),
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
                  color: c.goldMid,
                  backgroundColor: c.surface1,
                  onRefresh: () async {
                    ref.invalidate(userBookingsProvider);
                    await ref.read(userBookingsProvider.future);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.screenPaddingHorizontal,
                      vertical: AppConstants.paddingMD,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppConstants.paddingSM),
                    itemBuilder: (_, i) =>
                        _buildBookingCard(filtered[i], c, ext),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(BGColors c, BCThemeExtension ext) {
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
                    gradient: isSelected ? c.goldGradient : null,
                    color: isSelected ? null : c.surface2,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: c.goldMid.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: c.goldMid.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? BGGoldShimmer(
                          child: Text(
                            _tabLabel(tab),
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        )
                      : Text(
                          _tabLabel(tab),
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.textMuted,
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

  Widget _buildEmptyState(BGColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: AppConstants.iconSizeXXL,
              color: c.goldMid.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              _emptyMessage(),
              style: GoogleFonts.lato(
                fontSize: 16,
                color: c.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Booking Card ──────────────────────────────────────────────────────────

  Widget _buildBookingCard(Booking booking, BGColors c, BCThemeExtension ext) {
    final canCancel =
        booking.status == 'pending' || booking.status == 'confirmed';

    return GestureDetector(
      onTap: () => context.push('/appointment/${booking.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          gradient: c.goldGradient,
        ),
        // Gold gradient border effect — outer container is the border
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMD - 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Provider name + status chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.providerName ?? 'Proveedor',
                        style: GoogleFonts.playfairDisplay(
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
                  style: GoogleFonts.lato(
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
                      color: c.goldMid,
                    ),
                    const SizedBox(width: AppConstants.paddingXS),
                    Expanded(
                      child: Text(
                        _formatDate(booking.scheduledAt),
                        style: GoogleFonts.lato(
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
                        color: c.goldMid,
                      ),
                      Text(
                        '\$${booking.price!.toStringAsFixed(0)} MXN',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.goldMid,
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
                          color: Colors.red.shade900.withValues(alpha: 0.3),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSM),
                          border: Border.all(
                            color: Colors.red.shade600.withValues(alpha: 0.4),
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
                              style: GoogleFonts.lato(
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
        ),
      ),
    );
  }

  // ── Status Pill ───────────────────────────────────────────────────────────

  Widget _buildStatusPill(String status, BGColors c, BCThemeExtension ext) {
    final color = _statusColor(status, ext);
    final label = _statusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM + 4,
        vertical: AppConstants.paddingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
