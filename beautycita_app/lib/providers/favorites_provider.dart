import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/repositories/favorites_repository.dart';
import 'package:beautycita/services/toast_service.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository();
});

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  final repository = ref.watch(favoritesRepositoryProvider);
  return FavoritesNotifier(repository);
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final FavoritesRepository _repository;

  FavoritesNotifier(this._repository) : super({}) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = await _repository.getFavoriteBusinessIds();
    } catch (e) {
      debugPrint('FavoritesNotifier: failed to load favorites ($e)');
      ToastService.showError(ToastService.friendlyError(e));
    }
  }

  /// Optimistic toggle: update UI immediately, revert on error.
  Future<void> toggle(String businessId) async {
    final wasFavorited = state.contains(businessId);
    final previous = Set<String>.from(state);

    // Optimistic update
    if (wasFavorited) {
      state = Set<String>.from(state)..remove(businessId);
    } else {
      state = Set<String>.from(state)..add(businessId);
    }

    try {
      if (wasFavorited) {
        await _repository.removeFavorite(businessId);
      } else {
        await _repository.addFavorite(businessId);
      }
    } catch (e) {
      // Revert on failure
      state = previous;
      debugPrint('FavoritesNotifier: toggle failed ($e)');
      ToastService.showError(ToastService.friendlyError(e));
    }
  }
}
