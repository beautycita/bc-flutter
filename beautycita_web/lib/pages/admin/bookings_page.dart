import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_bookings_provider.dart';
import '../../widgets/bc_data_table.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/master_detail_layout.dart';
import '../../widgets/pagination_bar.dart';
import 'booking_detail_panel.dart';

/// Admin bookings management page with master-detail layout.
class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  AdminBooking? _selectedBooking;
  Set<AdminBooking> _checkedBookings = {};
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final filter = ref.read(bookingsFilterProvider);
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: filter.dateFrom != null && filter.dateTo != null
          ? DateTimeRange(start: filter.dateFrom!, end: filter.dateTo!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            ),
      locale: const Locale('es'),
    );

    if (picked != null) {
      ref.read(bookingsFilterProvider.notifier).state = filter.copyWith(
        dateFrom: () => picked.start,
        dateTo: () => picked.end,
        page: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filter = ref.watch(bookingsFilterProvider);
    final bookingsAsync = ref.watch(adminBookingsProvider);
    final dateFormat = DateFormat('d MMM yy', 'es');
    final timeFormat = DateFormat('HH:mm', 'es');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );

    // Surface errors
    if (bookingsAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48,
                  color: colors.error.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('Error cargando reservas',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(
                '${bookingsAsync.error}',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(adminBookingsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final items = bookingsAsync.valueOrNull?.bookings ?? [];
    final totalCount = bookingsAsync.valueOrNull?.totalCount ?? 0;
    final isLoading = bookingsAsync.isLoading;
    final totalPages = (totalCount / filter.pageSize).ceil();

    return MasterDetailLayout<AdminBooking>(
      items: items,
      isLoading: isLoading,
      selectedItem: _selectedBooking,
      onSelect: (booking) =>
          setState(() => _selectedBooking = booking),
      detailTitle: _selectedBooking != null
          ? 'Reserva #${_selectedBooking!.shortId}'
          : 'Reserva',
      detailBuilder: (booking) =>
          BookingDetailContent(booking: booking),
      filterBar: FilterBar(
        searchField: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar servicio, cliente...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.sm,
              vertical: BCSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(BCSpacing.radiusXs),
            ),
            suffixIcon: filter.searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      ref
                          .read(bookingsFilterProvider.notifier)
                          .state = filter.copyWith(
                        searchText: '',
                        page: 0,
                      );
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            ref.read(bookingsFilterProvider.notifier).state =
                filter.copyWith(searchText: value, page: 0);
          },
        ),
        filters: [
          // Status filter
          _BookingFilterDropdown(
            value: filter.status,
            hint: 'Estado',
            items: const {
              null: 'Todos',
              'pending': 'Pendiente',
              'confirmed': 'Confirmada',
              'completed': 'Completada',
              'cancelled': 'Cancelada',
              'no_show': 'No asistio',
            },
            onChanged: (value) {
              ref.read(bookingsFilterProvider.notifier).state =
                  filter.copyWith(status: () => value, page: 0);
            },
          ),
          // Date range button
          OutlinedButton.icon(
            onPressed: () => _pickDateRange(context),
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(
              filter.dateFrom != null && filter.dateTo != null
                  ? '${dateFormat.format(filter.dateFrom!)} - ${dateFormat.format(filter.dateTo!)}'
                  : 'Rango de fechas',
              style: theme.textTheme.bodySmall,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: BCSpacing.sm,
                vertical: BCSpacing.xs,
              ),
              side: BorderSide(
                color: filter.dateFrom != null
                    ? colors.primary
                    : colors.outlineVariant,
              ),
            ),
          ),
        ],
        onClearAll: filter.hasActiveFilters
            ? () {
                _searchController.clear();
                ref.read(bookingsFilterProvider.notifier).state =
                    const BookingsFilter();
              }
            : null,
      ),
      table: BCDataTable<AdminBooking>(
        columns: [
          BCColumn<AdminBooking>(
            id: 'id',
            label: 'ID',
            width: 80,
            cellBuilder: (booking) => Text(
              booking.shortId,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 1,
            ),
          ),
          BCColumn<AdminBooking>(
            id: 'client',
            label: 'Cliente',
            cellBuilder: (booking) => Text(
              booking.clientName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BCColumn<AdminBooking>(
            id: 'salon',
            label: 'Salon',
            cellBuilder: (booking) => Text(
              booking.salonName,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BCColumn<AdminBooking>(
            id: 'service_name',
            label: 'Servicio',
            sortable: true,
            cellBuilder: (booking) => Text(
              booking.service,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BCColumn<AdminBooking>(
            id: 'starts_at',
            label: 'Fecha/Hora',
            sortable: true,
            width: 130,
            cellBuilder: (booking) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dateFormat.format(booking.dateTime),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                ),
                Text(
                  timeFormat.format(booking.dateTime),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          BCColumn<AdminBooking>(
            id: 'status',
            label: 'Estado',
            sortable: true,
            width: 110,
            cellBuilder: (booking) => _BookingStatusChip(
              status: booking.status,
            ),
          ),
          BCColumn<AdminBooking>(
            id: 'amount',
            label: 'Monto',
            sortable: true,
            width: 90,
            cellBuilder: (booking) => Text(
              currencyFormat.format(booking.amount),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          BCColumn<AdminBooking>(
            id: 'payment_status',
            label: 'Pago',
            width: 90,
            cellBuilder: (booking) => _PaymentChip(
              status: booking.paymentStatus,
            ),
          ),
        ],
        items: items,
        selectedItems: _checkedBookings,
        selectedItem: _selectedBooking,
        isLoading: isLoading,
        sortColumn: filter.sortColumn,
        sortAscending: filter.sortAscending,
        onRowTap: (booking) =>
            setState(() => _selectedBooking = booking),
        onSelectionChanged: (selected) =>
            setState(() => _checkedBookings = selected),
        onSort: (column) {
          final ascending =
              filter.sortColumn == column ? !filter.sortAscending : true;
          ref.read(bookingsFilterProvider.notifier).state =
              filter.copyWith(
            sortColumn: () => column,
            sortAscending: ascending,
          );
        },
        emptyIcon: Icons.calendar_month_outlined,
        emptyTitle: 'No hay reservas',
        emptySubtitle: filter.hasActiveFilters
            ? 'Intenta con otros filtros'
            : null,
      ),
      bulkActionBar: _checkedBookings.isNotEmpty
          ? BulkActionBar(
              selectedCount: _checkedBookings.length,
              onClearSelection: () =>
                  setState(() => _checkedBookings = {}),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    // TODO: Export selected bookings
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Exportar'),
                ),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Bulk cancel
                  },
                  icon: Icon(Icons.cancel, size: 18,
                      color: colors.error),
                  label: Text(
                    'Cancelar',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
            )
          : null,
      pagination: totalPages > 1
          ? PaginationBar(
              currentPage: filter.page,
              totalPages: totalPages,
              totalItems: totalCount,
              pageSize: filter.pageSize,
              onPageChanged: (page) {
                ref.read(bookingsFilterProvider.notifier).state =
                    filter.copyWith(page: page);
              },
              onPageSizeChanged: (size) {
                ref.read(bookingsFilterProvider.notifier).state =
                    filter.copyWith(pageSize: size, page: 0);
              },
            )
          : null,
    );
  }
}

// ── Chip widgets ──────────────────────────────────────────────────────────────

class _BookingStatusChip extends StatelessWidget {
  const _BookingStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('Pendiente', Colors.orange),
      'confirmed' => ('Confirmada', Colors.blue),
      'completed' => ('Completada', Colors.green),
      'cancelled' => ('Cancelada', Colors.red),
      'no_show' => ('No asistio', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'paid' => ('Pagado', Colors.green),
      'pending' => ('Pendiente', Colors.orange),
      'refunded' => ('Reembolso', Colors.blue),
      'failed' => ('Fallido', Colors.red),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Filter dropdown ───────────────────────────────────────────────────────────

class _BookingFilterDropdown extends StatelessWidget {
  const _BookingFilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final Map<String?, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BCSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          hint: Text(hint, style: theme.textTheme.bodySmall),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
          ),
          items: items.entries
              .map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v),
        ),
      ),
    );
  }
}
