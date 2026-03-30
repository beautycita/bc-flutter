import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sort direction enum.
enum SortDir { asc, desc }

/// Generic sort/search/filter/selection state for any admin list.
class AdminDataState<T> {
  final List<T> allItems;
  final String searchQuery;
  final String? sortField;
  final SortDir sortDir;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Set<int> selectedIndices;
  final int page;
  final int pageSize;

  const AdminDataState({
    this.allItems = const [],
    this.searchQuery = '',
    this.sortField,
    this.sortDir = SortDir.desc,
    this.dateFrom,
    this.dateTo,
    this.selectedIndices = const {},
    this.page = 0,
    this.pageSize = 50,
  });

  AdminDataState<T> copyWith({
    List<T>? allItems,
    String? searchQuery,
    String? sortField,
    SortDir? sortDir,
    DateTime? dateFrom,
    DateTime? dateTo,
    Set<int>? selectedIndices,
    int? page,
    int? pageSize,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearSort = false,
  }) {
    return AdminDataState<T>(
      allItems: allItems ?? this.allItems,
      searchQuery: searchQuery ?? this.searchQuery,
      sortField: clearSort ? null : (sortField ?? this.sortField),
      sortDir: sortDir ?? this.sortDir,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      selectedIndices: selectedIndices ?? this.selectedIndices,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  bool get hasSelection => selectedIndices.isNotEmpty;
  int get selectionCount => selectedIndices.length;
  bool get hasDateFilter => dateFrom != null || dateTo != null;
  bool get hasSearch => searchQuery.isNotEmpty;

  List<T> get selectedItems {
    final filtered = this.filtered;
    return selectedIndices
        .where((i) => i < filtered.length)
        .map((i) => filtered[i])
        .toList();
  }

  /// Override in subclass or provide via controller.
  List<T> get filtered => allItems;
}

/// Controller that manages sort/search/filter/selection.
/// Subclass or use directly with type-specific filter/sort functions.
class AdminDataController<T> extends StateNotifier<AdminDataState<T>> {
  final bool Function(T item, String query)? searchFn;
  final Comparable Function(T item, String field)? sortKeyFn;
  final DateTime? Function(T item)? dateExtractFn;

  AdminDataController({
    this.searchFn,
    this.sortKeyFn,
    this.dateExtractFn,
    List<T> initialItems = const [],
  }) : super(AdminDataState<T>(allItems: initialItems));

  void setItems(List<T> items) {
    state = state.copyWith(allItems: items, selectedIndices: {});
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query, page: 0, selectedIndices: {});
  }

  void setSort(String field) {
    if (state.sortField == field) {
      state = state.copyWith(
        sortDir: state.sortDir == SortDir.asc ? SortDir.desc : SortDir.asc,
      );
    } else {
      state = state.copyWith(sortField: field, sortDir: SortDir.desc);
    }
  }

  void clearSort() {
    state = state.copyWith(clearSort: true);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      dateFrom: from,
      dateTo: to,
      clearDateFrom: from == null,
      clearDateTo: to == null,
      page: 0,
      selectedIndices: {},
    );
  }

  void clearDateRange() {
    state = state.copyWith(clearDateFrom: true, clearDateTo: true);
  }

  void toggleSelect(int index) {
    final s = Set<int>.from(state.selectedIndices);
    if (s.contains(index)) {
      s.remove(index);
    } else {
      s.add(index);
    }
    state = state.copyWith(selectedIndices: s);
  }

  void selectAll() {
    final count = filtered.length;
    state = state.copyWith(
      selectedIndices: Set<int>.from(List.generate(count, (i) => i)),
    );
  }

  void clearSelection() {
    state = state.copyWith(selectedIndices: {});
  }

  void nextPage() {
    final maxPage = (filtered.length / state.pageSize).ceil() - 1;
    if (state.page < maxPage) {
      state = state.copyWith(page: state.page + 1);
    }
  }

  void prevPage() {
    if (state.page > 0) {
      state = state.copyWith(page: state.page - 1);
    }
  }

  /// Filtered, sorted, paginated items.
  List<T> get filtered {
    var items = List<T>.from(state.allItems);

    // Search
    if (state.searchQuery.isNotEmpty && searchFn != null) {
      items = items.where((i) => searchFn!(i, state.searchQuery)).toList();
    }

    // Date range
    if (state.hasDateFilter && dateExtractFn != null) {
      items = items.where((i) {
        final d = dateExtractFn!(i);
        if (d == null) return false;
        if (state.dateFrom != null && d.isBefore(state.dateFrom!)) return false;
        if (state.dateTo != null && d.isAfter(state.dateTo!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
    }

    // Sort
    if (state.sortField != null && sortKeyFn != null) {
      items.sort((a, b) {
        final ka = sortKeyFn!(a, state.sortField!);
        final kb = sortKeyFn!(b, state.sortField!);
        return state.sortDir == SortDir.asc
            ? ka.compareTo(kb)
            : kb.compareTo(ka);
      });
    }

    return items;
  }

  /// Current page of filtered items.
  List<T> get paginatedItems {
    final all = filtered;
    final start = state.page * state.pageSize;
    if (start >= all.length) return [];
    final end = (start + state.pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int get totalPages => (filtered.length / state.pageSize).ceil();
}
