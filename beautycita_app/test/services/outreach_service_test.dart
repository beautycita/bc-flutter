// Behavior tests for OutreachService models + pure helpers.
//
// Network-touching methods (listTemplates, countEligible, enqueueBulk, etc.)
// require a Supabase client and live edge functions; bughunter exercises
// those end-to-end. This file covers the pure logic that doesn't:
//
//   - JSON deserialization for OutreachTemplate / EligibilityCounts /
//     OutreachPreview / BulkJobStatus.
//   - BulkJobStatus computed getters: isActive, processed, progress.
//   - OutreachService.gatingBlockReason() decision matrix.
//   - OutreachException toString shape.

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/services/outreach_service.dart';

void main() {
  group('OutreachException', () {
    test('toString includes status code and message', () {
      final e = OutreachException('boom', statusCode: 500);
      expect(e.toString(), 'OutreachException(500): boom');
    });
  });

  group('OutreachTemplate.fromJson', () {
    test('parses required + optional fields', () {
      final t = OutreachTemplate.fromJson({
        'id': 't1',
        'name': 'Welcome',
        'channel': 'whatsapp',
        'subject': null,
        'body_template': 'Hola {{salon_name}}',
        'category': 'invite',
        'recipient_table': 'discovered_salons',
        'is_invite': true,
        'required_variables': ['salon_name'],
        'manual_variables': ['custom_msg'],
        'gating_rule': {'min_rating': 4.0},
      });
      expect(t.id, 't1');
      expect(t.channel, 'whatsapp');
      expect(t.body, 'Hola {{salon_name}}');
      expect(t.isInvite, true);
      expect(t.requiredVariables, ['salon_name']);
      expect(t.manualVariables, ['custom_msg']);
      expect(t.gatingRule, isNotNull);
      expect(t.gatingRule!['min_rating'], 4.0);
    });

    test('handles missing optional collections without throwing', () {
      final t = OutreachTemplate.fromJson({
        'id': 't2',
        'name': 'Bare',
        'channel': 'email',
        'body_template': 'X',
        'is_invite': false,
      });
      expect(t.subject, isNull);
      expect(t.category, isNull);
      expect(t.recipientTable, isNull);
      expect(t.requiredVariables, isEmpty);
      expect(t.manualVariables, isEmpty);
      expect(t.gatingRule, isNull);
    });

    test('prettyLabel falls back to "general" when category is null', () {
      final t = OutreachTemplate.fromJson({
        'id': 't3', 'name': 'No-cat', 'channel': 'email',
        'body_template': '', 'is_invite': false,
      });
      expect(t.prettyLabel, 'No-cat · general');
    });

    test('drops non-string entries from variables lists', () {
      final t = OutreachTemplate.fromJson({
        'id': 't4', 'name': 'Mixed', 'channel': 'email',
        'body_template': '', 'is_invite': false,
        'required_variables': ['ok', 42, null, 'also_ok'],
      });
      expect(t.requiredVariables, ['ok', 'also_ok']);
    });
  });

  group('EligibilityCounts.fromJson', () {
    test('parses numeric fields with int coercion', () {
      final c = EligibilityCounts.fromJson({
        'eligible': 7,
        'opted_out': 1,
        'cooldown': 2,
        'no_channel': 3,
        'total': 13,
      });
      expect(c.eligible, 7);
      expect(c.optedOut, 1);
      expect(c.cooldown, 2);
      expect(c.noChannel, 3);
      expect(c.total, 13);
    });

    test('defaults missing fields to 0', () {
      final c = EligibilityCounts.fromJson({});
      expect(c.eligible, 0);
      expect(c.total, 0);
    });
  });

  group('OutreachPreview.fromJson', () {
    test('parses with all flags', () {
      final p = OutreachPreview.fromJson({
        'subject': 's', 'body': 'b',
        'salon_name': 'n', 'unsubscribe_link': 'u',
        'opted_out': true, 'cooldown_active': false,
        'has_phone': true, 'has_email': false,
      });
      expect(p.optedOut, true);
      expect(p.cooldownActive, false);
      expect(p.hasPhone, true);
      expect(p.hasEmail, false);
    });

    test('defaults flags to false / strings to empty when missing', () {
      final p = OutreachPreview.fromJson({'body': 'only-body'});
      expect(p.subject, isNull);
      expect(p.salonName, '');
      expect(p.unsubscribeLink, '');
      expect(p.optedOut, false);
      expect(p.hasPhone, false);
    });
  });

  group('BulkJobStatus computed getters', () {
    BulkJobStatus mk({
      String status = 'queued', int total = 100,
      int sent = 0, int skipped = 0, int failed = 0,
    }) =>
        BulkJobStatus.fromJson({
          'id': 'j1', 'status': status, 'channel': 'whatsapp',
          'total_count': total, 'sent_count': sent,
          'skipped_count': skipped, 'failed_count': failed,
          'template_name': 'tpl', 'created_at': '2026-05-01T00:00:00Z',
        });

    test('isActive true for queued + draining', () {
      expect(mk(status: 'queued').isActive, true);
      expect(mk(status: 'draining').isActive, true);
    });

    test('isActive false for terminal states', () {
      expect(mk(status: 'completed').isActive, false);
      expect(mk(status: 'cancelled').isActive, false);
      expect(mk(status: 'failed').isActive, false);
    });

    test('processed sums sent + skipped + failed', () {
      expect(mk(sent: 10, skipped: 5, failed: 2).processed, 17);
    });

    test('progress is processed/total', () {
      expect(mk(total: 100, sent: 25).progress, closeTo(0.25, 1e-9));
    });

    test('progress is 0 when total is 0 (no division by zero)', () {
      expect(mk(total: 0, sent: 0).progress, 0);
    });
  });

  group('OutreachService.gatingBlockReason', () {
    final templateNoGate = OutreachTemplate.fromJson({
      'id': 't', 'name': 'n', 'channel': 'email',
      'body_template': '', 'is_invite': false,
    });

    OutreachTemplate withGate(Map<String, dynamic> rule) =>
        OutreachTemplate.fromJson({
          'id': 't', 'name': 'n', 'channel': 'email',
          'body_template': '', 'is_invite': false, 'gating_rule': rule,
        });

    test('null gating rule => allowed (returns null)', () {
      expect(
        OutreachService.gatingBlockReason(template: templateNoGate, row: {}),
        isNull,
      );
    });

    test('min_interest_count: blocks when below', () {
      final reason = OutreachService.gatingBlockReason(
        template: withGate({'min_interest_count': 5}),
        row: {'interest_count': 2},
      );
      expect(reason, isNotNull);
      expect(reason, contains('5'));
      expect(reason, contains('2'));
    });

    test('min_interest_count: allows when meeting threshold', () {
      expect(
        OutreachService.gatingBlockReason(
          template: withGate({'min_interest_count': 5}),
          row: {'interest_count': 5},
        ),
        isNull,
      );
    });

    test('min_rating: rating_average preferred, falls back to average_rating', () {
      // Primary key takes precedence.
      expect(
        OutreachService.gatingBlockReason(
          template: withGate({'min_rating': 4.0}),
          row: {'rating_average': 4.5, 'average_rating': 1.0},
        ),
        isNull,
      );
      // Falls back to average_rating when rating_average missing.
      expect(
        OutreachService.gatingBlockReason(
          template: withGate({'min_rating': 4.0}),
          row: {'average_rating': 4.5},
        ),
        isNull,
      );
      // Both missing => 0 < 4 => blocked.
      final reason = OutreachService.gatingBlockReason(
        template: withGate({'min_rating': 4.0}),
        row: {},
      );
      expect(reason, isNotNull);
    });

    test('min_review_count: rating_count preferred, falls back to total_reviews', () {
      expect(
        OutreachService.gatingBlockReason(
          template: withGate({'min_review_count': 10}),
          row: {'rating_count': 12, 'total_reviews': 1},
        ),
        isNull,
      );
      expect(
        OutreachService.gatingBlockReason(
          template: withGate({'min_review_count': 10}),
          row: {'total_reviews': 12},
        ),
        isNull,
      );
      final reason = OutreachService.gatingBlockReason(
        template: withGate({'min_review_count': 10}),
        row: {'rating_count': 3},
      );
      expect(reason, isNotNull);
      expect(reason, contains('10'));
      expect(reason, contains('3'));
    });

    test('multiple rules: first failing rule produces the reason', () {
      // Interest fails first; rating doesn't get checked because the function
      // returns on the first failure.
      final reason = OutreachService.gatingBlockReason(
        template: withGate({'min_interest_count': 5, 'min_rating': 4.0}),
        row: {'interest_count': 0, 'rating_average': 1.0},
      );
      expect(reason, isNotNull);
      expect(reason, contains('búsquedas'));
    });
  });
}
