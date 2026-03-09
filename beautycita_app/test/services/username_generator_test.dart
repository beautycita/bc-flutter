import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/services/username_generator.dart';

void main() {
  group('UsernameGenerator', () {
    group('generateUsername', () {
      test('returns a non-empty string', () {
        final username = UsernameGenerator.generateUsername();
        expect(username, isNotEmpty);
      });

      test('is in camelCase format (lowercase start, uppercase in middle)', () {
        // Generate several to increase confidence
        for (var i = 0; i < 20; i++) {
          final username = UsernameGenerator.generateUsername();
          // Should start with lowercase
          expect(username[0], equals(username[0].toLowerCase()),
              reason: '$username should start with lowercase');
          // Should contain at least one uppercase letter (the noun capital)
          expect(username, matches(RegExp(r'[A-Z]')),
              reason: '$username should contain uppercase');
        }
      });

      test('does not contain spaces or special characters', () {
        for (var i = 0; i < 50; i++) {
          final username = UsernameGenerator.generateUsername();
          expect(username, matches(RegExp(r'^[a-zA-Z]+$')),
              reason: '$username should be alpha-only');
        }
      });
    });

    group('generateUsernameWithSuffix', () {
      test('ends with a 2-digit number (10-99)', () {
        for (var i = 0; i < 50; i++) {
          final username = UsernameGenerator.generateUsernameWithSuffix();
          final suffix = username.replaceAll(RegExp(r'^[a-zA-Z]+'), '');
          final num = int.tryParse(suffix);
          expect(num, isNotNull, reason: '$username should end with digits');
          expect(num, inInclusiveRange(10, 99),
              reason: 'Suffix $num should be 10-99');
        }
      });

      test('base part is camelCase', () {
        for (var i = 0; i < 20; i++) {
          final username = UsernameGenerator.generateUsernameWithSuffix();
          final base = username.replaceAll(RegExp(r'\d+$'), '');
          expect(base[0], equals(base[0].toLowerCase()));
          expect(base, matches(RegExp(r'[A-Z]')));
        }
      });
    });

    group('generateSuggestions', () {
      test('returns requested count of usernames', () {
        final suggestions = UsernameGenerator.generateSuggestions(count: 5);
        expect(suggestions, hasLength(5));
      });

      test('all usernames in set are unique', () {
        final suggestions = UsernameGenerator.generateSuggestions(count: 10);
        expect(suggestions.toSet().length, suggestions.length,
            reason: 'Suggestions should be unique');
      });

      test('respects withSuffix parameter', () {
        final withSuffix =
            UsernameGenerator.generateSuggestions(count: 5, withSuffix: true);
        for (final name in withSuffix) {
          expect(name, matches(RegExp(r'\d{2}$')),
              reason: '$name should end with 2-digit suffix');
        }

        final withoutSuffix =
            UsernameGenerator.generateSuggestions(count: 5, withSuffix: false);
        for (final name in withoutSuffix) {
          expect(name, matches(RegExp(r'^[a-zA-Z]+$')),
              reason: '$name should be alpha-only');
        }
      });

      test('defaults to 5 suggestions', () {
        final suggestions = UsernameGenerator.generateSuggestions();
        expect(suggestions, hasLength(5));
      });
    });

    group('totalCombinations', () {
      test('is greater than 1000 (enough for uniqueness)', () {
        expect(UsernameGenerator.totalCombinations, greaterThan(1000));
      });

      test('withSuffix has 90x more combinations', () {
        expect(
          UsernameGenerator.totalCombinationsWithSuffix,
          UsernameGenerator.totalCombinations * 90,
        );
      });
    });
  });
}
