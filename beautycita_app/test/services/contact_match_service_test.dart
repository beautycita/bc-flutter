import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/services/contact_match_service.dart';

void main() {
  group('normalizePhone', () {
    test('full MX number with +52', () {
      expect(
        ContactMatchService.normalizePhone('+52 322 123 4567'),
        '+523221234567',
      );
    });
    test('MX local 10 digits', () {
      expect(
        ContactMatchService.normalizePhone('3221234567'),
        '+523221234567',
      );
    });
    test('with dashes', () {
      expect(
        ContactMatchService.normalizePhone('322-123-4567'),
        '+523221234567',
      );
    });
    test('with parentheses', () {
      expect(
        ContactMatchService.normalizePhone('(322) 123 4567'),
        '+523221234567',
      );
    });
    test('52 prefix no plus', () {
      expect(
        ContactMatchService.normalizePhone('52 322 123 4567'),
        '+523221234567',
      );
    });
    test('US number preserved', () {
      expect(
        ContactMatchService.normalizePhone('+1 555 123 4567'),
        '+15551234567',
      );
    });
    test('11 digit US number', () {
      expect(
        ContactMatchService.normalizePhone('15551234567'),
        '+15551234567',
      );
    });
    test('strips special chars', () {
      expect(
        ContactMatchService.normalizePhone('+52 (322) 123-4567'),
        '+523221234567',
      );
    });
  });

  group('matchContacts', () {
    final salonPhones = {
      '+523221234567': const SalonPhoneEntry(
        id: 'salon-1',
        phone: '+523221234567',
        type: 'd',
      ),
      '+523229876543': const SalonPhoneEntry(
        id: 'salon-2',
        phone: '+523229876543',
        type: 'r',
      ),
    };

    test('matches contact with salon', () {
      final contacts = [
        const ContactEntry(
          displayName: 'Mi Estilista',
          phones: ['+523221234567'],
        ),
      ];
      final matches = ContactMatchService.matchContacts(contacts, salonPhones);
      expect(matches.length, 1);
      expect(matches[0].salonId, 'salon-1');
      expect(matches[0].salonType, 'd');
      expect(matches[0].contactName, 'Mi Estilista');
    });

    test('no match returns empty', () {
      final contacts = [
        const ContactEntry(
          displayName: 'Random',
          phones: ['+529991112222'],
        ),
      ];
      final matches = ContactMatchService.matchContacts(contacts, salonPhones);
      expect(matches, isEmpty);
    });

    test('deduplicates by salon id', () {
      final contacts = [
        const ContactEntry(
          displayName: 'Contact 1',
          phones: ['+523221234567'],
        ),
        const ContactEntry(
          displayName: 'Contact 2',
          phones: ['+523221234567'],
        ),
      ];
      final matches = ContactMatchService.matchContacts(contacts, salonPhones);
      expect(matches.length, 1);
    });

    test('multiple matches for different salons', () {
      final contacts = [
        const ContactEntry(
          displayName: 'Salon A',
          phones: ['+523221234567'],
        ),
        const ContactEntry(
          displayName: 'Salon B',
          phones: ['+523229876543'],
        ),
      ];
      final matches = ContactMatchService.matchContacts(contacts, salonPhones);
      expect(matches.length, 2);
    });

    test('contact with multiple phones matches first', () {
      final contacts = [
        const ContactEntry(
          displayName: 'Multi',
          phones: ['+529990001111', '+523221234567'],
        ),
      ];
      final matches = ContactMatchService.matchContacts(contacts, salonPhones);
      expect(matches.length, 1);
      expect(matches[0].matchedPhone, '+523221234567');
    });
  });

  group('ContactMatch serialization', () {
    test('toJson and fromJson roundtrip', () {
      const match = ContactMatch(
        contactName: 'Test',
        salonId: 'id-1',
        salonType: 'd',
        matchedPhone: '+523221234567',
      );
      final json = match.toJson();
      final restored = ContactMatch.fromJson(json);
      expect(restored.contactName, 'Test');
      expect(restored.salonId, 'id-1');
      expect(restored.salonType, 'd');
    });
  });
}
