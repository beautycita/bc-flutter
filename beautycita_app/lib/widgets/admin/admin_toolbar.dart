import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:intl/intl.dart';
/// Composable toolbar for admin list screens.
/// Each screen picks which tools it needs via boolean flags.
class AdminToolbar extends StatelessWidget {
  // Search
  final bool showSearch;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final TextEditingController? searchController;

  // Date range
  final bool showDateRange;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final VoidCallback? onDateRangeTap;
  final VoidCallback? onDateRangeClear;

  // Sort
  final bool showSort;
  final String? currentSortField;
  final bool sortAscending;
  final List<SortOption>? sortOptions;
  final ValueChanged<String>? onSortChanged;

  // Export
  final bool showExport;
  final VoidCallback? onExport;

  // Bulk selection
  final bool showBulkSelect;
  final int selectedCount;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final List<BulkAction>? bulkActions;

  // Item count
  final int? totalCount;
  final int? filteredCount;

  const AdminToolbar({
    super.key,
    this.showSearch = false,
    this.searchHint = 'Buscar...',
    this.onSearchChanged,
    this.searchController,
    this.showDateRange = false,
    this.dateFrom,
    this.dateTo,
    this.onDateRangeTap,
    this.onDateRangeClear,
    this.showSort = false,
    this.currentSortField,
    this.sortAscending = false,
    this.sortOptions,
    this.onSortChanged,
    this.showExport = false,
    this.onExport,
    this.showBulkSelect = false,
    this.selectedCount = 0,
    this.onSelectAll,
    this.onClearSelection,
    this.bulkActions,
    this.totalCount,
    this.filteredCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Search + action buttons
        if (showSearch || showExport || showSort)
          Row(
            children: [
              if (showSearch)
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      style: GoogleFonts.nunito(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: searchHint,
                        hintStyle: GoogleFonts.nunito(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                        prefixIcon: Icon(Icons.search, size: 20, color: colors.onSurface.withValues(alpha: 0.4)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
                        ),
                        filled: true,
                        fillColor: colors.surface,
                      ),
                    ),
                  ),
                ),
              if (showSort && sortOptions != null) ...[
                const SizedBox(width: 8),
                _SortButton(
                  currentField: currentSortField,
                  ascending: sortAscending,
                  options: sortOptions!,
                  onChanged: onSortChanged,
                ),
              ],
              if (showExport) ...[
                const SizedBox(width: 8),
                _IconBtn(
                  icon: Icons.download_rounded,
                  tooltip: 'Exportar CSV',
                  onTap: onExport,
                ),
              ],
            ],
          ),

        // Row 2: Date range + count
        if (showDateRange || totalCount != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (showDateRange) ...[
                _DateRangeChip(
                  from: dateFrom,
                  to: dateTo,
                  onTap: onDateRangeTap,
                  onClear: onDateRangeClear,
                ),
                const SizedBox(width: 8),
              ],
              if (totalCount != null)
                Text(
                  filteredCount != null && filteredCount != totalCount
                      ? '$filteredCount de $totalCount'
                      : '$totalCount registros',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ],

        // Row 3: Bulk action bar
        if (showBulkSelect && selectedCount > 0) ...[
          const SizedBox(height: 8),
          _BulkActionBar(
            count: selectedCount,
            actions: bulkActions ?? [],
            onSelectAll: onSelectAll,
            onClear: onClearSelection,
          ),
        ],

        const SizedBox(height: 8),
      ],
    );
  }
}

/// Sort option definition.
class SortOption {
  final String field;
  final String label;
  const SortOption(this.field, this.label);
}

/// Bulk action definition.
class BulkAction {
  final String label;
  final IconData icon;
  final VoidCallback onExecute;
  final Color? color;
  const BulkAction(this.label, this.icon, this.onExecute, {this.color});
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _IconBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String? currentField;
  final bool ascending;
  final List<SortOption> options;
  final ValueChanged<String>? onChanged;

  const _SortButton({
    this.currentField,
    this.ascending = false,
    required this.options,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isActive = currentField != null;

    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => options.map((o) => PopupMenuItem(
        value: o.field,
        child: Row(
          children: [
            if (o.field == currentField)
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: colors.primary,
              ),
            if (o.field == currentField) const SizedBox(width: 6),
            Text(o.label, style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: o.field == currentField ? FontWeight.w700 : FontWeight.w400,
            )),
          ],
        ),
      )).toList(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? colors.primary.withValues(alpha: 0.1) : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? colors.primary.withValues(alpha: 0.3) : colors.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          Icons.sort_rounded,
          size: 20,
          color: isActive ? colors.primary : colors.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _DateRangeChip({this.from, this.to, this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasFilter = from != null || to != null;
    final fmt = DateFormat('dd/MM');

    String label = 'Fechas';
    if (from != null && to != null) {
      label = '${fmt.format(from!)} - ${fmt.format(to!)}';
    } else if (from != null) {
      label = 'Desde ${fmt.format(from!)}';
    } else if (to != null) {
      label = 'Hasta ${fmt.format(to!)}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasFilter ? colors.primary.withValues(alpha: 0.1) : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFilter ? colors.primary.withValues(alpha: 0.3) : colors.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14,
                color: hasFilter ? colors.primary : colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: hasFilter ? FontWeight.w700 : FontWeight.w500,
              color: hasFilter ? colors.primary : colors.onSurface.withValues(alpha: 0.6),
            )),
            if (hasFilter && onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: colors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  final int count;
  final List<BulkAction> actions;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClear;

  const _BulkActionBar({
    required this.count,
    required this.actions,
    this.onSelectAll,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(
            '$count seleccionado${count > 1 ? 's' : ''}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSelectAll,
            child: Text('Todos', style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.primary,
              decoration: TextDecoration.underline,
            )),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: Text('Limpiar', style: GoogleFonts.nunito(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.5),
            )),
          ),
          const Spacer(),
          ...actions.map((a) => Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _BulkBtn(action: a),
          )),
        ],
      ),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  final BulkAction action;
  const _BulkBtn({required this.action});

  @override
  Widget build(BuildContext context) {
    final c = action.color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        action.onExecute();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 16, color: c),
            const SizedBox(width: 4),
            Text(action.label, style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c,
            )),
          ],
        ),
      ),
    );
  }
}

/// Helper to show a date range picker dialog.
Future<DateTimeRange?> showAdminDateRangePicker(BuildContext context, {DateTime? initialFrom, DateTime? initialTo}) {
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2025),
    lastDate: DateTime.now().add(const Duration(days: 30)),
    initialDateRange: initialFrom != null && initialTo != null
        ? DateTimeRange(start: initialFrom, end: initialTo)
        : null,
    locale: const Locale('es', 'MX'),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme,
        ),
        child: child!,
      );
    },
  );
}
