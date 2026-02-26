import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';

import 'empty_state.dart';
import 'loading_skeleton.dart';

/// Column definition for [BCDataTable].
class BCColumn<T> {
  const BCColumn({
    required this.id,
    required this.label,
    required this.cellBuilder,
    this.width,
    this.sortable = false,
  });

  /// Unique identifier used for sorting callbacks.
  final String id;

  /// Header label text.
  final String label;

  /// Optional fixed width. If null, the column flexes.
  final double? width;

  /// Whether clicking this header triggers sorting.
  final bool sortable;

  /// Builds the cell widget for a given row item.
  final Widget Function(T item) cellBuilder;
}

/// Themed, sortable data table with checkbox selection, hover highlights,
/// alternating row colours, loading skeletons, and empty state.
///
/// Generic over [T] — the row data type.
class BCDataTable<T> extends StatelessWidget {
  const BCDataTable({
    required this.columns,
    required this.items,
    required this.onRowTap,
    required this.onSelectionChanged,
    required this.onSort,
    this.selectedItems = const {},
    this.isLoading = false,
    this.sortColumn,
    this.sortAscending = true,
    this.selectedItem,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Sin datos',
    this.emptySubtitle,
    super.key,
  });

  /// Column definitions.
  final List<BCColumn<T>> columns;

  /// Current page of items to display.
  final List<T> items;

  /// Items with a checked checkbox.
  final Set<T> selectedItems;

  /// Fired when a row is tapped (selects for detail panel).
  final ValueChanged<T> onRowTap;

  /// Fired when checkbox selection changes.
  final ValueChanged<Set<T>> onSelectionChanged;

  /// True while data is being fetched — shows skeleton rows.
  final bool isLoading;

  /// Currently sorted column id (null if unsorted).
  final String? sortColumn;

  /// Sort direction.
  final bool sortAscending;

  /// Fired when a sortable column header is tapped.
  final ValueChanged<String> onSort;

  /// The item currently shown in the detail panel (highlighted row).
  final T? selectedItem;

  /// Icon for the empty-state display.
  final IconData emptyIcon;

  /// Title for the empty-state display.
  final String emptyTitle;

  /// Subtitle for the empty-state display.
  final String? emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return TableLoadingSkeleton(
        rows: 8,
        columns: columns.length,
      );
    }

    if (items.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allSelected =
        items.isNotEmpty && selectedItems.length == items.length;

    return Column(
      children: [
        // ── Header row ─────────────────────────────────────────────────
        _HeaderRow<T>(
          columns: columns,
          allSelected: allSelected,
          sortColumn: sortColumn,
          sortAscending: sortAscending,
          onSort: onSort,
          onSelectAll: (selected) {
            if (selected) {
              onSelectionChanged(items.toSet());
            } else {
              onSelectionChanged({});
            }
          },
        ),
        const Divider(height: 1),

        // ── Data rows ──────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isChecked = selectedItems.contains(item);
              final isHighlighted = item == selectedItem;

              return _DataRow<T>(
                item: item,
                columns: columns,
                isChecked: isChecked,
                isHighlighted: isHighlighted,
                isEven: index.isEven,
                onTap: () => onRowTap(item),
                onCheckChanged: (checked) {
                  final updated = Set<T>.from(selectedItems);
                  if (checked) {
                    updated.add(item);
                  } else {
                    updated.remove(item);
                  }
                  onSelectionChanged(updated);
                },
                colors: colors,
                theme: theme,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Header row ────────────────────────────────────────────────────────────────

class _HeaderRow<T> extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.allSelected,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onSelectAll,
    super.key,
  });

  final List<BCColumn<T>> columns;
  final bool allSelected;
  final String? sortColumn;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final ValueChanged<bool> onSelectAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.md,
        vertical: BCSpacing.sm,
      ),
      color: colors.surface,
      child: Row(
        children: [
          // Select-all checkbox
          SizedBox(
            width: 40,
            child: Checkbox(
              value: allSelected,
              onChanged: (v) => onSelectAll(v ?? false),
              activeColor: colors.primary,
            ),
          ),

          // Column headers
          for (final col in columns)
            Expanded(
              flex: col.width != null ? 0 : 1,
              child: SizedBox(
                width: col.width,
                child: _HeaderCell(
                  column: col,
                  isSorted: sortColumn == col.id,
                  ascending: sortAscending,
                  onSort: col.sortable ? () => onSort(col.id) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell<T> extends StatefulWidget {
  const _HeaderCell({
    required this.column,
    required this.isSorted,
    required this.ascending,
    this.onSort,
    super.key,
  });

  final BCColumn<T> column;
  final bool isSorted;
  final bool ascending;
  final VoidCallback? onSort;

  @override
  State<_HeaderCell<T>> createState() => _HeaderCellState<T>();
}

class _HeaderCellState<T> extends State<_HeaderCell<T>> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sortable = widget.onSort != null;

    return MouseRegion(
      onEnter: sortable ? (_) => setState(() => _hovering = true) : null,
      onExit: sortable ? (_) => setState(() => _hovering = false) : null,
      cursor: sortable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onSort,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BCSpacing.sm,
            vertical: BCSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.column.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: widget.isSorted
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sortable && (widget.isSorted || _hovering)) ...[
                const SizedBox(width: 2),
                Icon(
                  widget.isSorted
                      ? (widget.ascending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
                      : Icons.unfold_more,
                  size: 14,
                  color: widget.isSorted
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data row ──────────────────────────────────────────────────────────────────

class _DataRow<T> extends StatefulWidget {
  const _DataRow({
    required this.item,
    required this.columns,
    required this.isChecked,
    required this.isHighlighted,
    required this.isEven,
    required this.onTap,
    required this.onCheckChanged,
    required this.colors,
    required this.theme,
    super.key,
  });

  final T item;
  final List<BCColumn<T>> columns;
  final bool isChecked;
  final bool isHighlighted;
  final bool isEven;
  final VoidCallback onTap;
  final ValueChanged<bool> onCheckChanged;
  final ColorScheme colors;
  final ThemeData theme;

  @override
  State<_DataRow<T>> createState() => _DataRowState<T>();
}

class _DataRowState<T> extends State<_DataRow<T>> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (widget.isHighlighted) {
      bgColor = widget.colors.primary.withValues(alpha: 0.08);
    } else if (_hovering) {
      bgColor = widget.colors.primary.withValues(alpha: 0.04);
    } else if (widget.isChecked) {
      bgColor = widget.colors.primary.withValues(alpha: 0.06);
    } else if (widget.isEven) {
      bgColor = widget.colors.onSurface.withValues(alpha: 0.02);
    } else {
      bgColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BCSpacing.md,
            vertical: BCSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(
                color: widget.colors.outlineVariant.withValues(alpha: 0.5),
              ),
              left: widget.isHighlighted
                  ? BorderSide(
                      color: widget.colors.primary,
                      width: 3,
                    )
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: widget.isChecked,
                  onChanged: (v) => widget.onCheckChanged(v ?? false),
                  activeColor: widget.colors.primary,
                ),
              ),

              // Cells
              for (final col in widget.columns)
                Expanded(
                  flex: col.width != null ? 0 : 1,
                  child: SizedBox(
                    width: col.width,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: BCSpacing.sm),
                      child: col.cellBuilder(widget.item),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
