import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../helpers/test_mocks.dart';

void main() {
  group('FavoritesRepository (via mock)', () {
    late MockFavoritesRepository repo;

    setUp(() {
      repo = MockFavoritesRepository();
    });

    group('getFavoriteBusinessIds', () {
      test('returns empty set when user has no favorites', () async {
        when(() => repo.getFavoriteBusinessIds())
            .thenAnswer((_) async => <String>{});

        final result = await repo.getFavoriteBusinessIds();
        expect(result, isEmpty);
      });

      test('returns set of business IDs', () async {
        when(() => repo.getFavoriteBusinessIds())
            .thenAnswer((_) async => {'biz-1', 'biz-2', 'biz-3'});

        final result = await repo.getFavoriteBusinessIds();
        expect(result, hasLength(3));
        expect(result, contains('biz-1'));
        expect(result, contains('biz-2'));
        expect(result, contains('biz-3'));
      });

      test('returns empty set when not authenticated', () async {
        when(() => repo.getFavoriteBusinessIds())
            .thenAnswer((_) async => <String>{});

        final result = await repo.getFavoriteBusinessIds();
        expect(result, isEmpty);
      });
    });

    group('addFavorite', () {
      test('completes successfully', () async {
        when(() => repo.addFavorite(any()))
            .thenAnswer((_) async {});

        await expectLater(repo.addFavorite('biz-1'), completes);
        verify(() => repo.addFavorite('biz-1')).called(1);
      });

      test('throws when not authenticated', () async {
        when(() => repo.addFavorite(any()))
            .thenThrow(Exception('User not authenticated'));

        expect(
          () => repo.addFavorite('biz-1'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('removeFavorite', () {
      test('completes successfully', () async {
        when(() => repo.removeFavorite(any()))
            .thenAnswer((_) async {});

        await expectLater(repo.removeFavorite('biz-1'), completes);
        verify(() => repo.removeFavorite('biz-1')).called(1);
      });

      test('throws when not authenticated', () async {
        when(() => repo.removeFavorite(any()))
            .thenThrow(Exception('User not authenticated'));

        expect(
          () => repo.removeFavorite('biz-1'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
