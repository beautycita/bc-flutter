import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/config/constants.dart';

void main() {
  group('AppConstants', () {
    group('emailRegex', () {
      test('matches valid emails', () {
        final valid = [
          'user@example.com',
          'test.name@domain.org',
          'user+tag@domain.co',
          'a@b.cd',
        ];
        for (final email in valid) {
          expect(AppConstants.emailRegex.hasMatch(email), isTrue,
              reason: '$email should be valid');
        }
      });

      test('rejects invalid emails', () {
        final invalid = [
          '',
          'noatsign',
          '@domain.com',
          'user@',
          'user@.com',
          'user@domain',
          'user @domain.com',
        ];
        for (final email in invalid) {
          expect(AppConstants.emailRegex.hasMatch(email), isFalse,
              reason: '$email should be invalid');
        }
      });
    });

    group('phoneRegex', () {
      test('matches 10-digit Mexican phone numbers', () {
        expect(AppConstants.phoneRegex.hasMatch('3221234567'), isTrue);
        expect(AppConstants.phoneRegex.hasMatch('5512345678'), isTrue);
      });

      test('rejects non-10-digit strings', () {
        expect(AppConstants.phoneRegex.hasMatch('123456789'), isFalse); // 9 digits
        expect(AppConstants.phoneRegex.hasMatch('12345678901'), isFalse); // 11 digits
        expect(AppConstants.phoneRegex.hasMatch('322-123-4567'), isFalse); // dashes
        expect(AppConstants.phoneRegex.hasMatch('abcdefghij'), isFalse); // letters
        expect(AppConstants.phoneRegex.hasMatch(''), isFalse);
      });
    });

    group('baseBuildNumber ABI offset stripping', () {
      // Save and restore buildNumber since it's a mutable static
      late int originalBuildNumber;

      setUp(() {
        originalBuildNumber = AppConstants.buildNumber;
      });

      tearDown(() {
        AppConstants.buildNumber = originalBuildNumber;
      });

      // Uses examples from the code comment: base 50010, offsets 1-4k
      test('strips armeabi ABI offset (+1000): 51010 → 50010', () {
        AppConstants.buildNumber = 51010;
        // (51010 ~/ 1000) % 10 = 51 % 10 = 1, in [1,4] → strip
        expect(AppConstants.baseBuildNumber, 50010);
      });

      test('strips arm64 ABI offset (+2000): 52010 → 50010', () {
        AppConstants.buildNumber = 52010;
        // (52010 ~/ 1000) % 10 = 52 % 10 = 2, in [1,4] → strip
        expect(AppConstants.baseBuildNumber, 50010);
      });

      test('strips x86 ABI offset (+3000): 53010 → 50010', () {
        AppConstants.buildNumber = 53010;
        expect(AppConstants.baseBuildNumber, 50010);
      });

      test('strips x86_64 ABI offset (+4000): 54010 → 50010', () {
        AppConstants.buildNumber = 54010;
        // (54010 ~/ 1000) % 10 = 54 % 10 = 4, in [1,4] → strip
        expect(AppConstants.baseBuildNumber, 50010);
      });

      test('no offset when thousands digit is 0: 50010 → 50010', () {
        AppConstants.buildNumber = 50010;
        // (50010 ~/ 1000) % 10 = 50 % 10 = 0, NOT in [1,4] → no strip
        expect(AppConstants.baseBuildNumber, 50010);
      });

      test('no offset when thousands digit > 4: 48063 → 48063', () {
        AppConstants.buildNumber = 48063;
        // (48063 ~/ 1000) % 10 = 48 % 10 = 8, NOT in [1,4] → no strip
        expect(AppConstants.baseBuildNumber, 48063);
      });

      test('no offset when thousands digit is 5: 45000 → 45000', () {
        AppConstants.buildNumber = 45000;
        // (45000 ~/ 1000) % 10 = 45 % 10 = 5, NOT in [1,4] → no strip
        expect(AppConstants.baseBuildNumber, 45000);
      });

      test('returns 0 for buildNumber <= 0', () {
        AppConstants.buildNumber = 0;
        expect(AppConstants.baseBuildNumber, 0);

        AppConstants.buildNumber = -1;
        expect(AppConstants.baseBuildNumber, 0);
      });

      test('offset 1 is stripped correctly: 41000 → 40000', () {
        AppConstants.buildNumber = 41000;
        expect(AppConstants.baseBuildNumber, 40000);
      });

      test('offset 2 is stripped correctly: 42000 → 40000', () {
        AppConstants.buildNumber = 42000;
        expect(AppConstants.baseBuildNumber, 40000);
      });

      test('offset 3 is stripped correctly: 43000 → 40000', () {
        AppConstants.buildNumber = 43000;
        expect(AppConstants.baseBuildNumber, 40000);
      });

      test('offset 4 is stripped correctly: 44000 → 40000', () {
        AppConstants.buildNumber = 44000;
        expect(AppConstants.baseBuildNumber, 40000);
      });
    });

    group('value ranges', () {
      test('buildNumber is positive', () {
        expect(AppConstants.buildNumber, greaterThan(0));
      });

      test('version is semver format', () {
        expect(
          RegExp(r'^\d+\.\d+\.\d+$').hasMatch(AppConstants.version),
          isTrue,
        );
      });

      test('padding values are positive and ordered', () {
        expect(AppConstants.paddingXS, greaterThan(0));
        expect(AppConstants.paddingSM, greaterThan(AppConstants.paddingXS));
        expect(AppConstants.paddingMD, greaterThan(AppConstants.paddingSM));
        expect(AppConstants.paddingLG, greaterThan(AppConstants.paddingMD));
        expect(AppConstants.paddingXL, greaterThan(AppConstants.paddingLG));
      });

      test('radius values are positive and ordered', () {
        expect(AppConstants.radiusXS, greaterThan(0));
        expect(AppConstants.radiusSM, greaterThan(AppConstants.radiusXS));
        expect(AppConstants.radiusMD, greaterThan(AppConstants.radiusSM));
        expect(AppConstants.radiusLG, greaterThan(AppConstants.radiusMD));
        expect(AppConstants.radiusXL, greaterThan(AppConstants.radiusLG));
      });

      test('touch targets meet minimum standards', () {
        expect(AppConstants.minTouchHeight, greaterThanOrEqualTo(44.0));
        expect(AppConstants.comfortableTouchHeight,
            greaterThan(AppConstants.minTouchHeight));
      });

      test('thumb zone spans 60% of screen', () {
        expect(AppConstants.thumbZoneHeight, 0.6);
        expect(AppConstants.thumbZoneStart, 0.4);
        expect(
          AppConstants.thumbZoneStart + AppConstants.thumbZoneHeight,
          closeTo(1.0, 0.001),
        );
      });

      test('opacity values are in 0-1 range', () {
        expect(AppConstants.opacityDisabled, inInclusiveRange(0.0, 1.0));
        expect(AppConstants.opacityMedium, inInclusiveRange(0.0, 1.0));
        expect(AppConstants.opacityLight, inInclusiveRange(0.0, 1.0));
      });

      test('page size limits are sensible', () {
        expect(AppConstants.defaultPageSize, greaterThan(0));
        expect(AppConstants.maxPageSize, greaterThan(AppConstants.defaultPageSize));
      });

      test('update dismiss cooldown is 24 hours', () {
        expect(
          AppConstants.updateDismissCooldown,
          const Duration(hours: 24),
        );
      });

      test('versionCheckUrl is a valid URL', () {
        expect(
          Uri.tryParse(AppConstants.versionCheckUrl)?.hasScheme,
          isTrue,
        );
      });
    });
  });
}
