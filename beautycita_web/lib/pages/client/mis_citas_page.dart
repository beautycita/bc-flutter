import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/breakpoints.dart';
import '../../config/router.dart';
import '../../config/web_theme.dart';
import '../../providers/client_bookings_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/web_design_system.dart';

// ── Main page ────────────────────────────────────────────────────────────────

class MisCitasPage extends ConsumerStatefulWidget {
  const MisCitasPage({super.key});

  @override
  ConsumerState<MisCitasPage> createState() => _MisCitasPageState();
}

class _MisCitasPageState extends ConsumerState<MisCitasPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientBookingsProvider.notifier).fetchBookings();
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    const tabs = [BookingsTab.upcoming, BookingsTab.past, BookingsTab.cancelled];
    ref.read(clientBookingsProvider.notifier).setTab(tabs[_tabController.index]);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auth gate
    if (!BCSupabase.isAuthenticated) {
      return _AuthGate();
    }

    final state = ref.watch(clientBookingsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(width);
        final horizontalPadding = isDesktop ? (width - 800) / 2 : 16.0;

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(clientBookingsProvider.notifier).fetchBookings(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding.clamp(16.0, double.infinity),
                    BCSpacing.lg,
                    horizontalPadding.clamp(16.0, double.infinity),
                    0,
                  ),
                  child: _Header(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding.clamp(16.0, double.infinity),
                  ),
                  child: _TabBarSection(
                    controller: _tabController,
                    upcomingCount: state.upcoming.length,
                  ),
                ),
              ),
              if (state.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          horizontalPadding.clamp(16.0, double.infinity),
                    ),
                    child: const _BookingCardsSkeleton(),
                  ),
                )
              else if (state.error != null)
                SliverToBoxAdapter(
                  child: _ErrorView(
                    message: state.error!,
                    onRetry: () => ref
                        .read(clientBookingsProvider.notifier)
                        .fetchBookings(),
                  ),
                )
              else if (state.activeList.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyTab(tab: state.activeTab),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding.clamp(16.0, double.infinity),
                      BCSpacing.md,
                      horizontalPadding.clamp(16.0, double.infinity),
                      BCSpacing.xxl,
                    ),
                    child: StaggeredFadeIn(
                      staggerDelay: const Duration(milliseconds: 80),
                      spacing: BCSpacing.sm,
                      children: [
                        for (final booking in state.activeList)
                          _BookingCard(
                            booking: booking,
                            isUpcoming:
                                state.activeTab == BookingsTab.upcoming,
                            onCancel: () =>
                                _showCancelDialog(context, booking),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCancelDialog(BuildContext context, Booking booking) async {
    final scaffold = ScaffoldMessenger.of(context);
    final colors = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Estás segura de que quieres cancelar tu cita de '
          '${booking.serviceName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, mantener'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success =
        await ref.read(clientBookingsProvider.notifier).cancelBooking(booking.id);

    if (!mounted) return;

    scaffold.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Cita cancelada exitosamente'
              : 'Error al cancelar la cita. Intenta de nuevo.',
        ),
        backgroundColor: success ? colors.primary : colors.error,
      ),
    );
  }
}

// ── Auth gate ────────────────────────────────────────────────────────────────

class _AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kWebPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outlined,
                size: 36,
                color: kWebTextHint,
              ),
            ),
            const SizedBox(height: BCSpacing.lg),
            const Text(
              'Inicia sesion para ver tus citas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BCSpacing.lg),
            WebGradientButton(
              onPressed: () => context.go(WebRoutes.auth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.login_outlined, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Iniciar sesion'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const WebSectionHeader(
            label: 'Mis Citas',
            title: 'Mis Citas',
            centered: false,
            titleSize: 32,
          ),
          WebGradientButton(
            onPressed: () => context.go(WebRoutes.reservar),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_outlined, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Nueva Reservacion'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ──────────────────────────────────────────────────────────────────

class _TabBarSection extends StatelessWidget {
  const _TabBarSection({
    required this.controller,
    required this.upcomingCount,
  });

  final TabController controller;
  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      labelColor: kWebPrimary,
      unselectedLabelColor: kWebTextSecondary,
      indicatorColor: kWebPrimary,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: 'system-ui',
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'system-ui',
      ),
      dividerColor: kWebCardBorder,
      tabs: [
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_outlined, size: 16),
              const SizedBox(width: 6),
              const Text('Proximas'),
              if (upcomingCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: kWebBrandGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$upcomingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_outlined, size: 16),
              SizedBox(width: 6),
              Text('Pasadas'),
            ],
          ),
        ),
        const Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 16),
              SizedBox(width: 6),
              Text('Canceladas'),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Booking card ─────────────────────────────────────────────────────────────

class _BookingCard extends StatefulWidget {
  const _BookingCard({
    required this.booking,
    required this.isUpcoming,
    required this.onCancel,
  });

  final Booking booking;
  final bool isUpcoming;
  final VoidCallback onCancel;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final dateFormat = DateFormat("EEE d 'de' MMM, yyyy", 'es');
    final timeFormat = DateFormat('h:mm a', 'es');

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Service name + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  b.serviceName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kWebTextPrimary,
                    fontFamily: 'system-ui',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadge(status: b.status),
            ],
          ),
          const SizedBox(height: 16),

          // Row 2: Salon name
          if (b.providerName != null)
            WebInfoRow(
              icon: Icons.storefront_outlined,
              iconColor: kWebSecondary,
              label: 'Salon',
              value: b.providerName!,
            ),
          if (b.providerName != null) const SizedBox(height: 12),

          // Row 3: Date, time, duration
          WebInfoRow(
            icon: Icons.calendar_today_outlined,
            iconColor: kWebTertiary,
            label: 'Fecha y hora',
            value: '${dateFormat.format(b.scheduledAt)} \u00b7 '
                '${timeFormat.format(b.scheduledAt)} \u00b7 '
                '${b.durationMinutes} min',
          ),

          // Row 4: Price + payment status
          if (b.price != null && b.price! > 0) ...[
            const SizedBox(height: 12),
            WebInfoRow(
              icon: Icons.payments_outlined,
              iconColor: kWebPrimary,
              label: 'Precio',
              value: '\$${b.price!.toStringAsFixed(0)} MXN',
              trailing: b.paymentStatus != null
                  ? _PaymentStatusText(status: b.paymentStatus!)
                  : null,
            ),
          ],

          // Action buttons
          if (widget.isUpcoming &&
              (b.status == 'pending' || b.status == 'confirmed')) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: kWebCardBorder),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (b.providerName != null)
                  WebOutlinedButton(
                    onPressed: () => _contactSalon(b),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_outlined,
                            size: 16, color: kWebPrimary),
                        const SizedBox(width: 6),
                        const Text('Contactar Salon'),
                      ],
                    ),
                  ),
                const SizedBox(width: BCSpacing.sm),
                TextButton.icon(
                  onPressed: widget.onCancel,
                  icon: Icon(Icons.cancel_outlined,
                      size: 16, color: Colors.red.shade600),
                  label: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _contactSalon(Booking b) {
    final message = Uri.encodeComponent(
      'Hola, tengo una cita de ${b.serviceName} agendada. '
      'Quisiera confirmar los detalles.',
    );
    final phone = b.businessPhone?.replaceAll(RegExp(r'[^\d]'), '');
    if (phone != null && phone.isNotEmpty) {
      launchUrl(Uri.parse('https://wa.me/$phone?text=$message'));
    } else {
      // Fallback: open WhatsApp with message only (no specific recipient)
      launchUrl(Uri.parse('https://wa.me/?text=$message'));
    }
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'system-ui',
        ),
      ),
    );
  }

  static (String, Color) _statusInfo(String status) {
    return switch (status) {
      'pending' => ('Pendiente', Colors.amber.shade700),
      'confirmed' => ('Confirmada', const Color(0xFF22C55E)),
      'completed' => ('Completada', const Color(0xFF22C55E)),
      'cancelled_customer' => ('Cancelada', const Color(0xFFEF4444)),
      'cancelled_business' => ('Cancelada por salon', const Color(0xFFEF4444)),
      'no_show' => ('No asistio', Colors.grey),
      _ => (status, Colors.grey),
    };
  }
}

// ── Payment status text ──────────────────────────────────────────────────────

class _PaymentStatusText extends StatelessWidget {
  const _PaymentStatusText({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _paymentInfo(status);
    return Text(
      '· $label',
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static (String, Color) _paymentInfo(String status) {
    return switch (status) {
      'paid' => ('Pagado', Colors.green.shade600),
      'pending' => ('Pago pendiente', Colors.amber.shade700),
      'refunded' => ('Reembolsado', Colors.blue.shade600),
      'failed' => ('Pago fallido', Colors.red.shade600),
      _ => ('Sin pago', Colors.grey),
    };
  }
}

// ── Skeleton loading ─────────────────────────────────────────────────────────

class _BookingCardsSkeleton extends StatelessWidget {
  const _BookingCardsSkeleton();

  @override
  Widget build(BuildContext context) {
    final baseColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    return Column(
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(
              top: BCSpacing.md,
              bottom: BCSpacing.xs,
            ),
            child: _SkeletonCard(baseColor: baseColor),
          ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.baseColor});
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: BCSpacing.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _shimmerBar(baseColor, 14, 0.6)),
                const SizedBox(width: BCSpacing.md),
                _shimmerBar(baseColor, 14, 0.15, fixed: true),
              ],
            ),
            const SizedBox(height: BCSpacing.sm),
            _shimmerBar(baseColor, 12, 0.4),
            const SizedBox(height: BCSpacing.xs),
            _shimmerBar(baseColor, 12, 0.7),
            const SizedBox(height: BCSpacing.xs),
            _shimmerBar(baseColor, 12, 0.3),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBar(Color color, double height, double widthFactor,
      {bool fixed = false}) {
    final bar = Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(BCSpacing.xs),
      ),
    );

    final widget = fixed
        ? SizedBox(width: 80, child: bar)
        : FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor,
            child: bar,
          );

    return widget
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1200),
          color: Colors.white.withValues(alpha: 0.04),
        );
  }
}

// ── Empty states ─────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.tab});
  final BookingsTab tab;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      BookingsTab.upcoming => EmptyState(
          icon: Icons.calendar_month_outlined,
          title: 'No tienes citas próximas',
          subtitle: 'Reserva tu primer servicio de belleza',
          action: FilledButton.icon(
            onPressed: () => context.go(WebRoutes.reservar),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Reservar ahora'),
          ),
        ),
      BookingsTab.past => const EmptyState(
          icon: Icons.history,
          title: 'Aún no tienes citas pasadas',
          subtitle: 'Tus citas completadas aparecerán aquí',
        ),
      BookingsTab.cancelled => const EmptyState(
          icon: Icons.cancel_outlined,
          title: 'No tienes citas canceladas',
        ),
    };
  }
}

// ── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outlined,
                  size: 36,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.6)),
            ),
            const SizedBox(height: BCSpacing.md),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
            ),
            const SizedBox(height: BCSpacing.md),
            WebOutlinedButton(
              onPressed: onRetry,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_outlined, size: 16, color: kWebPrimary),
                  const SizedBox(width: 6),
                  const Text('Reintentar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
