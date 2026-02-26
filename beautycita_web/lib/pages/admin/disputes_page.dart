import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_disputes_provider.dart';
import '../../widgets/bc_data_table.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/master_detail_layout.dart';
import 'dispute_detail_panel.dart';

/// Admin disputes page — master-detail table layout.
///
/// Table columns: ID, Client, Salon, Booking ref, Type (chip), Amount, Status (chip), Filed date
/// Filters: Status dropdown, Type dropdown, date range
/// Detail: dispute info, resolution workflow, timeline
class DisputesPage extends ConsumerStatefulWidget {
  const DisputesPage({super.key});

  @override
  ConsumerState<DisputesPage> createState() => _DisputesPageState();
}

class _DisputesPageState extends ConsumerState<DisputesPage> {
  Set<Dispute> _checkedItems = {};
  String? _sortColumn;
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final disputesAsync = ref.watch(disputesProvider);
    final filters = ref.watch(disputeFiltersProvider);
    final selectedDispute = ref.watch(selectedDisputeProvider);

    final disputes = disputesAsync.valueOrNull ?? [];
    final isLoading = disputesAsync.isLoading;

    return MasterDetailLayout<Dispute>(
      items: disputes,
      isLoading: isLoading,
      selectedItem: selectedDispute,
      onSelect: (d) =>
          ref.read(selectedDisputeProvider.notifier).state = d,
      detailTitle: selectedDispute != null
          ? 'Disputa #${selectedDispute.id.substring(0, 8)}'
          : 'Detalle',
      detailBuilder: (dispute) => DisputeDetailContent(dispute: dispute),
      filterBar: _DisputeFilterBar(filters: filters, ref: ref),
      table: BCDataTable<Dispute>(
        columns: _buildColumns(context),
        items: disputes,
        selectedItems: _checkedItems,
        onRowTap: (d) =>
            ref.read(selectedDisputeProvider.notifier).state = d,
        onSelectionChanged: (s) => setState(() => _checkedItems = s),
        onSort: (col) {
          setState(() {
            if (_sortColumn == col) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumn = col;
              _sortAscending = true;
            }
          });
        },
        sortColumn: _sortColumn,
        sortAscending: _sortAscending,
        selectedItem: selectedDispute,
        emptyIcon: Icons.gavel_outlined,
        emptyTitle: 'Sin disputas',
        emptySubtitle: 'No hay disputas que coincidan con los filtros',
      ),
    );
  }

  List<BCColumn<Dispute>> _buildColumns(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('d/MM/yy', 'es');

    return [
      BCColumn<Dispute>(
        id: 'id',
        label: 'ID',
        width: 90,
        sortable: true,
        cellBuilder: (d) => Text(
          '#${d.id.substring(0, 8)}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      BCColumn<Dispute>(
        id: 'client',
        label: 'Cliente',
        sortable: true,
        cellBuilder: (d) => Text(
          d.clientName,
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      BCColumn<Dispute>(
        id: 'salon',
        label: 'Salon',
        sortable: true,
        cellBuilder: (d) => Text(
          d.salonName,
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      BCColumn<Dispute>(
        id: 'booking',
        label: 'Reserva',
        width: 90,
        cellBuilder: (d) => Text(
          d.bookingRef != null ? '#${d.bookingRef!.substring(0, 8)}' : '-',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      BCColumn<Dispute>(
        id: 'type',
        label: 'Tipo',
        width: 100,
        sortable: true,
        cellBuilder: (d) => _TypeChip(type: d.type, label: d.typeLabel),
      ),
      BCColumn<Dispute>(
        id: 'amount',
        label: 'Monto',
        width: 100,
        sortable: true,
        cellBuilder: (d) => Text(
          '\$${d.amount.toStringAsFixed(0)}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      BCColumn<Dispute>(
        id: 'status',
        label: 'Estado',
        width: 110,
        sortable: true,
        cellBuilder: (d) => _StatusChipSmall(
          status: d.status,
          label: d.statusLabel,
        ),
      ),
      BCColumn<Dispute>(
        id: 'filed',
        label: 'Fecha',
        width: 80,
        sortable: true,
        cellBuilder: (d) => Text(
          dateFmt.format(d.filedAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    ];
  }
}

// ── Filter bar ───────────────────────────────────────────────────────────────

class _DisputeFilterBar extends StatelessWidget {
  const _DisputeFilterBar({required this.filters, required this.ref});
  final DisputeFilters filters;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterBar(
      searchField: SizedBox(
        height: 36,
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar disputas...',
            prefixIcon: const Icon(Icons.search, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            isDense: true,
          ),
          style: theme.textTheme.bodySmall,
          onChanged: (q) {
            ref.read(disputeFiltersProvider.notifier).state =
                filters.copyWith(searchQuery: q);
          },
        ),
      ),
      filters: [
        // Status dropdown
        SizedBox(
          width: 150,
          height: 36,
          child: DropdownButtonFormField<String>(
            initialValue: filters.status,
            decoration: InputDecoration(
              labelText: 'Estado',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            style: theme.textTheme.bodySmall,
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos')),
              DropdownMenuItem(value: 'open', child: Text('Abierta')),
              DropdownMenuItem(
                  value: 'reviewing', child: Text('En revision')),
              DropdownMenuItem(value: 'resolved', child: Text('Resuelta')),
              DropdownMenuItem(value: 'rejected', child: Text('Rechazada')),
            ],
            onChanged: (v) {
              ref.read(disputeFiltersProvider.notifier).state =
                  filters.copyWith(status: () => v);
            },
          ),
        ),
        // Type dropdown
        SizedBox(
          width: 150,
          height: 36,
          child: DropdownButtonFormField<String>(
            initialValue: filters.type,
            decoration: InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            style: theme.textTheme.bodySmall,
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos')),
              DropdownMenuItem(
                  value: 'service_quality', child: Text('Calidad')),
              DropdownMenuItem(value: 'no_show', child: Text('No show')),
              DropdownMenuItem(
                  value: 'overcharge', child: Text('Cobro excesivo')),
              DropdownMenuItem(value: 'other', child: Text('Otro')),
            ],
            onChanged: (v) {
              ref.read(disputeFiltersProvider.notifier).state =
                  filters.copyWith(type: () => v);
            },
          ),
        ),
      ],
      onClearAll: filters.hasActiveFilters
          ? () => ref.read(disputeFiltersProvider.notifier).state =
              DisputeFilters.empty
          : null,
    );
  }
}

// ── Inline chips ─────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.label});
  final String type;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (type) {
      'service_quality' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'no_show' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'overcharge' => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _ => (Colors.grey.shade100, Colors.grey.shade700),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusChipSmall extends StatelessWidget {
  const _StatusChipSmall({required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'open' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'reviewing' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'resolved' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'rejected' => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _ => (Colors.grey.shade100, Colors.grey.shade700),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
