import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/models/chat_thread.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('ChatThread', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = chatThreadJson();
        final thread = ChatThread.fromJson(json);

        expect(thread.id, 'thread-1');
        expect(thread.userId, 'user-1');
        expect(thread.contactType, 'aphrodite');
        expect(thread.lastMessageText, 'Hola!');
        expect(thread.unreadCount, 0);
        expect(thread.pinned, isFalse);
      });

      test('defaults unreadCount to 0 when null', () {
        final json = chatThreadJson();
        json.remove('unread_count');
        final thread = ChatThread.fromJson(json);

        expect(thread.unreadCount, 0);
      });

      test('defaults pinned to false when null', () {
        final json = chatThreadJson();
        json.remove('pinned');
        final thread = ChatThread.fromJson(json);

        expect(thread.pinned, isFalse);
      });

      test('handles null lastMessageAt', () {
        final thread = ChatThread.fromJson(chatThreadJson(
          lastMessageAt: null,
        ));

        expect(thread.lastMessageAt, isNull);
      });
    });

    group('toJson', () {
      test('round-trips through fromJson', () {
        final original = chatThreadJson();
        final thread = ChatThread.fromJson(original);
        final json = thread.toJson();

        expect(json['id'], 'thread-1');
        expect(json['user_id'], 'user-1');
        expect(json['contact_type'], 'aphrodite');
        expect(json['unread_count'], 0);
        expect(json['pinned'], isFalse);
      });
    });

    group('displayName', () {
      test('returns Afrodita for aphrodite contact type', () {
        final thread = ChatThread.fromJson(chatThreadJson(contactType: 'aphrodite'));
        expect(thread.displayName, 'Afrodita');
      });

      test('returns Soporte BeautyCita for support contact type', () {
        final thread = ChatThread.fromJson(chatThreadJson(contactType: 'support'));
        expect(thread.displayName, 'Soporte BeautyCita');
      });

      test('returns Eros for support_ai contact type', () {
        final thread = ChatThread.fromJson(chatThreadJson(contactType: 'support_ai'));
        expect(thread.displayName, 'Eros');
      });

      test('returns contactName for other contact types', () {
        final thread = ChatThread.fromJson(chatThreadJson(
          contactType: 'salon',
          contactName: 'Salon Rosa',
        ));
        expect(thread.displayName, 'Salon Rosa');
      });

      test('falls back to contactId when contactName is null', () {
        final thread = ChatThread.fromJson(chatThreadJson(
          contactType: 'salon',
          contactName: null,
          contactId: 'salon-123',
        ));
        expect(thread.displayName, 'salon-123');
      });

      test('falls back to Chat when both are null', () {
        final thread = ChatThread.fromJson(chatThreadJson(
          contactType: 'salon',
          contactName: null,
          contactId: null,
        ));
        expect(thread.displayName, 'Chat');
      });
    });

    group('type checks', () {
      test('isAphrodite returns true for aphrodite type', () {
        final thread = ChatThread.fromJson(chatThreadJson(contactType: 'aphrodite'));
        expect(thread.isAphrodite, isTrue);
        expect(thread.isSupport, isFalse);
        expect(thread.isEros, isFalse);
      });

      test('isSupport returns true for support type', () {
        final thread = ChatThread.fromJson(chatThreadJson(contactType: 'support'));
        expect(thread.isSupport, isTrue);
      });

      test('isEros returns true for support_ai type', () {
        final thread = ChatThread.fromJson(chatThreadJson(contactType: 'support_ai'));
        expect(thread.isEros, isTrue);
      });
    });

    group('copyWith', () {
      test('updates lastMessageText', () {
        final thread = ChatThread.fromJson(chatThreadJson());
        final updated = thread.copyWith(lastMessageText: 'Nuevo mensaje');

        expect(updated.lastMessageText, 'Nuevo mensaje');
        expect(updated.id, thread.id);
      });

      test('updates unreadCount', () {
        final thread = ChatThread.fromJson(chatThreadJson());
        final updated = thread.copyWith(unreadCount: 5);

        expect(updated.unreadCount, 5);
      });

      test('updates openaiThreadId', () {
        final thread = ChatThread.fromJson(chatThreadJson());
        final updated = thread.copyWith(openaiThreadId: 'thread_abc');

        expect(updated.openaiThreadId, 'thread_abc');
      });

      test('preserves unchanged fields', () {
        final thread = ChatThread.fromJson(chatThreadJson(
          contactType: 'aphrodite',
          pinned: true,
        ));
        final updated = thread.copyWith(unreadCount: 3);

        expect(updated.contactType, 'aphrodite');
        expect(updated.pinned, isTrue);
      });
    });
  });
}
