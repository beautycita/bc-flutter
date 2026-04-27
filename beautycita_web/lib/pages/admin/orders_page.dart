// =============================================================================
// Admin Orders page — POS order list with new POS-completion-v2 columns
// =============================================================================
// Surfaces every order across the platform with status filters (including
// awaiting_pickup + completed), fulfillment method, claim window remaining,
// and refund_reason. Read-only — admin actions go through the salon-cancel
// or process-dispute paths.
// =============================================================================

import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/web_theme.dart';
import '../../widgets/web_design_system.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});
  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String _statusFilter = 'all';
  String _fulfillmentFilter = 'all';
  String _search = '';

  static const _statuses = <String, String>{
    'all': 'Todos',
    'paid': 'Pagado (espera envio)',
    'awaiting_pickup': 'Esperando recoleccion',
    'shipped': 'Enviado',
    'delivered': 'Entregado',
    'completed': 'Finalizado',
    'refunded': 'Reembolsado',
    'cancelled': 'Cancelado',
  };

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.amber.shade700;
      case 'awaiting_pickup':
        return Colors.purple.shade600;
      case 'shipped':
        return Colors.blue.shade600;
      case 'delivered':
        return Colors.teal.shade600;
      case 'completed':
        return Colors.green.shade700;
      case 'refunded':
        return Colors.red.shade600;
      case 'cancelled':
        return Colors.grey.shade600;
      default:
        return Colors.grey;
    }
  }

  String _fmtClaimWindow(String? endsAt) {
    if (endsAt == null) return '—';
    final dt = DateTime.tryParse(endsAt)?.toUtc();
    if (dt == null) return '—';
    final now = DateTime.now().toUtc();
    final delta = dt.difference(now);
    if (delta.isNegative) return 'Cerrada';
    final days = delta.inDays;
    final hours = delta.inHours.remainder(24);
    return days > 0 ? '$days d ${hours}h' : '${delta.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWebBackground,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: StaggeredFadeIn(
          spacing: 16,
          children: [
            const _HeaderRow(),
            _FilterBar(
              status: _statusFilter,
              fulfillment: _fulfillmentFilter,
              search: _search,
              statuses: _statuses,
              onStatus: (v) => setState(() => _statusFilter = v),
              onFulfillment: (v) => setState(() => _fulfillmentFilter = v),
              onSearch: (v) => setState(() => _search = v),
            ),
            Expanded(
              child: Consumer(
                builder: (ctx, ref, _) {
                  final asyncRows = ref.watch(_ordersProvider((
                    status: _statusFilter,
                    fulfillment: _fulfillmentFilter,
                    search: _search,
                  )));
                  return asyncRows.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (rows) => rows.isEmpty
                        ? const Center(child: Text('Sin pedidos para los filtros aplicados'))
                        : _OrdersTable(
                            rows: rows,
                            statusColor: _statusColor,
                            statusLabels: _statuses,
                            fmtClaimWindow: _fmtClaimWindow,
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
}

typedef _Filters = ({String status, String fulfillment, String search});

final _ordersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _Filters>((ref, filters) async {
  if (!BCSupabase.isInitialized) return [];
  var q = BCSupabase.client.from('orders').select(
    'id, buyer_id, business_id, product_name, quantity, total_amount, '
    'commission_amount, status, fulfillment_method, tracking_number, '
    'shipped_at, picked_up_at, claim_window_ends_at, completed_at, '
    'refund_reason, refunded_at, created_at',
  );
  if (filters.status != 'all') {
    q = q.eq('status', filters.status);
  }
  if (filters.fulfillment != 'all') {
    q = q.eq('fulfillment_method', filters.fulfillment);
  }
  if (filters.search.trim().isNotEmpty) {
    q = q.ilike('product_name', '%${filters.search.trim()}%');
  }
  final rows = await q.order('created_at', ascending: false).limit(500);
  return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
});

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.shopping_bag_outlined, size: 24, color: kWebPrimary),
        SizedBox(width: 12),
        Text('Pedidos POS',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kWebTextPrimary)),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String status;
  final String fulfillment;
  final String search;
  final Map<String, String> statuses;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onFulfillment;
  final ValueChanged<String> onSearch;

  const _FilterBar({
    required this.status,
    required this.fulfillment,
    required this.search,
    required this.statuses,
    required this.onStatus,
    required this.onFulfillment,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String>(
            value: status,
            onChanged: (v) => v != null ? onStatus(v) : null,
            items: statuses.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
          ),
          DropdownButton<String>(
            value: fulfillment,
            onChanged: (v) => v != null ? onFulfillment(v) : null,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Cumplimiento: todo')),
              DropdownMenuItem(value: 'ship', child: Text('Envio')),
              DropdownMenuItem(value: 'pickup', child: Text('Recoleccion')),
            ],
          ),
          SizedBox(
            width: 280,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Buscar producto…',
                prefixIcon: Icon(Icons.search, size: 18),
                border: OutlineInputBorder(),
              ),
              onChanged: onSearch,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Color Function(String) statusColor;
  final Map<String, String> statusLabels;
  final String Function(String?) fmtClaimWindow;

  const _OrdersTable({
    required this.rows,
    required this.statusColor,
    required this.statusLabels,
    required this.fmtClaimWindow,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy HH:mm', 'es');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Producto')),
              DataColumn(label: Text('Estado')),
              DataColumn(label: Text('Cumplim.')),
              DataColumn(label: Text('Total'), numeric: true),
              DataColumn(label: Text('Comision'), numeric: true),
              DataColumn(label: Text('Reclamo')),
              DataColumn(label: Text('Motivo refund')),
              DataColumn(label: Text('Creado')),
            ],
            rows: rows.map((r) {
              final s = r['status'] as String? ?? '';
              return DataRow(cells: [
                DataCell(Text(r['product_name'] as String? ?? '—')),
                DataCell(_StatusChip(label: statusLabels[s] ?? s, color: statusColor(s))),
                DataCell(Text(r['fulfillment_method'] == 'pickup' ? 'Recolección' : 'Envío')),
                DataCell(Text('\$${(r['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
                DataCell(Text('\$${(r['commission_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
                DataCell(Text(fmtClaimWindow(r['claim_window_ends_at'] as String?))),
                DataCell(Text((r['refund_reason'] as String?) ?? '—')),
                DataCell(Text(df.format(DateTime.parse(r['created_at'] as String).toLocal()))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
