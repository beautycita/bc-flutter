import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../config/constants.dart';
import '../../../config/theme_extension.dart';
import '../../../models/booking.dart';
import '../../../providers/booking_provider.dart';
import 'el_widgets.dart';

// ─── Filter tabs ────────────────────────────────────────────────────────────
enum _BookingTab { proximas, pasadas, canceladas }

/// Emerald Luxe variant of the My Bookings screen.
/// Art deco geometric frames (hexagonal/diamond CustomPainter), Cinzel / Raleway
/// fonts, gold gradient accents with emerald border trim, diamond ornament
/// dividers.
class ELMyBookingsScreen extends ConsumerStatefulWidget {
  const ELMyBookingsScreen({super.key});

  @override
  ConsumerState<ELMyBookingsScreen> createState() =>
      _ELMyBookingsScreenState();
}

class _ELMyBookingsScreenState extends ConsumerState<ELMyBookingsScreen> {
  _BookingTab _activeTab = _BookingTab.proximas;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _tabLabel(_BookingTab tab) {
    switch (tab) {
      case _BookingTab.proximas:
        return 'PROXIMAS';
      case _BookingTab.pasadas:
        return 'PASADAS';
      case _BookingTab.canceladas:
        return 'CANCELADAS';
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
        return 'PENDIENTE';
      case 'confirmed':
        return 'CONFIRMADA';
      case 'completed':
        return 'COMPLETADA';
      case 'cancelled_customer':
        return 'CANCELADA';
      case 'cancelled_business':
        return 'CANCELADA';
      case 'no_show':
        return 'NO ASISTIO';
      default:
        return status.toUpperCase();
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
    final c = ELColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
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
                // Gold line handle
                Center(
                  child: Container(
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(gradient: c.goldGradient),
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
                  'Cancelar Cita',
                  style: GoogleFonts.cinzel(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.gold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Text(
                  'Se cancelara tu cita de ${booking.serviceName}.'
                  '${booking.transportMode == 'uber' ? ' Tambien se cancelaran tus viajes de Uber.' : ''}',
                  style: GoogleFonts.raleway(
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
                            border: Border.all(
                              color: c.gold.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'MANTENER',
                            style: GoogleFonts.cinzel(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.gold,
                              letterSpacing: 2.0,
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
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'CANCELAR',
                            style: GoogleFonts.cinzel(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 2.0,
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
    final c = ELColors.of(context);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────
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
                        color: c.surface,
                        border: Border.all(
                          color: c.gold.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: c.gold,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      Text(
                        'MIS CITAS',
                        style: GoogleFonts.cinzel(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.gold,
                          letterSpacing: 4.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Diamond ornament
                      ELDiamondIndicator(size: 5),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // Balance
                ],
              ),
            ),

            // Gold accent divider
            const ELGoldAccent(showDiamond: true),

            // ── Tab Bar ──────────────────────────────────────────────────
            _buildTabBar(c),

            const SizedBox(height: 4),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: bookingsAsync.when(
                loading: () =>
                    const Center(child: ELGeometricDots()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingLG),
                    child: Text(
                      'Error al cargar citas: $err',
                      style: GoogleFonts.raleway(color: Colors.red),
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
                    color: c.gold,
                    backgroundColor: c.surface,
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
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(ELColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
        vertical: AppConstants.paddingXS,
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
                    border: Border.all(
                      color: isSelected
                          ? c.gold
                          : c.gold.withValues(alpha: 0.12),
                      width: isSelected ? 1.0 : 0.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: c.gold.withValues(alpha: 0.25),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _tabLabel(tab),
                        style: GoogleFonts.cinzel(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: isSelected ? c.bg : c.textSecondary,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 3),
                        ELDiamondIndicator(size: 4),
                      ],
                    ],
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

  Widget _buildEmptyState(ELColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ELDecoFrame(
              cornerSize: 16,
              padding: const EdgeInsets.all(20),
              child: Icon(
                Icons.calendar_today_rounded,
                size: AppConstants.iconSizeXXL,
                color: c.gold.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              _emptyMessage(),
              style: GoogleFonts.raleway(
                fontSize: 14,
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

  Widget _buildBookingCard(Booking booking, ELColors c, BCThemeExtension ext) {
    final canCancel =
        booking.status == 'pending' || booking.status == 'confirmed';

    return GestureDetector(
      onTap: () => context.push('/appointment/${booking.id}'),
      child: ELDecoCard(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        cornerLength: 12,
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
                    style: GoogleFonts.cinzel(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      letterSpacing: 0.5,
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
              style: GoogleFonts.raleway(
                fontSize: 14,
                color: c.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Gold line separator
            Container(
              height: 0.5,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.gold.withValues(alpha: 0.0),
                    c.gold.withValues(alpha: 0.3),
                    c.gold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),

            // Date
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: AppConstants.iconSizeSM,
                  color: c.gold.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppConstants.paddingXS),
                Expanded(
                  child: Text(
                    _formatDate(booking.scheduledAt),
                    style: GoogleFonts.raleway(
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
                  // Gold diamond before price
                  Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 5,
                      height: 5,
                      color: c.gold.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${booking.price!.toStringAsFixed(0)} MXN',
                    style: GoogleFonts.raleway(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.gold,
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
                      color: Colors.red.withValues(alpha: 0.08),
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
                          size: 14,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'CANCELAR',
                          style: GoogleFonts.cinzel(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade400,
                            letterSpacing: 1.5,
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

  Widget _buildStatusPill(String status, ELColors c, BCThemeExtension ext) {
    final color = _statusColor(status, ext);
    final label = _statusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM + 2,
        vertical: AppConstants.paddingXS - 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tiny diamond indicator
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 4,
              height: 4,
              color: color.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
