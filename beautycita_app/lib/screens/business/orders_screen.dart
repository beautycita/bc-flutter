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

Widget _OrderDetailRow(String label, String? value) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 130,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
      ),
      Expanded(
        child: Text(
          value ?? '—',
          style: GoogleFonts.nunito(fontSize: 13),
        ),
      ),
    ],
  ),
);

class _OrderCard extends ConsumerStatefulWidget {
  final Order order;
  final Future<void> Function(Order)? onAction;

  const _OrderCard({required this.order, required this.onAction});

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _loading = false;

  void _showOrderDetail(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          String fmtDt(DateTime? dt) {
            if (dt == null) return '—';
            final local = dt.toLocal();
            return '${local.day}/${local.month.toString().padLeft(2,'0')}/${local.year} '
                '${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';
          }
          String fmtAddr(Map<String, dynamic>? addr) {
            if (addr == null) return '—';
            final sb = StringBuffer();
            addr.forEach((k, v) { sb.write('$k: $v\n'); });
            return sb.toString().trim();
          }
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Detalle Pedido',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _OrderDetailRow('ID', order.id),
              _OrderDetailRow('Comprador ID', order.buyerId),
              _OrderDetailRow('Negocio ID', order.businessId),
              _OrderDetailRow('Producto ID', order.productId),
              _OrderDetailRow('Producto', order.productName),
              _OrderDetailRow('Cantidad', order.quantity.toString()),
              _OrderDetailRow('Total', '\$${order.totalAmount.toStringAsFixed(2)} MXN'),
              _OrderDetailRow('Comision', '\$${order.commissionAmount.toStringAsFixed(2)} MXN'),
              _OrderDetailRow('Estado', order.status),
              _OrderDetailRow('Rastreo', order.trackingNumber),
              _OrderDetailRow('Stripe PI', order.stripePaymentIntentId),
              _OrderDetailRow('Direccion', fmtAddr(order.shippingAddress)),
              _OrderDetailRow('Creado', fmtDt(order.createdAt)),
              _OrderDetailRow('Enviado', fmtDt(order.shippedAt)),
              _OrderDetailRow('Entregado', fmtDt(order.deliveredAt)),
              _OrderDetailRow('Reembolsado', fmtDt(order.refundedAt)),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final order = widget.order;

    return GestureDetector(
      onTap: () => _showOrderDetail(context, order),
      child: Container(
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

          // Shipping deadline countdown for paid orders
          if (order.isPaid) ...[
            const SizedBox(height: AppConstants.paddingSM),
            _ShippingDeadlineBar(order: order),
          ],

          // Tracking number display or entry
          if (order.trackingNumber != null && order.trackingNumber!.isNotEmpty) ...[
            const SizedBox(height: AppConstants.paddingSM),
            Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    size: 13, color: const Color(0xFF059669)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Rastreo: ${order.trackingNumber}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF059669),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

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

          // Tracking number entry button for paid orders without tracking
          if (order.isPaid && (order.trackingNumber == null || order.trackingNumber!.isEmpty)) ...[
            const SizedBox(height: AppConstants.paddingSM),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _showTrackingNumberSheet(context, order),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: Text(
                  'Ingresa numero de rastreo',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  ),
                ),
              ),
            ),
          ],

          // Action button
          if (widget.onAction != null) ...[
            const SizedBox(height: AppConstants.paddingSM),
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
    ),
    );
  }

  void _showTrackingNumberSheet(BuildContext context, Order order) {
    final controller = TextEditingController(text: order.trackingNumber ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final colors = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Numero de Rastreo',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ingresa el numero de guia o rastreo del envio para que el cliente pueda seguir su pedido.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Numero de guia',
                    hintText: 'Ej: 1Z999AA10123456784',
                    prefixIcon: const Icon(Icons.local_shipping_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.primary, width: 2),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final tracking = controller.text.trim();
                          if (tracking.isEmpty) {
                            ToastService.showWarning('Ingresa un numero de rastreo');
                            return;
                          }
                          setSheetState(() => saving = true);
                          try {
                            final service = ref.read(orderServiceProvider);
                            await service.updateTrackingNumber(order.id, tracking);
                            ref.invalidate(businessOrdersProvider);
                            ToastService.showSuccess('Numero de rastreo guardado');
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            ToastService.showErrorWithDetails('Error al guardar', e);
                          } finally {
                            if (ctx.mounted) setSheetState(() => saving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Guardar', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        },
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
// Shipping deadline countdown bar
// ---------------------------------------------------------------------------

class _ShippingDeadlineBar extends StatelessWidget {
  final Order order;
  const _ShippingDeadlineBar({required this.order});

  @override
  Widget build(BuildContext context) {
    final daysLeft = order.shippingDeadlineDaysLeft;
    final isOverdue = order.isShippingOverdue;
    final isUrgent = order.isShippingUrgent;
    final progress = ((14 - daysLeft) / 14).clamp(0.0, 1.0);

    final Color barColor;
    final Color bgColor;
    final String label;

    if (isOverdue) {
      barColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFEE2E2);
      label = 'Vencido hace ${daysLeft.abs()} dia${daysLeft.abs() == 1 ? '' : 's'}';
    } else if (isUrgent) {
      barColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFEF3C7);
      label = '$daysLeft dia${daysLeft == 1 ? '' : 's'} para enviar';
    } else {
      barColor = const Color(0xFF059669);
      bgColor = const Color(0xFFD1FAE5);
      label = '$daysLeft dias para enviar';
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                size: 14,
                color: barColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
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
