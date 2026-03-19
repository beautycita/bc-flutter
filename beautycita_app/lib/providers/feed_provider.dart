import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beautycita_core/models.dart' hide Provider;
import 'package:beautycita/services/feed_service.dart';

/// Singleton FeedService instance.
final feedServiceProvider = Provider<FeedService>((ref) => FeedService());

/// Current category filter. null means "all categories".
final feedCategoryProvider = StateProvider<String?>((ref) => null);

/// Single-page feed fetch, auto-disposed when no longer watched.
/// Automatically re-fetches when the category filter changes.
final feedProvider = FutureProvider.autoDispose<List<FeedItem>>((ref) {
  final service = ref.read(feedServiceProvider);
  final category = ref.watch(feedCategoryProvider);
  return service.fetchFeed(page: 0, category: category);
});

/// Saved feed items for the current user, auto-disposed.
final savedItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.read(feedServiceProvider);
  return service.fetchSaved();
});

// ---------------------------------------------------------------------------
// Paginated feed — use this for the infinite-scroll feed screen.
// ---------------------------------------------------------------------------

/// Manages paginated loading of feed items with support for infinite scroll.
///
/// Usage:
///   final notifier = ref.read(feedPaginationProvider.notifier);
///   await notifier.loadInitial();          // called once on screen init
///   await notifier.loadMore();             // called when list nears the bottom
///   notifier.updateSaveStatus(id, true, 1); // optimistic save toggle
class FeedPaginationNotifier extends ChangeNotifier {
  final FeedService _service;

  final List<FeedItem> _items = [];
  String? _category;
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;

  FeedPaginationNotifier(this._service);

  List<FeedItem> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get hasMore => _hasMore;

  /// Reset and load the first page. Call this on screen init or filter change.
  Future<void> loadInitial({String? category}) async {
    _category = category;
    _page = 0;
    _items.clear();
    _hasMore = true;
    notifyListeners();
    await _loadPage();
  }

  /// Append the next page. Safe to call concurrently — extra calls are no-ops.
  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    await _loadPage();
  }

  Future<void> _loadPage() async {
    _loading = true;
    notifyListeners();
    try {
      final newItems =
          await _service.fetchFeed(page: _page, category: _category);
      _items.addAll(newItems);
      // A full page means there may be more; a short page signals the end.
      _hasMore = newItems.length >= 20;
      _page++;
    } catch (e) {
      if (kDebugMode) debugPrint('[FeedPagination] _loadPage: $e');
    }
    _loading = false;
    notifyListeners();
  }

  /// Notify listeners after a save toggle so the UI can refresh save state.
  ///
  /// Because [FeedItem] is immutable, the widget reading [items] is responsible
  /// for tracking the toggled [itemId] locally for optimistic display.
  /// This call simply triggers a rebuild so any derived state is refreshed.
  void updateSaveStatus(String itemId, bool isSaved, int saveCountDelta) {
    notifyListeners();
  }
}

final feedPaginationProvider =
    ChangeNotifierProvider.autoDispose<FeedPaginationNotifier>((ref) {
  final service = ref.read(feedServiceProvider);
  return FeedPaginationNotifier(service);
});
