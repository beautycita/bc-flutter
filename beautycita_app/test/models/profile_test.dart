import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_core/models.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('Profile', () {
    group('fromJson', () {
      test('parses all fields', () {
        final p = Profile.fromJson(profileJson());

        expect(p.id, 'user-1');
        expect(p.fullName, 'Ana Garcia');
        expect(p.username, 'anaGarcia');
        expect(p.phone, '3221234567');
        expect(p.saldo, 100.0);
        expect(p.role, 'customer');
      });

      test('defaults saldo to 0 when null', () {
        final p = Profile.fromJson(profileJson(saldo: 0));
        final json = profileJson();
        json.remove('saldo');
        final p2 = Profile.fromJson(json);

        expect(p.saldo, 0);
        expect(p2.saldo, 0);
      });

      test('defaults role to customer when null', () {
        final json = profileJson();
        json.remove('role');
        final p = Profile.fromJson(json);

        expect(p.role, 'customer');
      });

      test('handles null optional fields', () {
        final p = Profile.fromJson(profileJson(
          fullName: null,
          username: null,
          phone: null,
          avatarUrl: null,
        ));

        expect(p.fullName, isNull);
        expect(p.username, isNull);
        expect(p.phone, isNull);
        expect(p.avatarUrl, isNull);
      });
    });

    group('displayName', () {
      test('returns fullName when available', () {
        final p = Profile.fromJson(profileJson(fullName: 'Ana Garcia'));
        expect(p.displayName, 'Ana Garcia');
      });

      test('falls back to username when fullName is null', () {
        final p = Profile.fromJson(profileJson(fullName: null, username: 'anaGarcia'));
        expect(p.displayName, 'anaGarcia');
      });

      test('falls back to Usuario when both are null', () {
        final p = Profile.fromJson(profileJson(fullName: null, username: null));
        expect(p.displayName, 'Usuario');
      });
    });

    group('toJson', () {
      test('round-trips through fromJson', () {
        final original = profileJson();
        final p = Profile.fromJson(original);
        final json = p.toJson();

        expect(json['id'], 'user-1');
        expect(json['full_name'], 'Ana Garcia');
        expect(json['username'], 'anaGarcia');
        expect(json['saldo'], 100.0);
        expect(json['role'], 'customer');
      });
    });
  });
}
