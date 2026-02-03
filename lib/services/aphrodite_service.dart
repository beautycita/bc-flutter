import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'supabase_client.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';

/// Service for interacting with Aphrodite AI via the aphrodite-chat edge function.
/// Uses Supabase for DB operations and edge function for AI proxy.
class AphroditeService {
  static const _uuid = Uuid();

  /// Creates a new Aphrodite chat thread for the given user.
  /// Calls the edge function to create an OpenAI thread, then inserts into DB.
  Future<ChatThread> createThread(String userId) async {
    final client = SupabaseClientService.client;

    // Call edge function to create OpenAI thread
    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: {'action': 'create_thread', 'language': 'es'},
    );

    if (response.status != 200) {
      throw AphroditeException(
        'Failed to create thread: ${response.status}',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    final openaiThreadId = data['thread_id'] as String;

    // Insert thread into DB
    final threadId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await client.from('chat_threads').insert({
      'id': threadId,
      'user_id': userId,
      'contact_type': 'aphrodite',
      'openai_thread_id': openaiThreadId,
      'pinned': true,
      'last_message_at': now.toIso8601String(),
      'created_at': now.toIso8601String(),
    });

    // Insert welcome message from Aphrodite
    const welcomeText =
        '*suspiro divino* Ay, otro mortal que busca mi guía... '
        'Bueno, supongo que es mi deber celestial ayudarte. '
        'Soy Afrodita, tu asesora de belleza. '
        'Pregúntame lo que quieras sobre belleza, '
        'o mándame una selfie y te digo qué hacer con... bueno, con todo eso. 💅✨';

    await client.from('chat_messages').insert({
      'id': _uuid.v4(),
      'thread_id': threadId,
      'sender_type': 'aphrodite',
      'content_type': 'text',
      'text_content': welcomeText,
      'created_at': now.toIso8601String(),
    });

    // Update thread last message
    await client.from('chat_threads').update({
      'last_message_text': welcomeText,
      'last_message_at': now.toIso8601String(),
    }).eq('id', threadId);

    return ChatThread(
      id: threadId,
      userId: userId,
      contactType: 'aphrodite',
      openaiThreadId: openaiThreadId,
      lastMessageText: welcomeText,
      lastMessageAt: now,
      unreadCount: 1,
      pinned: true,
      createdAt: now,
    );
  }

  /// Sends a text message to an Aphrodite thread.
  /// Inserts user message, calls edge function, inserts response.
  Future<ChatMessage> sendMessage(String threadId, String text) async {
    final client = SupabaseClientService.client;
    final userId = SupabaseClientService.currentUserId;
    final now = DateTime.now().toUtc();

    // Insert user message into DB
    final userMsgId = _uuid.v4();
    await client.from('chat_messages').insert({
      'id': userMsgId,
      'thread_id': threadId,
      'sender_type': 'user',
      'sender_id': userId,
      'content_type': 'text',
      'text_content': text,
      'created_at': now.toIso8601String(),
    });

    // Update thread last message
    await client.from('chat_threads').update({
      'last_message_text': text,
      'last_message_at': now.toIso8601String(),
    }).eq('id', threadId);

    // Get the OpenAI thread ID
    final threadData = await client
        .from('chat_threads')
        .select('openai_thread_id')
        .eq('id', threadId)
        .single();
    final openaiThreadId = threadData['openai_thread_id'] as String;

    // Call edge function
    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: {
        'action': 'send_message',
        'thread_id': openaiThreadId,
        'message': text,
      },
    );

    if (response.status != 200) {
      throw AphroditeException(
        'Failed to send message: ${response.status}',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    final responseText = data['response'] as String;

    // Insert Aphrodite response into DB
    final responseMsgId = _uuid.v4();
    final responseTime = DateTime.now().toUtc();

    await client.from('chat_messages').insert({
      'id': responseMsgId,
      'thread_id': threadId,
      'sender_type': 'aphrodite',
      'content_type': 'text',
      'text_content': responseText,
      'created_at': responseTime.toIso8601String(),
    });

    // Update thread
    await client.from('chat_threads').update({
      'last_message_text': responseText,
      'last_message_at': responseTime.toIso8601String(),
      'unread_count': 0,
    }).eq('id', threadId);

    return ChatMessage(
      id: responseMsgId,
      threadId: threadId,
      senderType: 'aphrodite',
      contentType: 'text',
      textContent: responseText,
      createdAt: responseTime,
    );
  }

  /// Requests a virtual try-on via the edge function.
  /// Uploads image, calls LightX through edge function, inserts result message.
  Future<ChatMessage> requestTryOn(
    String threadId,
    Uint8List imageBytes,
    String stylePrompt,
  ) async {
    final client = SupabaseClientService.client;
    final now = DateTime.now().toUtc();

    // Insert a "trying on" system message
    final tryingMsgId = _uuid.v4();
    await client.from('chat_messages').insert({
      'id': tryingMsgId,
      'thread_id': threadId,
      'sender_type': 'aphrodite',
      'content_type': 'text',
      'text_content':
          'Mmm, déjame ver... *examina la foto* Espera mientras trabajo mi magia divina... ✨',
      'created_at': now.toIso8601String(),
    });

    // Call edge function with base64 image
    final imageBase64 = base64Encode(imageBytes);

    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: {
        'action': 'try_on',
        'image_base64': imageBase64,
        'style_prompt': stylePrompt,
      },
    );

    if (response.status != 200) {
      throw AphroditeException(
        'Try-on failed: ${response.status}',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    final resultUrl = data['result_url'] as String;

    // Insert try-on result message
    final resultMsgId = _uuid.v4();
    final resultTime = DateTime.now().toUtc();

    await client.from('chat_messages').insert({
      'id': resultMsgId,
      'thread_id': threadId,
      'sender_type': 'aphrodite',
      'content_type': 'tryon_result',
      'media_url': resultUrl,
      'text_content': stylePrompt,
      'metadata': {'style_prompt': stylePrompt},
      'created_at': resultTime.toIso8601String(),
    });

    // Update thread
    await client.from('chat_threads').update({
      'last_message_text': '📸 Prueba virtual: $stylePrompt',
      'last_message_at': resultTime.toIso8601String(),
    }).eq('id', threadId);

    return ChatMessage(
      id: resultMsgId,
      threadId: threadId,
      senderType: 'aphrodite',
      contentType: 'tryon_result',
      textContent: stylePrompt,
      mediaUrl: resultUrl,
      metadata: {'style_prompt': stylePrompt},
      createdAt: resultTime,
    );
  }

  /// Inserts a local message into a thread (no edge function call).
  /// Used for onboarding flow messages that are client-side only.
  Future<ChatMessage> insertLocalMessage({
    required String threadId,
    required String senderType,
    String contentType = 'text',
    String? textContent,
    Map<String, dynamic> metadata = const {},
  }) async {
    final client = SupabaseClientService.client;
    final now = DateTime.now().toUtc();
    final msgId = _uuid.v4();

    await client.from('chat_messages').insert({
      'id': msgId,
      'thread_id': threadId,
      'sender_type': senderType,
      'content_type': contentType,
      'text_content': textContent,
      'metadata': metadata,
      'created_at': now.toIso8601String(),
    });

    if (textContent != null) {
      await client.from('chat_threads').update({
        'last_message_text': textContent,
        'last_message_at': now.toIso8601String(),
      }).eq('id', threadId);
    }

    return ChatMessage(
      id: msgId,
      threadId: threadId,
      senderType: senderType,
      contentType: contentType,
      textContent: textContent,
      metadata: metadata,
      createdAt: now,
    );
  }

  /// Gets or creates the Aphrodite thread for the current user.
  Future<ChatThread> getOrCreateAphroditeThread() async {
    final client = SupabaseClientService.client;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      throw AphroditeException('Not authenticated');
    }

    // Check if aphrodite thread already exists
    final existing = await client
        .from('chat_threads')
        .select()
        .eq('user_id', userId)
        .eq('contact_type', 'aphrodite')
        .maybeSingle();

    if (existing != null) {
      return ChatThread.fromJson(existing);
    }

    // Create new one
    return createThread(userId);
  }
}

class AphroditeException implements Exception {
  final String message;
  final int statusCode;

  AphroditeException(this.message, {this.statusCode = 0});

  @override
  String toString() => message;
}
