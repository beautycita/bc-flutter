import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beautycita_core/models.dart' hide Provider;
import '../../config/constants.dart';
import '../../providers/order_provider.dart';
import '../../services/toast_service.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ordersAsync = ref.watch(businessOrdersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: colors.primary,
              unselectedLabelColor: const Color(0xFF757575),
              indicatorColor: colors.primary,
              indicatorWeight: 2.5,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Pendientes'),
                Tab(text: 'Enviados'),
                Tab(text: 'Completados'),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final pending =
                    orders.where((o) => o.isPaid).toList();
                final shipped =
                    orders.where((o) => o.isShipped).toList();
                final completed = orders
                    .where((o) =>
                        o.isDelivered || o.isRefunded || o.isCancelled)
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _OrderList(
                      orders: pending,
                      emptyMessage: 'No hay pedidos pendientes',
                      emptySubtext: 'Los pedidos nuevos apareceran aqui',
                      onRefresh: () async =>
                          ref.invalidate(businessOrdersProvider),
                      onAction: _markShipped,
                    ),
                    _OrderList(
                      orders: shipped,
                      emptyMessage: 'No hay pedidos en camino',
                      emptySubtext:
                          'Marca los pedidos como enviados para verlos aqui',
                      onRefresh: () async =>
                          ref.invalidate(businessOrdersProvider),
                      onAction: _markDelivered,
                    ),
                    _OrderList(
                      orders: completed,
                      emptyMessage: 'Sin pedidos completados aun',
                      emptySubtext:
                          'Los pedidos entregados, reembolsados y cancelados apareceran aqui',
                      onRefresh: () async =>
                          ref.invalidate(businessOrdersProvider),
                      onAction: null,
                    ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48,
                        color: colors.error.withValues(alpha: 0.6)),
                    const SizedBox(height: AppConstants.paddingSM),
                    Text(
                      'Error cargando pedidos',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingXS),
                    Text(
                      e.toString(),
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: const Color(0xFF757575),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.paddingMD),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(businessOrdersProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text('Reintentar',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markShipped(Order order) async {
    final service = ref.read(orderServiceProvider);
    try {
      await service.markShipped(order.id);
      ref.invalidate(businessOrdersProvider);
      ToastService.showSuccess('Pedido marcado como enviado');
    } catch (e) {
      ToastService.showErrorWithDetails(
          'No se pudo actualizar el pedido', e);
    }
  }

  Future<void> _markDelivered(Order order) async {
    final service = ref.read(orderServiceProvider);
    try {
      await service.markDelivered(order.id);
      ref.invalidate(businessOrdersProvider);
      ToastService.showSuccess('Pedido marcado como entregado');
    } catch (e) {
      ToastService.showErrorWithDetails(
          'No se pudo actualizar el pedido', e);
    }
  }
}

// ---------------------------------------------------------------------------
// Order list tab
// ---------------------------------------------------------------------------

class _OrderList extends StatelessWidget {
  final List<Order> orders;
  final String emptyMessage;
  final String emptySubtext;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Order)? onAction;

  const _OrderList({
    required this.orders,
    required this.emptyMessage,
    required this.emptySubtext,
    required this.onRefresh,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: _EmptyState(
                  message: emptyMessage, subtext: emptySubtext),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        itemCount: orders.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppConstants.paddingSM),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _OrderCard(order: order, onAction: onAction);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order card
// ---------------------------------------------------------------------------

class _OrderCard extends StatefulWidget {
  final Order order;
  final Future<void> Function(Order)? onAction;

  const _OrderCard({required this.order, required this.onAction});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final order = widget.order;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: product name + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  order.productName,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              _StatusBadge(status: order.status),
            ],
          ),

          const SizedBox(height: AppConstants.paddingXS),

          // Quantity + amount row
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 14, color: const Color(0xFF9E9E9E)),
              const SizedBox(width: 4),
              Text(
                'x${order.quantity}',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: const Color(0xFF757575),
                ),
              ),
              const SizedBox(width: AppConstants.paddingMD),
              Icon(Icons.attach_money,
                  size: 14, color: const Color(0xFF4CAF50)),
              Text(
                '\$${order.totalAmount.toStringAsFixed(2)} MXN',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF212121),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingXS),

          // Date row
          Row(
            children: [
              Icon(Icons.access_time,
                  size: 13, color: const Color(0xFF9E9E9E)),
              const SizedBox(width: 4),
              Text(
                _formatDate(order.createdAt),
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
              if (order.daysSinceOrder > 2 && order.isPaid) ...[
                const SizedBox(width: AppConstants.paddingSM),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusFull),
                  ),
                  child: Text(
                    'hace ${order.daysSinceOrder} dias',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Shipping address snippet (if present)
          if (order.shippingAddress != null &&
              order.shippingAddress!.isNotEmpty) ...[
            const SizedBox(height: AppConstants.paddingXS),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 13, color: const Color(0xFF9E9E9E)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatAddress(order.shippingAddress!),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: const Color(0xFF757575),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Action button
          if (widget.onAction != null) ...[
            const SizedBox(height: AppConstants.paddingMD),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        await widget.onAction!(order);
                        if (mounted) setState(() => _loading = false);
                      },
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        order.isPaid
                            ? Icons.local_shipping_outlined
                            : Icons.check_circle_outline,
                        size: 18,
                      ),
                label: Text(
                  order.isPaid ? 'Marcar Enviado' : 'Marcar Entregado',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: order.isPaid
                      ? colors.primary
                      : const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusSM),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  String _formatAddress(Map<String, dynamic> addr) {
    final parts = <String>[];
    if (addr['street'] != null) parts.add(addr['street'] as String);
    if (addr['city'] != null) parts.add(addr['city'] as String);
    if (addr['state'] != null) parts.add(addr['state'] as String);
    if (parts.isEmpty) return addr.values.first.toString();
    return parts.join(', ');
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _resolveStyle(status);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  (String, Color, Color) _resolveStyle(String status) {
    switch (status) {
      case 'paid':
        return (
          'Pagado',
          const Color(0xFF3B82F6).withValues(alpha: 0.12),
          const Color(0xFF1D4ED8),
        );
      case 'shipped':
        return (
          'Enviado',
          const Color(0xFFF59E0B).withValues(alpha: 0.14),
          const Color(0xFFB45309),
        );
      case 'delivered':
        return (
          'Entregado',
          const Color(0xFF4CAF50).withValues(alpha: 0.14),
          const Color(0xFF2E7D32),
        );
      case 'refunded':
        return (
          'Reembolsado',
          const Color(0xFF8B5CF6).withValues(alpha: 0.12),
          const Color(0xFF6D28D9),
        );
      case 'cancelled':
        return (
          'Cancelado',
          const Color(0xFF9E9E9E).withValues(alpha: 0.14),
          const Color(0xFF616161),
        );
      default:
        return (
          status,
          const Color(0xFF9E9E9E).withValues(alpha: 0.14),
          const Color(0xFF616161),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final String message;
  final String subtext;
  const _EmptyState({required this.message, required this.subtext});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: colors.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF212121),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingXS),
            Text(
              subtext,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: const Color(0xFF757575),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
