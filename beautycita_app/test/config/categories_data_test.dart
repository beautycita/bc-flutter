import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/data/categories.dart';

void main() {
  group('allCategories', () {
    test('is not empty', () {
      expect(allCategories, isNotEmpty);
    });

    test('all category IDs are unique', () {
      final ids = allCategories.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'Duplicate category IDs found');
    });

    test('all subcategory IDs are unique across all categories', () {
      final ids = <String>[];
      for (final cat in allCategories) {
        for (final sub in cat.subcategories) {
          ids.add(sub.id);
        }
      }
      expect(ids.toSet().length, ids.length,
          reason: 'Duplicate subcategory IDs found');
    });

    test('all service item IDs are unique across all categories', () {
      final ids = <String>[];
      for (final cat in allCategories) {
        for (final sub in cat.subcategories) {
          if (sub.items != null) {
            for (final item in sub.items!) {
              ids.add(item.id);
            }
          }
        }
      }
      expect(ids.toSet().length, ids.length,
          reason: 'Duplicate service item IDs found');
    });

    test('all service types are unique', () {
      final types = <String>[];
      for (final cat in allCategories) {
        for (final sub in cat.subcategories) {
          if (sub.items != null) {
            for (final item in sub.items!) {
              types.add(item.serviceType);
            }
          }
        }
      }
      expect(types.toSet().length, types.length,
          reason: 'Duplicate service types found');
    });

    test('every category has a non-empty nameEs', () {
      for (final cat in allCategories) {
        expect(cat.nameEs, isNotEmpty, reason: 'Category ${cat.id} has empty nameEs');
      }
    });

    test('every category has an icon', () {
      for (final cat in allCategories) {
        expect(cat.icon, isNotEmpty, reason: 'Category ${cat.id} has empty icon');
      }
    });

    test('every category has at least one subcategory', () {
      for (final cat in allCategories) {
        expect(cat.subcategories, isNotEmpty,
            reason: 'Category ${cat.id} has no subcategories');
      }
    });

    test('every subcategory references its parent category', () {
      for (final cat in allCategories) {
        for (final sub in cat.subcategories) {
          expect(sub.categoryId, cat.id,
              reason:
                  'Subcategory ${sub.id} has categoryId ${sub.categoryId} but is in category ${cat.id}');
        }
      }
    });

    test('every service item references its parent subcategory', () {
      for (final cat in allCategories) {
        for (final sub in cat.subcategories) {
          if (sub.items != null) {
            for (final item in sub.items!) {
              expect(item.subcategoryId, sub.id,
                  reason:
                      'Item ${item.id} has subcategoryId ${item.subcategoryId} but is in subcategory ${sub.id}');
            }
          }
        }
      }
    });

    test('every service item has a non-empty serviceType', () {
      for (final cat in allCategories) {
        for (final sub in cat.subcategories) {
          if (sub.items != null) {
            for (final item in sub.items!) {
              expect(item.serviceType, isNotEmpty,
                  reason: 'Item ${item.id} has empty serviceType');
            }
          }
        }
      }
    });
  });
}
