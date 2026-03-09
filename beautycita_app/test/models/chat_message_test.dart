import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/models/chat_message.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('ChatMessage', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = chatMessageJson();
        final msg = ChatMessage.fromJson(json);

        expect(msg.id, 'msg-1');
        expect(msg.threadId, 'thread-1');
        expect(msg.senderType, 'user');
        expect(msg.senderId, 'user-1');
        expect(msg.contentType, 'text');
        expect(msg.textContent, 'Hola!');
        expect(msg.mediaUrl, isNull);
        expect(msg.metadata, isEmpty);
        expect(msg.createdAt, DateTime.utc(2026, 3, 5, 10));
      });

      test('defaults contentType to text when null', () {
        final json = chatMessageJson();
        json.remove('content_type');
        final msg = ChatMessage.fromJson(json);

        expect(msg.contentType, 'text');
      });

      test('defaults metadata to empty map when null', () {
        final json = chatMessageJson();
        json.remove('metadata');
        final msg = ChatMessage.fromJson(json);

        expect(msg.metadata, isEmpty);
      });
    });

    group('toJson', () {
      test('round-trips through fromJson', () {
        final original = chatMessageJson(
          textContent: 'Test message',
          metadata: {'key': 'value'},
        );
        final msg = ChatMessage.fromJson(original);
        final json = msg.toJson();

        expect(json['id'], 'msg-1');
        expect(json['thread_id'], 'thread-1');
        expect(json['sender_type'], 'user');
        expect(json['text_content'], 'Test message');
        expect(json['metadata'], {'key': 'value'});
        expect(json['created_at'], contains('2026-03-05'));
      });
    });

    group('computed properties', () {
      test('isFromUser returns true for user sender', () {
        final msg = ChatMessage.fromJson(chatMessageJson(senderType: 'user'));
        expect(msg.isFromUser, isTrue);
        expect(msg.isFromAphrodite, isFalse);
      });

      test('isFromAphrodite returns true for aphrodite sender', () {
        final msg = ChatMessage.fromJson(chatMessageJson(senderType: 'aphrodite'));
        expect(msg.isFromAphrodite, isTrue);
        expect(msg.isFromUser, isFalse);
      });

      test('isFromSupport returns true for support sender', () {
        final msg = ChatMessage.fromJson(chatMessageJson(senderType: 'support'));
        expect(msg.isFromSupport, isTrue);
      });

      test('isFromEros returns true for eros sender', () {
        final msg = ChatMessage.fromJson(chatMessageJson(senderType: 'eros'));
        expect(msg.isFromEros, isTrue);
      });

      test('hasMedia is true when mediaUrl is set', () {
        final msg = ChatMessage.fromJson(chatMessageJson(
          mediaUrl: 'https://example.com/photo.jpg',
        ));
        expect(msg.hasMedia, isTrue);
      });

      test('hasMedia is false when mediaUrl is null', () {
        final msg = ChatMessage.fromJson(chatMessageJson(mediaUrl: null));
        expect(msg.hasMedia, isFalse);
      });

      test('hasMedia is false when mediaUrl is empty', () {
        final msg = ChatMessage.fromJson(chatMessageJson(mediaUrl: ''));
        expect(msg.hasMedia, isFalse);
      });

      test('isTryOnResult matches tryon_result content type', () {
        final msg = ChatMessage.fromJson(chatMessageJson(contentType: 'tryon_result'));
        expect(msg.isTryOnResult, isTrue);
      });

      test('isPreferenceCard matches preference_card content type', () {
        final msg = ChatMessage.fromJson(chatMessageJson(contentType: 'preference_card'));
        expect(msg.isPreferenceCard, isTrue);
      });
    });
  });
}
