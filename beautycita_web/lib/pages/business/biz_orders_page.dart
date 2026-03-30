import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _ordersTabProvider = StateProvider<String>((ref) => 'pending');
final _selectedOrderProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

final _ordersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  final rows = await BCSupabase.client
      .from('orders')
      .select()
      .eq('business_id', bizId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

// ── Page ─────────────────────────────────────────────────────────────────────

class BizOrdersPage extends ConsumerWidget {
  const BizOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _OrdersContent(bizId: biz['id'] as String);
      },
    );
  }
}

// ── Content ──────────────────────────────────────────────────────────────────

class _OrdersContent extends ConsumerWidget {
  const _OrdersContent({required this.bizId});
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_ordersProvider(bizId));
    final tab = ref.watch(_ordersTabProvider);
    final selected = ref.watch(_selectedOrderProvider);

    final statusMap = {
      'pending': 'Pendiente',
      'shipped': 'Enviado',
      'completed': 'Completado',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
        final showPanel = selected != null && isDesktop;

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header + tabs
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    decoration: const BoxDecoration(
                      color: kWebSurface,
                      border: Border(
                          bottom: BorderSide(color: kWebCardBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ordersAsync.when(
                          loading: () => _buildHeader(context, 0),
                          error: (_, __) => _buildHeader(context, 0),
                          data: (orders) => _buildHeader(
                              context, orders.length),
                        ),
                        const SizedBox(height: 16),
                        // Tab bar
                        Row(
                          children: statusMap.entries
                              .map((e) => _TabButton(
                                    label: e.value,
                                    isActive: tab == e.key,
                                    count: ordersAsync.whenOrNull(
                                      data: (orders) => orders
                                          .where((o) =>
                                              o['status'] == e.key)
                                          .length,
                                    ),
                                    onTap: () {
                                      ref
                                          .read(_ordersTabProvider
                                              .notifier)
                                          .state = e.key;
                                      ref
                                          .read(_selectedOrderProvider
                                              .notifier)
                                          .state = null;
                                    },
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                  // Table
                  Expanded(
                    child: ordersAsync.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                          child:
                              Text('Error al cargar ordenes: $e')),
                      data: (orders) {
                        final filtered = orders
                            .where((o) => o['status'] == tab)
                            .toList();
                        return filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'Sin ordenes en este estado',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: kWebTextHint),
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: _OrdersTable(
                                  orders: filtered,
                                  isDesktop: isDesktop,
                                  selectedId: selected?['id']
                                      as String?,
                                  onSelect: (o) {
                                    ref
                                        .read(_selectedOrderProvider
                                            .notifier)
                                        .state =
                                        selected?['id'] == o['id']
                                            ? null
                                            : o;
                                  },
                                ),
                              );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Detail panel
            if (showPanel) ...[
              const VerticalDivider(width: 1, color: kWebCardBorder),
              SizedBox(
                width: 400,
                child: _OrderDetailPanel(
                    order: selected, bizId: bizId),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ordenes',
              style: theme.textTheme.titleLarge?.copyWith(
                color: kWebTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$count ordenes totales',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextHint),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.count,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? kWebPrimary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive ? kWebPrimary : kWebTextSecondary,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? kWebPrimary.withValues(alpha: 0.1)
                      : kWebCardBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isActive ? kWebPrimary : kWebTextHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Orders Table ──────────────────────────────────────────────────────────────

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({
    required this.orders,
    required this.isDesktop,
    required this.selectedId,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> orders;
  final bool isDesktop;
  final String? selectedId;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String fmtMoney(dynamic v) =>
        v == null ? '-' : '\$${(v as num).toStringAsFixed(2)}';
    String fmtDate(dynamic v) {
      if (v == null) return '-';
      try {
        final d = DateTime.parse(v.toString());
        return '${d.day}/${d.month}/${d.year}';
      } catch (_) {
        return v.toString();
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: isDesktop
              ? const {
                  0: FlexColumnWidth(1.5),
                  1: FlexColumnWidth(2.5),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.2),
                  5: FlexColumnWidth(2),
                  6: FlexColumnWidth(1.3),
                }
              : const {
                  0: FlexColumnWidth(1.5),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                },
          children: [
            // Header
            TableRow(
              decoration: const BoxDecoration(color: kWebBackground),
              children: [
                _th(theme, 'Orden ID'),
                _th(theme, 'Producto'),
                _th(theme, 'Cant.'),
                _th(theme, 'Monto'),
                if (isDesktop) ...[
                  _th(theme, 'Estado'),
                  _th(theme, 'Tracking'),
                  _th(theme, 'Creado'),
                ],
              ],
            ),

            // Rows
            for (final o in orders)
              TableRow(
                decoration: BoxDecoration(
                  color: selectedId == (o['id'] as String?)
                      ? kWebPrimary.withValues(alpha: 0.04)
                      : null,
                  border: const Border(
                    top: BorderSide(
                        color: kWebCardBorder, width: 0.5),
                  ),
                ),
                children: [
                  _td(theme,
                      child: _ClickableOrderId(
                        orderId: o['id'] as String? ?? '',
                        onTap: () => onSelect(o),
                      )),
                  _td(theme,
                      child: Text(
                        o['product_name'] as String? ?? '-',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kWebTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )),
                  _td(theme,
                      child: Text(
                        '${o['quantity'] ?? 1}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kWebTextSecondary),
                      )),
                  _td(theme,
                      child: Text(
                        fmtMoney(o['amount']),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: kWebTextPrimary,
                            fontWeight: FontWeight.w600),
                      )),
                  if (isDesktop) ...[
                    _td(theme,
                        child: _OrderStatusBadge(
                            status: o['status'] as String? ??
                                'pending')),
                    _td(theme,
                        child: Text(
                          o['tracking_number'] as String? ?? '-',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: o['tracking_number'] != null
                                ? kWebTertiary
                                : kWebTextHint,
                          ),
                        )),
                    _td(theme,
                        child: Text(
                          fmtDate(o['created_at']),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWebTextHint),
                        )),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _th(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: kWebTextHint,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _td(ThemeData theme, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: child,
    );
  }
}

class _ClickableOrderId extends StatefulWidget {
  const _ClickableOrderId({required this.orderId, required this.onTap});
  final String orderId;
  final VoidCallback onTap;

  @override
  State<_ClickableOrderId> createState() => _ClickableOrderIdState();
}

class _ClickableOrderIdState extends State<_ClickableOrderId> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          '#${widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _hov ? kWebPrimary : kWebTextSecondary,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'pending':
        bg = Colors.orange.withValues(alpha: 0.1);
        fg = Colors.orange.shade800;
        label = 'Pendiente';
      case 'shipped':
        bg = kWebTertiary.withValues(alpha: 0.1);
        fg = kWebTertiary;
        label = 'Enviado';
      case 'completed':
        bg = Colors.green.withValues(alpha: 0.1);
        fg = Colors.green.shade700;
        label = 'Completado';
      case 'cancelled':
        bg = Colors.red.withValues(alpha: 0.1);
        fg = Colors.red.shade700;
        label = 'Cancelado';
      default:
        bg = kWebCardBorder;
        fg = kWebTextHint;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Detail Panel ─────────────────────────────────────────────────────────────

class _OrderDetailPanel extends ConsumerStatefulWidget {
  const _OrderDetailPanel({required this.order, required this.bizId});
  final Map<String, dynamic> order;
  final String bizId;

  @override
  ConsumerState<_OrderDetailPanel> createState() =>
      _OrderDetailPanelState();
}

class _OrderDetailPanelState extends ConsumerState<_OrderDetailPanel> {
  final _trackingCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _trackingCtrl.text =
        widget.order['tracking_number'] as String? ?? '';
  }

  @override
  void didUpdateWidget(_OrderDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.order['id'] != widget.order['id']) {
      _trackingCtrl.text =
          widget.order['tracking_number'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _trackingCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{'status': newStatus};
      if (newStatus == 'shipped' &&
          _trackingCtrl.text.trim().isNotEmpty) {
        updates['tracking_number'] = _trackingCtrl.text.trim();
      }
      await BCSupabase.client
          .from('orders')
          .update(updates)
          .eq('id', widget.order['id'].toString());

      ref.invalidate(_ordersProvider(widget.bizId));
      ref.read(_ordersTabProvider.notifier).state = newStatus;
      ref.read(_selectedOrderProvider.notifier).state = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Orden marcada como $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = widget.order;

    String fmtDate(dynamic v) {
      if (v == null) return '-';
      try {
        final d = DateTime.parse(v.toString());
        return '${d.day}/${d.month}/${d.year}';
      } catch (_) {
        return v.toString();
      }
    }

    String fmtMoney(dynamic v) =>
        v == null ? '-' : '\$${(v as num).toStringAsFixed(2)}';

    final status = o['status'] as String? ?? 'pending';

    return Container(
      color: kWebSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kWebCardBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'Detalle de Orden',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: kWebTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_outlined,
                      size: 20, color: kWebTextHint),
                  onPressed: () => ref
                      .read(_selectedOrderProvider.notifier)
                      .state = null,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order ID + status
                  Row(
                    children: [
                      Text(
                        '#${(o['id'] as String? ?? '').length > 8 ? (o['id'] as String).substring(0, 8).toUpperCase() : (o['id'] as String? ?? '').toUpperCase()}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
                          color: kWebTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _OrderStatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Order details
                  _InfoRow(
                    theme: theme,
                    label: 'Producto',
                    value: o['product_name'] as String? ?? '-',
                  ),
                  _InfoRow(
                    theme: theme,
                    label: 'Cantidad',
                    value: '${o['quantity'] ?? 1}',
                  ),
                  _InfoRow(
                    theme: theme,
                    label: 'Monto',
                    value: fmtMoney(o['amount']),
                  ),
                  _InfoRow(
                    theme: theme,
                    label: 'Creado',
                    value: fmtDate(o['created_at']),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: kWebCardBorder),
                  const SizedBox(height: 16),

                  // Shipping address
                  Text(
                    'Direccion de Envio',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: kWebTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kWebBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kWebCardBorder),
                    ),
                    child: Text(
                      o['shipping_address'] as String? ??
                          'Sin direccion registrada',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: o['shipping_address'] != null
                            ? kWebTextPrimary
                            : kWebTextHint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tracking number (editable for pending → shipped)
                  if (status == 'pending') ...[
                    Text(
                      'Numero de Rastreo',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: kWebTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _trackingCtrl,
                      decoration: InputDecoration(
                        hintText: 'Ej: 1Z999AA10123456784',
                        hintStyle: theme.textTheme.bodySmall
                            ?.copyWith(color: kWebTextHint),
                        filled: true,
                        fillColor: kWebBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: kWebCardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: kWebCardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: kWebPrimary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: kWebTextPrimary),
                    ),
                    const SizedBox(height: 16),
                  ] else if (o['tracking_number'] != null) ...[
                    _InfoRow(
                        theme: theme,
                        label: 'Tracking',
                        value: o['tracking_number'] as String),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  if (status == 'pending') ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _saving ? null : () => _updateStatus('shipped'),
                        icon: const Icon(Icons.local_shipping_outlined,
                            size: 18),
                        label: const Text('Marcar como Enviado'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kWebTertiary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ] else if (status == 'shipped') ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _updateStatus('completed'),
                        icon: const Icon(Icons.check_circle_outline,
                            size: 18),
                        label: const Text('Marcar como Entregado'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (_saving) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.theme,
    required this.label,
    required this.value,
  });
  final ThemeData theme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextHint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
