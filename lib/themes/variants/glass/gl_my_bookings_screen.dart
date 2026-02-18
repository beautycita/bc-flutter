import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../config/constants.dart';
import '../../../config/theme_extension.dart';
import '../../../models/booking.dart';
import '../../../providers/booking_provider.dart';
import 'gl_widgets.dart';

// ─── Filter tabs ────────────────────────────────────────────────────────────
enum _BookingTab { proximas, pasadas, canceladas }

/// Glass variant of the My Bookings screen.
/// Frosted glass cards with BackdropFilter, aurora blob background,
/// neon-colored status pills, neon-glowing tab indicator, GlFrostedPanel
/// containers.
class GLMyBookingsScreen extends ConsumerStatefulWidget {
  const GLMyBookingsScreen({super.key});

  @override
  ConsumerState<GLMyBookingsScreen> createState() =>
      _GLMyBookingsScreenState();
}

class _GLMyBookingsScreenState extends ConsumerState<GLMyBookingsScreen> {
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
        return Colors.grey.shade500;
      default:
        return Colors.grey;
    }
  }

  /// Map status to neon accent for glow effect
  Color _statusNeon(String status, GlColors c) {
    switch (status) {
      case 'pending':
        return c.amber;
      case 'confirmed':
        return c.neonCyan;
      case 'completed':
        return c.neonPurple;
      case 'cancelled_customer':
      case 'cancelled_business':
        return c.neonPink;
      default:
        return c.neonPurple;
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
    final c = GlColors.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXL),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusXL),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: SafeArea(
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
                            gradient: c.neonGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingMD),
                      NeonGlow(
                        color: c.neonPink,
                        blurRadius: 30,
                        child: Icon(
                          Icons.cancel_outlined,
                          size: AppConstants.iconSizeXL,
                          color: c.neonPink,
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingSM),
                      Text(
                        'Cancelar esta cita?',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingXS),
                      Text(
                        'Se cancelara tu cita de ${booking.serviceName}.'
                        '${booking.transportMode == 'uber' ? ' Tambien se cancelaran tus viajes de Uber.' : ''}',
                        style: GoogleFonts.inter(
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
                              child: GlFrostedPanel(
                                borderRadius: AppConstants.radiusLG,
                                padding: EdgeInsets.zero,
                                child: SizedBox(
                                  height: AppConstants.minTouchHeight,
                                  child: Center(
                                    child: Text(
                                      'No, mantener',
                                      style: GoogleFonts.inter(
                                        color: c.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                                  color: c.neonPink,
                                  borderRadius: BorderRadius.circular(
                                      AppConstants.radiusLG),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          c.neonPink.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Si, cancelar',
                                  style: GoogleFonts.inter(
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
              ),
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
    final c = GlColors.of(context);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: GlAuroraBackground(
        child: SafeArea(
          bottom: false,
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
                      child: GlFrostedPanel(
                        borderRadius: 12,
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.arrow_back_ios_rounded,
                          color: c.text,
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ShaderMask(
                      shaderCallback: (b) =>
                          c.neonGradient.createShader(b),
                      child: Text(
                        'MIS CITAS',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 42), // Balance back button
                  ],
                ),
              ),

              // ── Tab Bar ──────────────────────────────────────────────────
              _buildTabBar(c),

              const GlDivider(),

              // ── List ─────────────────────────────────────────────────────
              Expanded(
                child: bookingsAsync.when(
                  loading: () => const Center(child: GlNeonDots()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppConstants.paddingLG),
                      child: Text(
                        'Error al cargar citas: $err',
                        style: GoogleFonts.inter(color: c.neonPink),
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
                      color: c.neonCyan,
                      backgroundColor: c.bgDeep,
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
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(GlColors c) {
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
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMD),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      height: AppConstants.minTouchHeight - 8,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMD),
                        border: Border.all(
                          color: isSelected
                              ? c.neonCyan.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.10),
                          width: isSelected ? 1.0 : 0.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      c.neonCyan.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: isSelected
                          ? ShaderMask(
                              shaderCallback: (b) =>
                                  c.neonGradient.createShader(b),
                              child: Text(
                                _tabLabel(tab),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _tabLabel(tab),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: c.textMuted,
                              ),
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

  Widget _buildEmptyState(GlColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NeonGlow(
              color: c.neonPurple,
              blurRadius: 40,
              child: Icon(
                Icons.calendar_today_rounded,
                size: AppConstants.iconSizeXXL,
                color: c.neonPurple.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              _emptyMessage(),
              style: GoogleFonts.inter(
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

  Widget _buildBookingCard(Booking booking, GlColors c, BCThemeExtension ext) {
    final canCancel =
        booking.status == 'pending' || booking.status == 'confirmed';
    final neon = _statusNeon(booking.status, c);

    return GestureDetector(
      onTap: () => context.push('/appointment/${booking.id}'),
      child: GlFrostedPanel(
        borderRadius: 20,
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        borderOpacity: 0.12,
        shadows: [
          BoxShadow(
            color: neon.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
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
                    style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
                  color: c.neonCyan,
                ),
                const SizedBox(width: AppConstants.paddingXS),
                Expanded(
                  child: Text(
                    _formatDate(booking.scheduledAt),
                    style: GoogleFonts.inter(
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
                    color: c.neonPink,
                  ),
                  Text(
                    '\$${booking.price!.toStringAsFixed(0)} MXN',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.neonPink,
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
                      color: c.neonPink.withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSM),
                      border: Border.all(
                        color: c.neonPink.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: c.neonPink,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cancelar',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.neonPink,
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

  Widget _buildStatusPill(String status, GlColors c, BCThemeExtension ext) {
    final color = _statusColor(status, ext);
    final neon = _statusNeon(status, c);
    final label = _statusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM + 4,
        vertical: AppConstants.paddingXS,
      ),
      decoration: BoxDecoration(
        color: neon.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(
          color: neon.withValues(alpha: 0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: neon.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
