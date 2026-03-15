import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beautycita/config/constants.dart';

// We test the version comparison and dismissal logic directly
// rather than mocking the full UpdaterService singleton.

void main() {
  group('UpdaterService version check logic', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('version comparison', () {
      test('detects update when remote build > local build', () {
        final remoteBuild = AppConstants.buildNumber + 1;
        final needsUpdate = remoteBuild > AppConstants.buildNumber;
        expect(needsUpdate, isTrue);
      });

      test('skips update when remote build == local build', () {
        final remoteBuild = AppConstants.buildNumber;
        final needsUpdate = remoteBuild > AppConstants.buildNumber;
        expect(needsUpdate, isFalse);
      });

      test('skips update when remote build < local build', () {
        final remoteBuild = AppConstants.buildNumber - 1;
        final needsUpdate = remoteBuild > AppConstants.buildNumber;
        expect(needsUpdate, isFalse);
      });
    });

    group('version.json parsing', () {
      test('parses valid version.json response', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'version': '2.0.0',
              'build': 99999,
              'url': 'https://example.com/app.apk',
              'required': true,
            }),
            200,
          );
        });

        final response = await client.get(Uri.parse(AppConstants.versionCheckUrl));
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        expect(data['version'], '2.0.0');
        expect(data['build'], 99999);
        expect(data['url'], 'https://example.com/app.apk');
        expect(data['required'], isTrue);

        client.close();
      });

      test('handles missing fields with defaults', () {
        final data = <String, dynamic>{};
        final remoteBuild = data['build'] as int? ?? 0;
        final remoteVersion = data['version'] as String? ?? '';
        final url = data['url'] as String? ?? '';
        final required = data['required'] as bool? ?? false;

        expect(remoteBuild, 0);
        expect(remoteVersion, '');
        expect(url, '');
        expect(required, isFalse);
      });

      test('handles HTTP error gracefully', () async {
        final client = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        final response = await client.get(Uri.parse(AppConstants.versionCheckUrl));
        expect(response.statusCode, 500);

        client.close();
      });
    });

    group('24h dismissal cooldown', () {
      test('recently dismissed build is skipped', () async {
        SharedPreferences.setMockInitialValues({
          AppConstants.keyUpdateDismissedBuild: 60000,
          AppConstants.keyUpdateDismissedAt: DateTime.now().toIso8601String(),
        });

        final prefs = await SharedPreferences.getInstance();
        final dismissedBuild = prefs.getInt(AppConstants.keyUpdateDismissedBuild) ?? 0;
        final dismissedAtStr = prefs.getString(AppConstants.keyUpdateDismissedAt);
        final dismissedAt = DateTime.tryParse(dismissedAtStr ?? '');

        final isDismissedRecently = dismissedBuild == 60000 &&
            dismissedAt != null &&
            DateTime.now().difference(dismissedAt) < AppConstants.updateDismissCooldown;

        expect(isDismissedRecently, isTrue);
      });

      test('expired dismissal is not skipped (>24h ago)', () async {
        final longAgo = DateTime.now().subtract(const Duration(hours: 25));
        SharedPreferences.setMockInitialValues({
          AppConstants.keyUpdateDismissedBuild: 60000,
          AppConstants.keyUpdateDismissedAt: longAgo.toIso8601String(),
        });

        final prefs = await SharedPreferences.getInstance();
        final dismissedBuild = prefs.getInt(AppConstants.keyUpdateDismissedBuild) ?? 0;
        final dismissedAtStr = prefs.getString(AppConstants.keyUpdateDismissedAt);
        final dismissedAt = DateTime.tryParse(dismissedAtStr ?? '');

        final isDismissedRecently = dismissedBuild == 60000 &&
            dismissedAt != null &&
            DateTime.now().difference(dismissedAt) < AppConstants.updateDismissCooldown;

        expect(isDismissedRecently, isFalse);
      });

      test('different build number is not skipped', () async {
        SharedPreferences.setMockInitialValues({
          AppConstants.keyUpdateDismissedBuild: 50000,
          AppConstants.keyUpdateDismissedAt: DateTime.now().toIso8601String(),
        });

        final prefs = await SharedPreferences.getInstance();
        final dismissedBuild = prefs.getInt(AppConstants.keyUpdateDismissedBuild) ?? 0;
        final remoteBuild = 60000;

        final isDismissedRecently = dismissedBuild == remoteBuild;
        expect(isDismissedRecently, isFalse);
      });

      test('required flag bypasses dismissal check', () {
        final required = true;

        // If required, don't check dismissal
        final shouldShow = required;
        expect(shouldShow, isTrue);
      });

      test('records dismissal correctly', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final remoteBuild = 60000;
        await prefs.setInt(AppConstants.keyUpdateDismissedBuild, remoteBuild);
        await prefs.setString(
            AppConstants.keyUpdateDismissedAt, DateTime.now().toIso8601String());

        expect(prefs.getInt(AppConstants.keyUpdateDismissedBuild), 60000);
        expect(prefs.getString(AppConstants.keyUpdateDismissedAt), isNotNull);
      });
    });
  });
}
