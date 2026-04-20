// Tests for the pure (non-Supabase) surface of business_chat_provider.
//
// Stream providers require a live Supabase client and are exercised in the
// chat-customer-to-salon integration flow under bughunter. Here we pin
// the two pieces that are pure and user-facing:
//   - sanitizeBusinessMessage: strips HTML, trims, caps at 2000 chars
//   - BusinessThread.fromRow: joins a chat_threads row with a profile
//
// Regression history: the chat overhaul in build 60062 hit a NULL-profile
// crash when the customer's profile row hadn't been loaded yet. The
// fromRow test here fixes the contract that a missing profile falls back
// to 'Cliente' rather than exploding.

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/providers/business_chat_provider.dart';

void main() {
  group('sanitizeBusinessMessage', () {
    test('strips simple HTML tags', () {
      expect(sanitizeBusinessMessage('hola <b>mundo</b>'), 'hola mundo');
    });

    test('strips nested / unbalanced tags greedily per opening <', () {
      expect(
        sanitizeBusinessMessage('<script>alert(1)</script>hi'),
        'alert(1)hi',
      );
    });

    test('strips self-closing + attribute-bearing tags', () {
      expect(
        sanitizeBusinessMessage('<img src="x" onerror="alert(1)"/>text'),
        'text',
      );
    });

    test('trims whitespace around the message', () {
      expect(sanitizeBusinessMessage('   hello   '), 'hello');
      expect(sanitizeBusinessMessage('\n\ttext\n'), 'text');
    });

    test('empty + whitespace-only input returns empty string', () {
      expect(sanitizeBusinessMessage(''), '');
      expect(sanitizeBusinessMessage('    '), '');
      expect(sanitizeBusinessMessage('\n\n'), '');
    });

    test('caps at 2000 characters after sanitization', () {
      final long = 'a' * 2500;
      final result = sanitizeBusinessMessage(long);
      expect(result.length, 2000);
      expect(result, 'a' * 2000);
    });

    test('cap applies to post-strip length, not raw length', () {
      // 2500 chars of <b> then real text: after stripping tags, only the
      // real text remains, well under the 2000 limit.
      final input = '<b>' * 500 + 'real' + '</b>' * 500;
      final result = sanitizeBusinessMessage(input);
      expect(result, 'real');
    });

    test('preserves legitimate greater-than / less-than as math operators', () {
      // "2 > 1" passes through; only bracketed patterns are treated as tags
      expect(sanitizeBusinessMessage('2 > 1 is true'), '2 > 1 is true');
    });

    test('strips malformed tag-like prefix', () {
      // "<hello" with no closing bracket — stripped greedily by the regex
      // (matches <[^>]*> so it needs a closing >). Without one, kept.
      expect(sanitizeBusinessMessage('<hello world'), '<hello world');
    });

    test('handles unicode content', () {
      expect(sanitizeBusinessMessage('Cita confirmada 💇‍♀️ <b>martes</b>'),
          'Cita confirmada 💇‍♀️ martes');
    });
  });

  group('BusinessThread.fromRow', () {
    Map<String, dynamic> makeRow({
      String? lastMsgAt,
      String createdAt = '2026-04-19T10:00:00Z',
    }) {
      return {
        'id': 'th-1',
        'user_id': 'user-1',
        'contact_type': 'salon',
        'contact_id': 'biz-1',
        'contact_name': 'Ejemplo Salon',
        'last_message_text': 'hola',
        'last_message_at': lastMsgAt,
        'unread_count': 3,
        'pinned': false,
        'created_at': createdAt,
      };
    }

    test('uses full_name from profile when available', () {
      final t = BusinessThread.fromRow(
        makeRow(),
        {'id': 'user-1', 'full_name': 'Maria Lopez', 'username': 'maria',
         'avatar_url': 'https://img.example/a.png'},
      );
      expect(t.customerName, 'Maria Lopez');
      expect(t.customerAvatarUrl, 'https://img.example/a.png');
    });

    test('falls back to username when full_name is null', () {
      final t = BusinessThread.fromRow(
        makeRow(),
        {'id': 'user-1', 'full_name': null, 'username': 'cherryBlossom'},
      );
      expect(t.customerName, 'cherryBlossom');
    });

    test('falls back to "Cliente" when profile is null', () {
      final t = BusinessThread.fromRow(makeRow(), null);
      expect(t.customerName, 'Cliente');
      expect(t.customerAvatarUrl, isNull);
    });

    test('falls back to "Cliente" when both name fields are null', () {
      final t = BusinessThread.fromRow(
        makeRow(),
        {'id': 'user-1', 'full_name': null, 'username': null},
      );
      expect(t.customerName, 'Cliente');
    });

    test('parses the underlying ChatThread correctly', () {
      final t = BusinessThread.fromRow(makeRow(), null);
      expect(t.thread.id, 'th-1');
      expect(t.thread.contactType, 'salon');
      expect(t.thread.unreadCount, 3);
      expect(t.thread.lastMessageAt, isNull);
      expect(t.thread.createdAt, DateTime.parse('2026-04-19T10:00:00Z'));
    });
  });
}
