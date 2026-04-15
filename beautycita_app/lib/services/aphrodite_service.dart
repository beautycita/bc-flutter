import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:beautycita_core/supabase.dart';
import 'supabase_client.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';

/// Service for interacting with Aphrodite AI via the aphrodite-chat edge function.
/// Uses Supabase for DB operations and edge function for AI proxy.
///
/// Updated for OpenAI Responses API - conversation history managed in Supabase.
class AphroditeService {
  static const _uuid = Uuid();

  /// Max file size for image uploads (10 MB).
  static const int _maxImageBytes = 10 * 1024 * 1024;

  /// Max length for style prompts sent to AI.
  static const int _maxStylePromptLength = 200;

  /// JPEG magic bytes (FF D8).
  static const List<int> _jpegMagic = [0xFF, 0xD8];

  /// PNG magic bytes (89 50 4E 47).
  static const List<int> _pngMagic = [0x89, 0x50, 0x4E, 0x47];

  /// Validates that [bytes] is a valid image (JPEG or PNG) under the size limit.
  /// Throws [AphroditeException] on failure.
  static void _validateImage(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw AphroditeException('La imagen esta vacia');
    }
    if (bytes.length > _maxImageBytes) {
      throw AphroditeException(
        'La imagen excede el limite de 10 MB (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)',
      );
    }
    // Check magic bytes
    final isJpeg = bytes.length >= 2 &&
        bytes[0] == _jpegMagic[0] &&
        bytes[1] == _jpegMagic[1];
    final isPng = bytes.length >= 4 &&
        bytes[0] == _pngMagic[0] &&
        bytes[1] == _pngMagic[1] &&
        bytes[2] == _pngMagic[2] &&
        bytes[3] == _pngMagic[3];
    if (!isJpeg && !isPng) {
      throw AphroditeException('Formato de imagen no soportado. Usa JPEG o PNG.');
    }
  }

  /// Regex allowing alphanumeric, spaces, basic punctuation, and Spanish characters.
  static final RegExp _allowedPromptChars = RegExp(
    r"^[a-zA-Z0-9\sáéíóúüñÁÉÍÓÚÜÑ.,;:!?¡¿()\-_/#+@&%']+$",
  );

  /// Sanitizes a style prompt: trims, limits length, strips HTML/script tags,
  /// and allows only safe characters (alphanumeric + basic punctuation + Spanish).
  static String _sanitizeStylePrompt(String raw) {
    // Strip HTML/script tags
    var cleaned = raw.replaceAll(RegExp(r'<[^>]*>'), '');
    // Trim and limit length
    cleaned = cleaned.trim();
    if (cleaned.length > _maxStylePromptLength) {
      cleaned = cleaned.substring(0, _maxStylePromptLength);
    }
    // Reject if it contains non-allowed characters
    if (cleaned.isNotEmpty && !_allowedPromptChars.hasMatch(cleaned)) {
      // Remove disallowed characters instead of rejecting entirely
      cleaned = cleaned.replaceAll(
        RegExp(r'[^a-zA-Z0-9\sáéíóúüñÁÉÍÓÚÜÑ.,;:!?¡¿()\-_/#+@&%\x27"]'),
        '',
      );
    }
    return cleaned;
  }

  /// Sends a text message to Aphrodite.
  /// The edge function handles thread creation, message saving, and AI response.
  /// Returns the AI response message.
  Future<ChatMessage> sendMessage(String? threadId, String text) async {
    final client = SupabaseClientService.client;

    // Call edge function - it handles everything
    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: {
        'action': 'send_message',
        'thread_id': threadId,
        'message': text,
        'language': 'es',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw AphroditeException(
        'Failed to send message: $error',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    final responseText = data['response'] as String;
    final actualThreadId = data['thread_id'] as String;
    final responseId = data['response_id'] as String?;

    // Return the response as a ChatMessage
    return ChatMessage(
      id: responseId ?? _uuid.v4(),
      threadId: actualThreadId,
      senderType: 'aphrodite',
      contentType: 'text',
      textContent: responseText,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Requests a virtual try-on via the edge function.
  /// Uploads image, calls LightX through edge function, inserts result message.
  Future<ChatMessage> requestTryOn(
    String threadId,
    Uint8List imageBytes,
    String stylePrompt, {
    String toolType = 'hair_color',
  }) async {
    // Validate image size and format before uploading
    _validateImage(imageBytes);

    // Sanitize the style prompt
    stylePrompt = _sanitizeStylePrompt(stylePrompt);
    if (stylePrompt.isEmpty) {
      throw AphroditeException('El prompt de estilo no puede estar vacio');
    }

    final client = SupabaseClientService.client;
    final now = DateTime.now().toUtc();

    // Insert a "trying on" system message
    final tryingMsgId = _uuid.v4();
    await client.from(BCTables.chatMessages).insert({
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
        'tool_type': toolType,
        'style_prompt': stylePrompt,
        'thread_id': threadId,
      },
    ).timeout(const Duration(seconds: 30));

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

    await client.from(BCTables.chatMessages).insert({
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
    await client.from(BCTables.chatThreads).update({
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

    await client.from(BCTables.chatMessages).insert({
      'id': msgId,
      'thread_id': threadId,
      'sender_type': senderType,
      'content_type': contentType,
      'text_content': textContent,
      'metadata': metadata,
      'created_at': now.toIso8601String(),
    });

    if (textContent != null) {
      await client.from(BCTables.chatThreads).update({
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

  /// Updates a message's metadata (e.g. to mark a preference card as answered).
  Future<void> updateMessageMetadata(
      String messageId, Map<String, dynamic> metadata) async {
    final client = SupabaseClientService.client;
    await client
        .from(BCTables.chatMessages)
        .update({'metadata': metadata}).eq('id', messageId);
  }

  /// Generates AI copy for a field (bio, service description, etc.).
  /// Returns the generated text string.
  Future<String> generateCopy({
    required String fieldType,
    Map<String, String> context = const {},
  }) async {
    final client = SupabaseClientService.client;

    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: {
        'action': 'generate_copy',
        'field_type': fieldType,
        'context': context,
      },
    ).timeout(const Duration(seconds: 15));

    if (response.status == 429) {
      final data = response.data as Map<String, dynamic>;
      throw AphroditeException(
        data['text'] as String? ?? 'Rate limited',
        statusCode: 429,
      );
    }

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw AphroditeException(
        'Copy generation failed: $error',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    return data['text'] as String? ?? '';
  }

  /// Archives a thread (soft-delete). Messages stay in DB but thread is hidden.
  Future<void> deleteThread(String threadId) async {
    final client = SupabaseClientService.client;
    await client.from(BCTables.chatThreads).update({
      'archived_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', threadId);
  }

  /// Gets or creates the Aphrodite thread for the current user.
  /// The edge function will create the thread if needed on first message.
  Future<ChatThread?> getAphroditeThread() async {
    final client = SupabaseClientService.client;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      throw AphroditeException('Not authenticated');
    }

    // Check if aphrodite thread already exists (non-archived)
    final existing = await client
        .from(BCTables.chatThreads)
        .select()
        .eq('user_id', userId)
        .eq('contact_type', 'aphrodite')
        .isFilter('archived_at', null)
        .maybeSingle()
        .timeout(const Duration(seconds: 8));

    if (existing != null) {
      return ChatThread.fromJson(existing);
    }

    return null; // Thread will be created on first message
  }

  /// Creates Aphrodite thread with welcome message.
  /// Called when user first opens Aphrodite chat.
  Future<ChatThread> createAphroditeThread() async {
    final client = SupabaseClientService.client;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      throw AphroditeException('Not authenticated');
    }

    final threadId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // Welcome message from Aphrodite
    const welcomeText =
        '*suspiro divino* Ay, otro mortal que busca mi guía... '
        'Bueno, supongo que es mi deber celestial ayudarte. '
        'Soy Afrodita, tu asesora de belleza. '
        'Pregúntame lo que quieras sobre belleza, '
        'o mándame una selfie y te digo qué hacer con... bueno, con todo eso. 💅✨';

    // Create thread
    await client.from(BCTables.chatThreads).insert({
      'id': threadId,
      'user_id': userId,
      'contact_type': 'aphrodite',
      'pinned': true,
      'last_message_text': welcomeText,
      'last_message_at': now.toIso8601String(),
      'created_at': now.toIso8601String(),
    }).timeout(const Duration(seconds: 8));

    // Insert welcome message
    await client.from(BCTables.chatMessages).insert({
      'id': _uuid.v4(),
      'thread_id': threadId,
      'sender_type': 'aphrodite',
      'content_type': 'text',
      'text_content': welcomeText,
      'created_at': now.toIso8601String(),
    }).timeout(const Duration(seconds: 8));

    return ChatThread(
      id: threadId,
      userId: userId,
      contactType: 'aphrodite',
      lastMessageText: welcomeText,
      lastMessageAt: now,
      unreadCount: 1,
      pinned: true,
      createdAt: now,
    );
  }

  /// Gets or creates the Aphrodite thread for the current user.
  Future<ChatThread> getOrCreateAphroditeThread() async {
    final existing = await getAphroditeThread();
    if (existing != null) {
      return existing;
    }
    return createAphroditeThread();
  }
}

class AphroditeException implements Exception {
  final String message;
  final int statusCode;

  AphroditeException(this.message, {this.statusCode = 0});

  @override
  String toString() => message;
}
