import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_core/models.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('FeedItem', () {
    group('fromJson', () {
      test('parses all fields', () {
        final f = FeedItem.fromJson(feedItemJson());

        expect(f.id, 'feed-1');
        expect(f.type, 'photo');
        expect(f.businessId, 'biz-1');
        expect(f.businessName, 'Salon Rosa');
        expect(f.businessSlug, 'salon-rosa');
        expect(f.staffName, 'Maria');
        expect(f.beforeUrl, 'https://example.com/before.jpg');
        expect(f.afterUrl, 'https://example.com/after.jpg');
        expect(f.caption, 'Transformacion increible');
        expect(f.serviceCategory, 'hair');
        expect(f.saveCount, 5);
        expect(f.isSaved, false);
      });

      test('defaults type to photo when null', () {
        final json = feedItemJson();
        json.remove('type');
        final f = FeedItem.fromJson(json);

        expect(f.type, 'photo');
      });

      test('parses product tags', () {
        final f = FeedItem.fromJson(feedItemJson(
          productTags: [
            feedProductTagJson(name: 'Product A'),
            feedProductTagJson(productId: 'prod-2', name: 'Product B'),
          ],
        ));

        expect(f.productTags, hasLength(2));
        expect(f.productTags[0].name, 'Product A');
        expect(f.productTags[1].productId, 'prod-2');
      });

      test('handles null product tags', () {
        final f = FeedItem.fromJson(feedItemJson(productTags: null));
        expect(f.productTags, isEmpty);
      });

      test('handles empty product tags list', () {
        final f = FeedItem.fromJson(feedItemJson(productTags: []));
        expect(f.productTags, isEmpty);
      });

      test('handles null optional fields', () {
        final f = FeedItem.fromJson(feedItemJson(
          businessPhotoUrl: null,
          businessSlug: null,
          staffName: null,
          beforeUrl: null,
          caption: null,
          serviceCategory: null,
        ));

        expect(f.businessPhotoUrl, isNull);
        expect(f.businessSlug, isNull);
        expect(f.staffName, isNull);
        expect(f.beforeUrl, isNull);
        expect(f.caption, isNull);
      });
    });

    group('computed properties', () {
      test('isBeforeAfter requires photo type and beforeUrl', () {
        final withBoth = FeedItem.fromJson(feedItemJson(type: 'photo', beforeUrl: 'url'));
        final noBeforeUrl = FeedItem.fromJson(feedItemJson(type: 'photo', beforeUrl: null));
        final wrongType = FeedItem.fromJson(feedItemJson(type: 'showcase', beforeUrl: 'url'));

        expect(withBoth.isBeforeAfter, true);
        expect(noBeforeUrl.isBeforeAfter, false);
        expect(wrongType.isBeforeAfter, false);
      });

      test('isShowcase returns true for showcase type', () {
        expect(FeedItem.fromJson(feedItemJson(type: 'showcase')).isShowcase, true);
        expect(FeedItem.fromJson(feedItemJson(type: 'photo')).isShowcase, false);
      });

      test('hasProducts returns true when product tags exist', () {
        final with_ = FeedItem.fromJson(feedItemJson(
          productTags: [feedProductTagJson()],
        ));
        final without = FeedItem.fromJson(feedItemJson(productTags: []));

        expect(with_.hasProducts, true);
        expect(without.hasProducts, false);
      });
    });
  });

  group('FeedProductTag', () {
    test('fromJson parses all fields', () {
      final t = FeedProductTag.fromJson(feedProductTagJson());

      expect(t.productId, 'prod-1');
      expect(t.name, 'Kerastase Elixir');
      expect(t.brand, 'Kerastase');
      expect(t.price, 890.0);
      expect(t.photoUrl, 'https://example.com/product.jpg');
      expect(t.inStock, true);
    });

    test('defaults inStock to true when null', () {
      final json = feedProductTagJson();
      json.remove('in_stock');
      final t = FeedProductTag.fromJson(json);

      expect(t.inStock, true);
    });
  });
}
