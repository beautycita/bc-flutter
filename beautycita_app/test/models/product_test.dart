import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_core/models.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('Product', () {
    group('fromJson', () {
      test('parses all fields', () {
        final p = Product.fromJson(productJson());

        expect(p.id, 'prod-1');
        expect(p.businessId, 'biz-1');
        expect(p.name, 'Shampoo Hidratante');
        expect(p.brand, 'Kerastase');
        expect(p.price, 450.0);
        expect(p.photoUrl, 'https://example.com/shampoo.jpg');
        expect(p.category, 'shampoo');
        expect(p.description, 'Shampoo para cabello seco');
        expect(p.inStock, true);
        expect(p.createdAt, DateTime.utc(2026, 3, 1, 10));
        expect(p.updatedAt, DateTime.utc(2026, 3, 5, 10));
      });

      test('defaults inStock to true when null', () {
        final json = productJson();
        json.remove('in_stock');
        final p = Product.fromJson(json);

        expect(p.inStock, true);
      });

      test('handles null optional fields', () {
        final p = Product.fromJson(productJson(
          brand: null,
          description: null,
        ));

        expect(p.brand, isNull);
        expect(p.description, isNull);
      });
    });

    group('toJson', () {
      test('serializes for insert (excludes id, timestamps)', () {
        final p = Product.fromJson(productJson());
        final json = p.toJson();

        expect(json['business_id'], 'biz-1');
        expect(json['name'], 'Shampoo Hidratante');
        expect(json['price'], 450.0);
        expect(json['category'], 'shampoo');
        expect(json.containsKey('id'), false);
        expect(json.containsKey('created_at'), false);
      });
    });

    group('copyWith', () {
      test('copies with new price', () {
        final p = Product.fromJson(productJson());
        final updated = p.copyWith(price: 500.0);

        expect(updated.price, 500.0);
        expect(updated.name, p.name);
        expect(updated.id, p.id);
      });

      test('copies with new stock status', () {
        final p = Product.fromJson(productJson());
        final outOfStock = p.copyWith(inStock: false);

        expect(outOfStock.inStock, false);
        expect(outOfStock.name, p.name);
      });

      test('preserves unchanged fields', () {
        final p = Product.fromJson(productJson());
        final copy = p.copyWith(name: 'New Name');

        expect(copy.brand, p.brand);
        expect(copy.price, p.price);
        expect(copy.category, p.category);
        expect(copy.createdAt, p.createdAt);
      });
    });

    group('categories', () {
      test('contains expected category keys', () {
        expect(Product.categories, containsPair('shampoo', 'Shampoo y Acondicionador'));
        expect(Product.categories, containsPair('perfume', 'Perfume'));
        expect(Product.categories, containsPair('lipstick', 'Labiales y Gloss'));
        expect(Product.categories, hasLength(10));
      });
    });
  });
}
