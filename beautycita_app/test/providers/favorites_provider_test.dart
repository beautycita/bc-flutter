import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beautycita/providers/favorites_provider.dart';
import '../helpers/test_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FavoritesNotifier', () {
    late MockFavoritesRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockFavoritesRepository();
      // Configure the mock to return empty favorites by default
      when(() => mockRepo.getFavoriteBusinessIds())
          .thenAnswer((_) async => <String>{});
    });

    tearDown(() {
      container.dispose();
    });

    ProviderContainer createContainer({Set<String>? initialFavorites}) {
      if (initialFavorites != null) {
        when(() => mockRepo.getFavoriteBusinessIds())
            .thenAnswer((_) async => initialFavorites);
      }
      container = ProviderContainer(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      return container;
    }

    test('loads favorites on creation', () async {
      when(() => mockRepo.getFavoriteBusinessIds())
          .thenAnswer((_) async => {'biz-1', 'biz-2'});

      createContainer();
      // Read to trigger creation
      container.read(favoritesProvider);

      // Wait for async _load() to complete
      await Future<void>.delayed(Duration.zero);

      final state = container.read(favoritesProvider);
      expect(state, containsAll(['biz-1', 'biz-2']));
    });

    group('toggle', () {
      test('adds business to favorites (optimistic)', () async {
        createContainer(initialFavorites: {});
        container.read(favoritesProvider);
        await Future<void>.delayed(Duration.zero);

        when(() => mockRepo.addFavorite('biz-1'))
            .thenAnswer((_) async {});

        await container.read(favoritesProvider.notifier).toggle('biz-1');

        expect(container.read(favoritesProvider), contains('biz-1'));
        verify(() => mockRepo.addFavorite('biz-1')).called(1);
      });

      test('removes business from favorites (optimistic)', () async {
        createContainer(initialFavorites: {'biz-1'});
        container.read(favoritesProvider);
        await Future<void>.delayed(Duration.zero);

        when(() => mockRepo.removeFavorite('biz-1'))
            .thenAnswer((_) async {});

        await container.read(favoritesProvider.notifier).toggle('biz-1');

        expect(container.read(favoritesProvider), isNot(contains('biz-1')));
        verify(() => mockRepo.removeFavorite('biz-1')).called(1);
      });

      test('reverts on add failure', () async {
        createContainer(initialFavorites: {});
        container.read(favoritesProvider);
        await Future<void>.delayed(Duration.zero);

        when(() => mockRepo.addFavorite('biz-1'))
            .thenThrow(Exception('Network error'));

        await container.read(favoritesProvider.notifier).toggle('biz-1');

        // Should have reverted to empty
        expect(container.read(favoritesProvider), isNot(contains('biz-1')));
      });

      test('reverts on remove failure', () async {
        createContainer(initialFavorites: {'biz-1'});
        container.read(favoritesProvider);
        await Future<void>.delayed(Duration.zero);

        when(() => mockRepo.removeFavorite('biz-1'))
            .thenThrow(Exception('Network error'));

        await container.read(favoritesProvider.notifier).toggle('biz-1');

        // Should have reverted — biz-1 still in favorites
        expect(container.read(favoritesProvider), contains('biz-1'));
      });

      test('optimistic UI: state updates before async completes', () async {
        createContainer(initialFavorites: {});
        container.read(favoritesProvider);
        await Future<void>.delayed(Duration.zero);

        // Delay the async call to verify optimistic update
        when(() => mockRepo.addFavorite('biz-1'))
            .thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });

        // Don't await — check state immediately
        final future = container.read(favoritesProvider.notifier).toggle('biz-1');

        // State should already contain biz-1 (optimistic)
        expect(container.read(favoritesProvider), contains('biz-1'));

        await future;
      });
    });
  });
}
