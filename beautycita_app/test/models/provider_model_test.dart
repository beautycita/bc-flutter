import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/models/provider.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('Provider', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = providerJson();
        final p = Provider.fromJson(json);

        expect(p.id, 'biz-1');
        expect(p.name, 'Salon Rosa');
        expect(p.phone, '3221234567');
        expect(p.whatsapp, '523221234567');
        expect(p.address, 'Av. Mexico 123');
        expect(p.city, 'Puerto Vallarta');
        expect(p.state, 'Jalisco');
        expect(p.lat, 20.6534);
        expect(p.lng, -105.2253);
        expect(p.rating, 4.5);
        expect(p.reviewsCount, 42);
        expect(p.businessCategory, 'salon');
        expect(p.serviceCategories, ['nails', 'hair']);
        expect(p.isVerified, isTrue);
      });

      test('defaults city and state to empty string when null', () {
        final json = providerJson();
        json['city'] = null;
        json['state'] = null;
        final p = Provider.fromJson(json);

        expect(p.city, '');
        expect(p.state, '');
      });

      test('defaults reviewsCount to 0 when null', () {
        final json = providerJson();
        json['total_reviews'] = null;
        final p = Provider.fromJson(json);

        expect(p.reviewsCount, 0);
      });

      test('defaults isVerified to false when null', () {
        final json = providerJson();
        json['is_verified'] = null;
        final p = Provider.fromJson(json);

        expect(p.isVerified, isFalse);
      });

      test('defaults serviceCategories to empty list when null', () {
        final json = providerJson();
        json['service_categories'] = null;
        final p = Provider.fromJson(json);

        expect(p.serviceCategories, isEmpty);
      });

      test('handles null optional fields', () {
        final json = providerJson();
        json['phone'] = null;
        json['whatsapp'] = null;
        json['address'] = null;
        json['lat'] = null;
        json['lng'] = null;
        json['photo_url'] = null;
        json['average_rating'] = null;
        json['hours'] = null;
        json['website'] = null;
        json['facebook_url'] = null;
        json['instagram_handle'] = null;
        final p = Provider.fromJson(json);

        expect(p.phone, isNull);
        expect(p.whatsapp, isNull);
        expect(p.lat, isNull);
        expect(p.lng, isNull);
        expect(p.rating, isNull);
        expect(p.website, isNull);
      });
    });

    group('toJson', () {
      test('round-trips through fromJson', () {
        final original = providerJson();
        final p = Provider.fromJson(original);
        final json = p.toJson();

        expect(json['id'], 'biz-1');
        expect(json['name'], 'Salon Rosa');
        expect(json['city'], 'Puerto Vallarta');
        expect(json['average_rating'], 4.5);
        expect(json['total_reviews'], 42);
        expect(json['service_categories'], ['nails', 'hair']);
        expect(json['is_verified'], isTrue);
      });
    });
  });

  group('ProviderService', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'svc-1',
        'business_id': 'biz-1',
        'category': 'nails',
        'subcategory': 'manicure',
        'name': 'Manicure Gel',
        'price': 350.0,
        'duration_minutes': 60,
      };
      final svc = ProviderService.fromJson(json);

      expect(svc.id, 'svc-1');
      expect(svc.providerId, 'biz-1');
      expect(svc.category, 'nails');
      expect(svc.subcategory, 'manicure');
      expect(svc.serviceName, 'Manicure Gel');
      expect(svc.priceMin, 350.0);
      expect(svc.durationMinutes, 60);
    });

    test('defaults duration to 60 when null', () {
      final json = {
        'id': 'svc-1',
        'business_id': 'biz-1',
        'name': 'Corte',
        'duration_minutes': null,
      };
      final svc = ProviderService.fromJson(json);

      expect(svc.durationMinutes, 60);
    });

    test('defaults category and subcategory to empty when null', () {
      final json = {
        'id': 'svc-1',
        'business_id': 'biz-1',
        'name': 'Corte',
        'category': null,
        'subcategory': null,
      };
      final svc = ProviderService.fromJson(json);

      expect(svc.category, '');
      expect(svc.subcategory, '');
    });

    test('toJson serializes correctly', () {
      final json = {
        'id': 'svc-1',
        'business_id': 'biz-1',
        'category': 'nails',
        'subcategory': 'manicure',
        'name': 'Manicure Gel',
        'price': 350.0,
        'duration_minutes': 60,
      };
      final svc = ProviderService.fromJson(json);
      final out = svc.toJson();

      expect(out['id'], 'svc-1');
      expect(out['business_id'], 'biz-1');
      expect(out['name'], 'Manicure Gel');
      expect(out['price'], 350.0);
      expect(out['duration_minutes'], 60);
    });
  });
}
