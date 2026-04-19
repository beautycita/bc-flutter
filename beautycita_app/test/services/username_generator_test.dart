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

    group('generateUsernameWithSuffix (three-word collision fallback)', () {
      test('is alpha-only (no numbers per "no numbers on usernames" rule)', () {
        for (var i = 0; i < 50; i++) {
          final username = UsernameGenerator.generateUsernameWithSuffix();
          expect(username, matches(RegExp(r'^[a-zA-Z]+$')),
              reason: '$username should be alpha-only');
        }
      });

      test('camelCase with two capital letters (three-word form)', () {
        for (var i = 0; i < 20; i++) {
          final username = UsernameGenerator.generateUsernameWithSuffix();
          expect(username[0], equals(username[0].toLowerCase()),
              reason: '$username should start with lowercase');
          final uppers = RegExp(r'[A-Z]').allMatches(username).length;
          expect(uppers, equals(2),
              reason: '$username should have exactly 2 capitals (3-word camelCase)');
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

      test('respects withSuffix parameter (three-word form, still alpha)', () {
        final withSuffix =
            UsernameGenerator.generateSuggestions(count: 5, withSuffix: true);
        for (final name in withSuffix) {
          expect(name, matches(RegExp(r'^[a-zA-Z]+$')),
              reason: '$name must stay alpha-only per "no numbers" rule');
          final uppers = RegExp(r'[A-Z]').allMatches(name).length;
          expect(uppers, equals(2),
              reason: '$name should be 3-word camelCase');
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
