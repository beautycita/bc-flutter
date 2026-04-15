import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/favorites_repository.dart';

final favoritesRepositoryProvider = Provider((ref) => FavoritesRepository());

/// Set of business IDs the current user has favorited.
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  final repo = ref.watch(favoritesRepositoryProvider);
  return FavoritesNotifier(repo);
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final FavoritesRepository _repo;

  FavoritesNotifier(this._repo) : super({}) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = await _repo.getFavoriteBusinessIds();
    } catch (e) {
      // User may not be authenticated yet
      debugPrint('[FavoritesNotifier._load] error: $e');
    }
  }

  bool isFavorite(String businessId) => state.contains(businessId);

  Future<void> toggle(String businessId) async {
    if (state.contains(businessId)) {
      // Optimistic remove
      state = Set.from(state)..remove(businessId);
      try {
        await _repo.removeFavorite(businessId);
      } catch (e) {
        debugPrint('[FavoritesNotifier.toggle] remove error: $e');
        // Revert on error
        state = Set.from(state)..add(businessId);
      }
    } else {
      // Optimistic add
      state = Set.from(state)..add(businessId);
      try {
        await _repo.addFavorite(businessId);
      } catch (e) {
        debugPrint('[FavoritesNotifier.toggle] add error: $e');
        // Revert on error
        state = Set.from(state)..remove(businessId);
      }
    }
  }
}
