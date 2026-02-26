import 'package:flutter/material.dart';

import '../config/breakpoints.dart';
import 'detail_panel.dart';

/// Responsive master-detail layout used by all admin data pages.
///
/// ```
/// Desktop (>1200px):
/// ┌────────────────────────────────┬──────────────┐
/// │  [Filter bar]                  │              │
/// ├────────────────────────────────┤  Detail      │
/// │  [Data table]                  │  Panel       │
/// │  ☐ Row 1    Col2   Col3  ...  │  (selected   │
/// │  ☑ Row 2    Col2   Col3  ...  │  item info)  │
/// │  ☐ Row 3    Col2   Col3  ...  │  400px wide  │
/// ├────────────────────────────────┤              │
/// │  [Bulk action bar] (if items) │              │
/// ├────────────────────────────────┤              │
/// │  [Pagination]                  │              │
/// └────────────────────────────────┴──────────────┘
///
/// Tablet (800–1200px):
///   Detail panel shows as a modal overlay on top of the table.
///
/// Mobile (<800px):
///   Detail panel as full-screen modal. Table as cards instead of rows.
/// ```
class MasterDetailLayout<T> extends StatelessWidget {
  const MasterDetailLayout({
    required this.items,
    required this.isLoading,
    required this.onSelect,
    required this.detailBuilder,
    required this.filterBar,
    required this.table,
    this.selectedItem,
    this.detailTitle,
    this.detailActions = const [],
    this.bulkActionBar,
    this.pagination,
    this.emptyTitle,
    this.emptySubtitle,
    super.key,
  });

  /// Current page of data items.
  final List<T> items;

  /// Whether data is currently loading.
  final bool isLoading;

  /// The item currently selected for the detail panel (null = panel closed).
  final T? selectedItem;

  /// Called when the user selects or deselects an item.
  final ValueChanged<T?> onSelect;

  /// Builds the detail panel content for a selected item.
  final Widget Function(T item) detailBuilder;

  /// Title shown in the detail panel header.
  final String? detailTitle;

  /// Action buttons for the detail panel header.
  final List<Widget> detailActions;

  /// The filter bar widget (search + dropdowns).
  final Widget filterBar;

  /// The data table widget.
  final Widget table;

  /// Optional bulk-action bar shown when items are checked.
  final Widget? bulkActionBar;

  /// Optional pagination bar.
  final Widget? pagination;

  /// Empty-state title (passed through to table if needed).
  final String? emptyTitle;

  /// Empty-state subtitle.
  final String? emptySubtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (WebBreakpoints.isDesktop(width)) {
          return _DesktopLayout<T>(
            selectedItem: selectedItem,
            onSelect: onSelect,
            detailBuilder: detailBuilder,
            detailTitle: detailTitle,
            detailActions: detailActions,
            filterBar: filterBar,
            table: table,
            bulkActionBar: bulkActionBar,
            pagination: pagination,
          );
        }

        // Tablet and mobile: table fills full width, detail is a modal
        return _CompactLayout<T>(
          selectedItem: selectedItem,
          onSelect: onSelect,
          detailBuilder: detailBuilder,
          detailTitle: detailTitle,
          detailActions: detailActions,
          filterBar: filterBar,
          table: table,
          bulkActionBar: bulkActionBar,
          pagination: pagination,
        );
      },
    );
  }
}

// ── Desktop layout ────────────────────────────────────────────────────────────

class _DesktopLayout<T> extends StatelessWidget {
  const _DesktopLayout({
    required this.selectedItem,
    required this.onSelect,
    required this.detailBuilder,
    required this.detailTitle,
    required this.detailActions,
    required this.filterBar,
    required this.table,
    this.bulkActionBar,
    this.pagination,
    super.key,
  });

  final T? selectedItem;
  final ValueChanged<T?> onSelect;
  final Widget Function(T item) detailBuilder;
  final String? detailTitle;
  final List<Widget> detailActions;
  final Widget filterBar;
  final Widget table;
  final Widget? bulkActionBar;
  final Widget? pagination;

  static const double _detailWidth = 400;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasDetail = selectedItem != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Master column ─────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filterBar,
              const Divider(height: 1),
              Expanded(child: table),
              if (bulkActionBar != null) bulkActionBar!,
              if (pagination != null) pagination!,
            ],
          ),
        ),

        // ── Detail panel (slide-in) ───────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: hasDetail ? _detailWidth : 0,
          child: hasDetail
              ? Container(
                  width: _detailWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  child: DetailPanel(
                    title: detailTitle ?? 'Detalle',
                    onClose: () => onSelect(null),
                    actions: detailActions,
                    child: detailBuilder(selectedItem as T),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Compact layout (tablet + mobile) ──────────────────────────────────────────

class _CompactLayout<T> extends StatefulWidget {
  const _CompactLayout({
    required this.selectedItem,
    required this.onSelect,
    required this.detailBuilder,
    required this.detailTitle,
    required this.detailActions,
    required this.filterBar,
    required this.table,
    this.bulkActionBar,
    this.pagination,
    super.key,
  });

  final T? selectedItem;
  final ValueChanged<T?> onSelect;
  final Widget Function(T item) detailBuilder;
  final String? detailTitle;
  final List<Widget> detailActions;
  final Widget filterBar;
  final Widget table;
  final Widget? bulkActionBar;
  final Widget? pagination;

  @override
  State<_CompactLayout<T>> createState() => _CompactLayoutState<T>();
}

class _CompactLayoutState<T> extends State<_CompactLayout<T>> {
  bool _modalOpen = false;

  @override
  void didUpdateWidget(covariant _CompactLayout<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Open modal when an item is newly selected
    if (widget.selectedItem != null && !_modalOpen) {
      _modalOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        DetailPanel.showAsModal(
          context,
          title: widget.detailTitle ?? 'Detalle',
          onClose: () {
            _modalOpen = false;
            widget.onSelect(null);
          },
          actions: widget.detailActions,
          child: widget.detailBuilder(widget.selectedItem as T),
        ).then((_) {
          _modalOpen = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.filterBar,
        const Divider(height: 1),
        Expanded(child: widget.table),
        if (widget.bulkActionBar != null) widget.bulkActionBar!,
        if (widget.pagination != null) widget.pagination!,
      ],
    );
  }
}
