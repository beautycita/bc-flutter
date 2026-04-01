import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/services/invite_service.dart';

void main() {
  group('InviteService', () {
    group('cleanPhoneForWhatsApp', () {
      test('strips dashes and spaces', () {
        expect(
          InviteService.cleanPhoneForWhatsApp('+52 333-123-4567'),
          equals('523331234567'),
        );
      });

      test('strips parentheses', () {
        expect(
          InviteService.cleanPhoneForWhatsApp('+52 (333) 123 4567'),
          equals('523331234567'),
        );
      });

      test('removes leading + for wa.me format', () {
        expect(
          InviteService.cleanPhoneForWhatsApp('+523331234567'),
          equals('523331234567'),
        );
      });

      test('handles number without country code prefix', () {
        expect(
          InviteService.cleanPhoneForWhatsApp('3331234567'),
          equals('3331234567'),
        );
      });

      test('returns null for null input', () {
        expect(InviteService.cleanPhoneForWhatsApp(null), isNull);
      });

      test('returns null for empty string', () {
        expect(InviteService.cleanPhoneForWhatsApp(''), isNull);
      });

      test('returns null for non-digit string', () {
        expect(InviteService.cleanPhoneForWhatsApp('no-phone'), isNull);
      });

      test('handles multiple + signs gracefully', () {
        expect(
          InviteService.cleanPhoneForWhatsApp('++52 333'),
          equals('52333'),
        );
      });
    });

    group('WhatsApp URL format', () {
      test('builds correct wa.me URL with encoded message', () {
        const phone = '+52 333-123-4567';
        const message = 'Hola! Te invito a BeautyCita';

        final cleanPhone = InviteService.cleanPhoneForWhatsApp(phone);
        final encodedMessage = Uri.encodeComponent(message);
        final url = 'https://wa.me/$cleanPhone?text=$encodedMessage';

        expect(url, startsWith('https://wa.me/523331234567?text='));
        expect(url, contains('Hola'));
        expect(url, contains('BeautyCita'));
      });

      test('encodes special characters in message', () {
        const message = 'Hola! ¿Cómo estás? Te invito & más';
        final encoded = Uri.encodeComponent(message);
        final url = 'https://wa.me/523331234567?text=$encoded';

        // URL should not contain raw & or ? in the message portion
        final textParam = url.split('text=').last;
        expect(textParam, isNot(contains('&')));
        expect(textParam, isNot(contains('?')));
        // But decoding should restore the original
        expect(Uri.decodeComponent(textParam), equals(message));
      });
    });

    group('parseSalonList', () {
      test('parses empty list', () {
        expect(InviteService.parseSalonList([]), isEmpty);
      });

      test('parses single salon with all fields', () {
        final json = [
          {
            'id': 'abc-123',
            'business_name': 'Salon Rosa',
            'phone': '+52 333 111 2222',
            'whatsapp': '+52 333 111 2222',
            'location_address': 'Av. Mexico 123',
            'location_city': 'Guadalajara',
            'feature_image_url': 'https://example.com/photo.jpg',
            'rating_average': 4.5,
            'rating_count': 120,
            'interest_count': 5,
            'distance_km': 2.3,
          }
        ];

        final salons = InviteService.parseSalonList(json);
        expect(salons, hasLength(1));
        expect(salons[0].id, equals('abc-123'));
        expect(salons[0].name, equals('Salon Rosa'));
        expect(salons[0].phone, equals('+52 333 111 2222'));
        expect(salons[0].address, equals('Av. Mexico 123'));
        expect(salons[0].city, equals('Guadalajara'));
        expect(salons[0].rating, equals(4.5));
        expect(salons[0].reviewsCount, equals(120));
        expect(salons[0].interestCount, equals(5));
        expect(salons[0].distanceKm, equals(2.3));
      });

      test('parses salon with old column names', () {
        final json = [
          {
            'id': 'def-456',
            'name': 'Salon Azul',
            'address': 'Calle 5',
            'city': 'CDMX',
            'photo_url': 'https://example.com/blue.jpg',
            'rating': 3.8,
            'reviews_count': 50,
            'interest_count': 0,
          }
        ];

        final salons = InviteService.parseSalonList(json);
        expect(salons, hasLength(1));
        expect(salons[0].name, equals('Salon Azul'));
        expect(salons[0].address, equals('Calle 5'));
        expect(salons[0].city, equals('CDMX'));
        expect(salons[0].photoUrl, equals('https://example.com/blue.jpg'));
        expect(salons[0].rating, equals(3.8));
      });

      test('parses multiple salons', () {
        final json = [
          {'id': '1', 'business_name': 'A', 'interest_count': 0},
          {'id': '2', 'business_name': 'B', 'interest_count': 3},
          {'id': '3', 'business_name': 'C', 'interest_count': 7},
        ];

        final salons = InviteService.parseSalonList(json);
        expect(salons, hasLength(3));
        expect(salons.map((s) => s.id), equals(['1', '2', '3']));
      });

      test('handles missing optional fields gracefully', () {
        final json = [
          {
            'id': 'minimal-1',
            'business_name': 'Minimal Salon',
            'interest_count': 0,
          }
        ];

        final salons = InviteService.parseSalonList(json);
        expect(salons, hasLength(1));
        expect(salons[0].phone, isNull);
        expect(salons[0].whatsapp, isNull);
        expect(salons[0].address, isNull);
        expect(salons[0].city, isNull);
        expect(salons[0].photoUrl, isNull);
        expect(salons[0].rating, isNull);
        expect(salons[0].reviewsCount, isNull);
        expect(salons[0].distanceKm, isNull);
      });
    });

    group('InviteException', () {
      test('toString returns message', () {
        final ex = InviteException('test error', statusCode: 500);
        expect(ex.toString(), equals('test error'));
        expect(ex.statusCode, equals(500));
      });

      test('default statusCode is 0', () {
        final ex = InviteException('oops');
        expect(ex.statusCode, equals(0));
      });
    });
  });
}
