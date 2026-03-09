import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/models/curate_result.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('CurateRequest', () {
    test('toJson includes required fields', () {
      final request = CurateRequest(
        serviceType: 'manicure_gel',
        location: const LatLng(lat: 20.65, lng: -105.22),
        transportMode: 'car',
      );
      final json = request.toJson();

      expect(json['service_type'], 'manicure_gel');
      expect(json['transport_mode'], 'car');
      expect(json['location']['lat'], 20.65);
      expect(json['location']['lng'], -105.22);
    });

    test('toJson includes optional fields when set', () {
      final request = CurateRequest(
        serviceType: 'manicure_gel',
        userId: 'user-1',
        location: const LatLng(lat: 20.65, lng: -105.22),
        transportMode: 'uber',
        followUpAnswers: {'nail_shape': 'almond'},
        overrideWindow: const OverrideWindow(range: 'tomorrow', timeOfDay: 'morning'),
        priceComfort: 'premium',
        qualitySpeed: 0.8,
        exploreLoyalty: 0.2,
        businessId: 'biz-1',
      );
      final json = request.toJson();

      expect(json['user_id'], 'user-1');
      expect(json['follow_up_answers'], {'nail_shape': 'almond'});
      expect(json['override_window']['range'], 'tomorrow');
      expect(json['override_window']['time_of_day'], 'morning');
      expect(json['price_comfort'], 'premium');
      expect(json['quality_speed'], 0.8);
      expect(json['explore_loyalty'], 0.2);
      expect(json['business_id'], 'biz-1');
    });

    test('toJson omits null optional fields with if-guards', () {
      final request = CurateRequest(
        serviceType: 'manicure_gel',
        location: const LatLng(lat: 20.65, lng: -105.22),
        transportMode: 'car',
      );
      final json = request.toJson();

      // user_id is always present (even as null), but conditional fields are omitted
      expect(json.containsKey('follow_up_answers'), isFalse);
      expect(json.containsKey('override_window'), isFalse);
      expect(json.containsKey('business_id'), isFalse);
      expect(json.containsKey('price_comfort'), isFalse);
      expect(json.containsKey('quality_speed'), isFalse);
      expect(json.containsKey('explore_loyalty'), isFalse);
    });
  });

  group('OverrideWindow', () {
    test('toJson serializes all fields', () {
      const window = OverrideWindow(
        range: 'this_week',
        timeOfDay: 'evening',
        specificDate: '2026-03-15',
      );
      final json = window.toJson();

      expect(json['range'], 'this_week');
      expect(json['time_of_day'], 'evening');
      expect(json['specific_date'], '2026-03-15');
    });
  });

  group('CurateResponse', () {
    test('fromJson parses booking window and results', () {
      final json = curateResponseJson(resultCount: 2);
      final response = CurateResponse.fromJson(json);

      expect(response.bookingWindow.primaryDate, '2026-03-10');
      expect(response.bookingWindow.primaryTime, '14:00');
      expect(response.results, hasLength(2));
    });

    test('fromJson handles empty results', () {
      final json = curateResponseJson(resultCount: 0);
      final response = CurateResponse.fromJson(json);

      expect(response.results, isEmpty);
    });
  });

  group('ResultCard', () {
    test('fromJson parses all nested objects', () {
      final json = resultCardJson(rank: 1, score: 0.92);
      final card = ResultCard.fromJson(json);

      expect(card.rank, 1);
      expect(card.score, 0.92);
      expect(card.business.name, 'Salon Rosa');
      expect(card.staff.name, 'Maria 1');
      expect(card.service.price, 350.0);
      expect(card.service.durationMinutes, 60);
      expect(card.service.currency, 'MXN');
      expect(card.slot.startsAt, '2026-03-10T14:00:00Z');
      expect(card.transport.mode, 'car');
      expect(card.transport.durationMin, 15);
      expect(card.badges, ['top_rated']);
      expect(card.areaAvgPrice, 300.0);
    });

    test('fromJson handles null review snippet', () {
      final json = resultCardJson();
      final card = ResultCard.fromJson(json);

      expect(card.reviewSnippet, isNull);
    });

    test('fromJson parses review snippet when present', () {
      final json = resultCardJson();
      json['review_snippet'] = {
        'text': 'Excelente servicio',
        'author_name': 'Ana',
        'days_ago': 3,
        'rating': 5,
        'quality_score': 0.95,
      };
      final card = ResultCard.fromJson(json);

      expect(card.reviewSnippet, isNotNull);
      expect(card.reviewSnippet!.text, 'Excelente servicio');
      expect(card.reviewSnippet!.authorName, 'Ana');
      expect(card.reviewSnippet!.isFallback, isFalse);
    });
  });

  group('ReviewSnippet', () {
    test('isFallback is true when authorName is null', () {
      const snippet = ReviewSnippet(text: 'Nuevo salon');
      expect(snippet.isFallback, isTrue);
    });

    test('isFallback is false when authorName is set', () {
      const snippet = ReviewSnippet(text: 'Gran servicio', authorName: 'Ana');
      expect(snippet.isFallback, isFalse);
    });
  });

  group('SlotInfo', () {
    test('startTime and endTime parse ISO strings', () {
      const slot = SlotInfo(
        startsAt: '2026-03-10T14:00:00Z',
        endsAt: '2026-03-10T15:00:00Z',
      );

      expect(slot.startTime, DateTime.utc(2026, 3, 10, 14));
      expect(slot.endTime, DateTime.utc(2026, 3, 10, 15));
    });
  });

  group('ScoringBreakdown', () {
    test('fromJson parses all scores', () {
      final json = {
        'proximity': 0.8,
        'availability': 0.9,
        'rating': 0.85,
        'price': 0.7,
        'portfolio': 0.6,
      };
      final breakdown = ScoringBreakdown.fromJson(json);

      expect(breakdown.proximity, 0.8);
      expect(breakdown.availability, 0.9);
      expect(breakdown.rating, 0.85);
      expect(breakdown.price, 0.7);
      expect(breakdown.portfolio, 0.6);
    });
  });
}
