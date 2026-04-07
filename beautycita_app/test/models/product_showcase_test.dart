import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_core/models.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('ProductShowcase', () {
    group('fromJson', () {
      test('parses all fields', () {
        final s = ProductShowcase.fromJson(productShowcaseJson());

        expect(s.id, 'showcase-1');
        expect(s.businessId, 'biz-1');
        expect(s.productId, 'prod-1');
        expect(s.caption, 'Nuevo en stock!');
        expect(s.createdAt, DateTime.utc(2026, 3, 10, 10));
      });

      test('handles null caption', () {
        final s = ProductShowcase.fromJson(productShowcaseJson(caption: null));
        expect(s.caption, isNull);
      });
    });

    group('toJson', () {
      test('serializes for insert (excludes id, timestamps)', () {
        final s = ProductShowcase.fromJson(productShowcaseJson());
        final json = s.toJson();

        expect(json['business_id'], 'biz-1');
        expect(json['product_id'], 'prod-1');
        expect(json['caption'], 'Nuevo en stock!');
        expect(json.containsKey('id'), false);
        expect(json.containsKey('created_at'), false);
      });
    });
  });
}
