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
import '../../providers/client_bookings_provider.dart';
import '../../widgets/empty_state.dart';

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
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding.clamp(16.0, double.infinity),
                    BCSpacing.md,
                    horizontalPadding.clamp(16.0, double.infinity),
                    BCSpacing.xxl,
                  ),
                  sliver: SliverList.builder(
                    itemCount: state.activeList.length,
                    itemBuilder: (context, index) {
                      final booking = state.activeList[index];
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: BCSpacing.sm),
                        child: _BookingCard(
                          booking: booking,
                          isUpcoming:
                              state.activeTab == BookingsTab.upcoming,
                          onCancel: () =>
                              _showCancelDialog(context, booking),
                        ),
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 50 * index),
                            duration: const Duration(milliseconds: 300),
                          )
                          .slideY(
                            begin: 0.05,
                            end: 0,
                            delay: Duration(milliseconds: 50 * index),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                    },
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: BCSpacing.iconXl,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: BCSpacing.lg),
            Text(
              'Inicia sesión para ver tus citas',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BCSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.go(WebRoutes.auth),
              icon: const Icon(Icons.login),
              label: const Text('Iniciar sesión'),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mis Citas',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          FilledButton.icon(
            onPressed: () => context.go(WebRoutes.reservar),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva Reservación'),
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
    final theme = Theme.of(context);
    return TabBar(
      controller: controller,
      labelColor: theme.colorScheme.primary,
      unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      indicatorColor: theme.colorScheme.primary,
      tabs: [
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Próximas'),
              if (upcomingCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
                  ),
                  child: Text(
                    '$upcomingCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Tab(text: 'Pasadas'),
        const Tab(text: 'Canceladas'),
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = widget.booking;
    final dateFormat = DateFormat("EEE d 'de' MMM, yyyy", 'es');
    final timeFormat = DateFormat('h:mm a', 'es');

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        child: Card(
          elevation: _hovered ? BCSpacing.elevationMedium : BCSpacing.elevationLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BCSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Service name + status badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.serviceName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusBadge(status: b.status),
                  ],
                ),
                const SizedBox(height: BCSpacing.xs),

                // Row 2: Salon name
                if (b.providerName != null)
                  Row(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text(
                        b.providerName!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: BCSpacing.xs),

                // Row 3: Date, time, duration
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text(
                      '${dateFormat.format(b.scheduledAt)} · '
                      '${timeFormat.format(b.scheduledAt)} · '
                      '${b.durationMinutes} min',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),

                // Row 4: Price + payment status
                if (b.price != null && b.price! > 0) ...[
                  const SizedBox(height: BCSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.payments_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text(
                        '\$${b.price!.toStringAsFixed(0)} MXN',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (b.paymentStatus != null) ...[
                        const SizedBox(width: BCSpacing.sm),
                        _PaymentStatusText(status: b.paymentStatus!),
                      ],
                    ],
                  ),
                ],

                // Action buttons
                if (widget.isUpcoming &&
                    (b.status == 'pending' || b.status == 'confirmed')) ...[
                  const SizedBox(height: BCSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: BCSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (b.providerName != null)
                        TextButton.icon(
                          onPressed: () => _contactSalon(b),
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('Contactar Salón'),
                        ),
                      const SizedBox(width: BCSpacing.sm),
                      TextButton.icon(
                        onPressed: widget.onCancel,
                        icon: Icon(Icons.cancel_outlined,
                            size: 18,
                            color: theme.colorScheme.error),
                        label: Text(
                          'Cancelar',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _contactSalon(Booking b) {
    // Open WhatsApp with the salon (placeholder — real phone would come from business data)
    final message = Uri.encodeComponent(
      'Hola, tengo una cita de ${b.serviceName} agendada. '
      'Quisiera confirmar los detalles.',
    );
    launchUrl(Uri.parse('https://wa.me/?text=$message'));
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusInfo(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static (String, Color) _statusInfo(String status, ColorScheme colors) {
    return switch (status) {
      'pending' => ('Pendiente', Colors.amber.shade700),
      'confirmed' => ('Confirmada', colors.primary),
      'completed' => ('Completada', Colors.green.shade600),
      'cancelled_customer' => ('Cancelada', colors.error),
      'cancelled_business' => ('Cancelada por salón', colors.error),
      'no_show' => ('No asistió', Colors.grey),
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: BCSpacing.iconXl,
                color: theme.colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: BCSpacing.md),
            Text(message, style: theme.textTheme.bodyLarge),
            const SizedBox(height: BCSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
