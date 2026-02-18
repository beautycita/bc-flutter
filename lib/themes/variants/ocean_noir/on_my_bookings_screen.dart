import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../config/constants.dart';
import '../../../config/theme_extension.dart';
import '../../../models/booking.dart';
import '../../../providers/booking_provider.dart';
import 'on_widgets.dart';

// ─── Filter tabs ────────────────────────────────────────────────────────────
enum _BookingTab { proximas, pasadas, canceladas }

/// Ocean Noir variant of the My Bookings screen.
/// Angular clipped cards (ONAngularClipper), Rajdhani/SourceSans3 fonts,
/// UPPERCASE text, cyan scan-line effects, ONHudFrame brackets, monospace
/// timestamps.
class ONMyBookingsScreen extends ConsumerStatefulWidget {
  const ONMyBookingsScreen({super.key});

  @override
  ConsumerState<ONMyBookingsScreen> createState() =>
      _ONMyBookingsScreenState();
}

class _ONMyBookingsScreenState extends ConsumerState<ONMyBookingsScreen> {
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

  /// Monospace timestamp format for HUD feel
  String _formatDateMono(DateTime dt) {
    return DateFormat('yyyy.MM.dd // HH:mm').format(dt);
  }

  /// Human-readable date line
  String _formatDateHuman(DateTime dt) {
    final formatter = DateFormat("EEEE d 'de' MMMM", 'es');
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
        return 'CANCELADA // SALON';
      case 'no_show':
        return 'NO ASISTIO';
      default:
        return status.toUpperCase();
    }
  }

  String _emptyMessage() {
    switch (_activeTab) {
      case _BookingTab.proximas:
        return 'NO HAY CITAS PROXIMAS';
      case _BookingTab.pasadas:
        return 'NO HAY CITAS PASADAS';
      case _BookingTab.canceladas:
        return 'NO HAY CITAS CANCELADAS';
    }
  }

  // ── Cancel flow ───────────────────────────────────────────────────────────

  Future<void> _cancelBooking(Booking booking) async {
    final c = ONColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface1,
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
                // Cyan line drag indicator
                Center(
                  child: Container(
                    width: 48,
                    height: 2,
                    color: c.cyan.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Icon(
                  Icons.warning_amber_rounded,
                  size: AppConstants.iconSizeXL,
                  color: c.red,
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  'CANCELAR CITA?',
                  style: GoogleFonts.rajdhani(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                Text(
                  'SERVICIO: ${booking.serviceName.toUpperCase()}'
                  '${booking.transportMode == 'uber' ? '\nTRANSPORTE UBER TAMBIEN SERA CANCELADO' : ''}',
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 11,
                    color: c.textMuted,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingLG),
                Row(
                  children: [
                    Expanded(
                      child: ONAngularButton(
                        label: 'MANTENER',
                        filled: false,
                        onTap: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    Expanded(
                      child: ONAngularButton(
                        label: 'CANCELAR',
                        color: c.red,
                        textColor: Colors.white,
                        onTap: () => Navigator.pop(ctx, true),
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
    final c = ONColors.of(context);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: c.surface0,
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
                        color: c.surface2,
                        border: Border.all(
                          color: c.cyan.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: c.cyan,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MIS CITAS',
                          style: GoogleFonts.rajdhani(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                            letterSpacing: 3.0,
                          ),
                        ),
                        Text(
                          'BOOKING REGISTRY // ${DateFormat('yyyy.MM.dd').format(DateTime.now())}',
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 9,
                            color: c.cyan.withValues(alpha: 0.5),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Cyan divider line
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.cyan.withValues(alpha: 0.0),
                    c.cyan.withValues(alpha: 0.4),
                    c.cyan.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),

            // ── Tab Bar ──────────────────────────────────────────────────
            _buildTabBar(c),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: bookingsAsync.when(
                loading: () => const Center(child: ONDataDots()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingLG),
                    child: Text(
                      'ERROR: $err',
                      style: GoogleFonts.sourceCodePro(
                        color: c.red,
                        fontSize: 12,
                      ),
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
                    color: c.cyan,
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
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(ONColors c) {
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
                child: ClipPath(
                  clipper: const ONAngularClipper(clipSize: 10),
                  child: Container(
                    height: AppConstants.minTouchHeight - 8,
                    decoration: BoxDecoration(
                      color: isSelected ? c.cyan : c.surface2,
                      border: Border.all(
                        color: isSelected
                            ? c.cyan
                            : c.cyan.withValues(alpha: 0.15),
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: c.cyan.withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _tabLabel(tab),
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: isSelected ? c.surface0 : c.textMuted,
                      ),
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

  Widget _buildEmptyState(ONColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ONHudFrame(
              bracketSize: 20,
              color: c.cyan.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(24),
              child: Icon(
                Icons.calendar_today_rounded,
                size: AppConstants.iconSizeXXL,
                color: c.cyan.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              _emptyMessage(),
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Booking Card ──────────────────────────────────────────────────────────

  Widget _buildBookingCard(Booking booking, ONColors c, BCThemeExtension ext) {
    final canCancel =
        booking.status == 'pending' || booking.status == 'confirmed';

    return GestureDetector(
      onTap: () => context.push('/appointment/${booking.id}'),
      child: ONHudFrame(
        bracketSize: 14,
        bracketThickness: 1.0,
        color: c.cyan.withValues(alpha: 0.4),
        padding: const EdgeInsets.all(2),
        child: ClipPath(
          clipper: const ONAngularClipper(clipSize: 14),
          child: Container(
            color: c.surface2,
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: provider name + status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (booking.providerName ?? 'PROVEEDOR').toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          letterSpacing: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    _buildStatusPill(booking.status, c, ext),
                  ],
                ),

                const SizedBox(height: 6),

                // Service name
                Text(
                  booking.serviceName.toUpperCase(),
                  style: GoogleFonts.sourceSans3(
                    fontSize: 13,
                    color: c.textSecondary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const ONCyanDivider(),

                // Monospace timestamp
                Row(
                  children: [
                    Icon(
                      Icons.access_time_filled_rounded,
                      size: 14,
                      color: c.cyan.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDateMono(booking.scheduledAt),
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.cyan,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Human date
                Text(
                  _formatDateHuman(booking.scheduledAt),
                  style: GoogleFonts.sourceSans3(
                    fontSize: 12,
                    color: c.textMuted,
                  ),
                ),

                // Price
                if (booking.price != null) ...[
                  const SizedBox(height: AppConstants.paddingSM),
                  Row(
                    children: [
                      Text(
                        'TOTAL: ',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.textMuted,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        '\$${booking.price!.toStringAsFixed(0)} MXN',
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.green,
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
                      child: ClipPath(
                        clipper: const ONAngularClipper(clipSize: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.paddingSM + 4,
                            vertical: AppConstants.paddingXS + 2,
                          ),
                          color: c.red.withValues(alpha: 0.12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                size: 14,
                                color: c.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'CANCELAR',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: c.red,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildStatusPill(String status, ONColors c, BCThemeExtension ext) {
    final color = _statusColor(status, ext);
    final label = _statusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM + 2,
        vertical: AppConstants.paddingXS - 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.rajdhani(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
