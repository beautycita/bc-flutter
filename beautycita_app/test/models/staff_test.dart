import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_core/models.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('Staff', () {
    group('fromJson', () {
      test('parses all fields', () {
        final s = Staff.fromJson(staffJson());

        expect(s.id, 'staff-1');
        expect(s.businessId, 'biz-1');
        expect(s.firstName, 'Maria');
        expect(s.lastName, 'Lopez');
        expect(s.position, 'stylist');
        expect(s.experienceYears, 5);
        expect(s.averageRating, 4.8);
        expect(s.totalReviews, 20);
        expect(s.isActive, true);
        expect(s.commissionRate, 0.3);
      });

      test('defaults missing fields', () {
        final json = <String, dynamic>{
          'id': 'staff-2',
          'business_id': 'biz-1',
        };
        final s = Staff.fromJson(json);

        expect(s.firstName, '');
        expect(s.lastName, '');
        expect(s.position, 'stylist');
        expect(s.experienceYears, 0);
        expect(s.averageRating, 0);
        expect(s.totalReviews, 0);
        expect(s.isActive, true);
        expect(s.commissionRate, 0);
      });
    });

    group('fullName', () {
      test('combines first and last name', () {
        final s = Staff.fromJson(staffJson(firstName: 'Maria', lastName: 'Lopez'));
        expect(s.fullName, 'Maria Lopez');
      });

      test('trims when last name is empty', () {
        final s = Staff.fromJson(staffJson(firstName: 'Maria', lastName: ''));
        expect(s.fullName, 'Maria');
      });
    });

    group('toJson', () {
      test('round-trips through fromJson', () {
        final s = Staff.fromJson(staffJson());
        final json = s.toJson();

        expect(json['id'], 'staff-1');
        expect(json['business_id'], 'biz-1');
        expect(json['first_name'], 'Maria');
        expect(json['last_name'], 'Lopez');
        expect(json['experience_years'], 5);
        expect(json['average_rating'], 4.8);
        expect(json['is_active'], true);
        expect(json['commission_rate'], 0.3);
      });
    });
  });
}
