import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_thread.dart';
import '../models/chat_message.dart';
import '../services/aphrodite_service.dart';
import '../services/supabase_client.dart';

/// AphroditeService singleton provider.
final aphroditeServiceProvider = Provider<AphroditeService>((ref) {
  return AphroditeService();
});

/// Stream of all chat threads for the current user, ordered by pinned DESC, last_message_at DESC.
final chatThreadsProvider = StreamProvider<List<ChatThread>>((ref) {
  if (!SupabaseClientService.isInitialized) {
    return Stream.value([]);
  }
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return Stream.value([]);

  final client = SupabaseClientService.client;
  return client
      .from('chat_threads')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((rows) {
    final threads = rows
        .where((r) => r['archived_at'] == null) // Hide archived threads
        .map((r) => ChatThread.fromJson(r))
        .toList();
    // Sort: pinned first, then by last_message_at descending
    threads.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return threads;
  });
});

/// Stream of messages for a specific thread, ordered by created_at ascending.
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, threadId) {
  if (!SupabaseClientService.isInitialized) {
    return Stream.value([]);
  }

  final client = SupabaseClientService.client;
  return client
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('thread_id', threadId)
      .map((rows) {
    final messages = rows.map((r) => ChatMessage.fromJson(r)).toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  });
});

/// Ensures an Aphrodite thread exists for the current user.
/// Creates one if needed (with welcome message).
final aphroditeThreadProvider = FutureProvider<ChatThread?>((ref) async {
  if (!SupabaseClientService.isInitialized) return null;
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return null;

  final service = ref.read(aphroditeServiceProvider);
  return service
      .getOrCreateAphroditeThread()
      .timeout(const Duration(seconds: 10));
});

/// State notifier for sending messages (handles loading state).
class SendMessageNotifier extends StateNotifier<AsyncValue<ChatMessage?>> {
  final AphroditeService _service;

  SendMessageNotifier(this._service) : super(const AsyncValue.data(null));

  Future<ChatMessage?> send(String threadId, String text) async {
    state = const AsyncValue.loading();
    try {
      final msg = await _service.sendMessage(threadId, text);
      state = AsyncValue.data(msg);
      return msg;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final sendMessageProvider =
    StateNotifierProvider<SendMessageNotifier, AsyncValue<ChatMessage?>>((ref) {
  final service = ref.watch(aphroditeServiceProvider);
  return SendMessageNotifier(service);
});

/// State notifier for try-on requests.
class SendTryOnNotifier extends StateNotifier<AsyncValue<ChatMessage?>> {
  final AphroditeService _service;

  SendTryOnNotifier(this._service) : super(const AsyncValue.data(null));

  Future<ChatMessage?> send(
    String threadId,
    Uint8List imageBytes,
    String stylePrompt, {
    String toolType = 'hair_color',
  }) async {
    state = const AsyncValue.loading();
    try {
      final msg = await _service.requestTryOn(threadId, imageBytes, stylePrompt, toolType: toolType);
      state = AsyncValue.data(msg);
      return msg;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final sendTryOnProvider =
    StateNotifierProvider<SendTryOnNotifier, AsyncValue<ChatMessage?>>((ref) {
  final service = ref.watch(aphroditeServiceProvider);
  return SendTryOnNotifier(service);
});

/// Get or create support thread for current user.
final supportThreadProvider = FutureProvider<ChatThread?>((ref) async {
  if (!SupabaseClientService.isInitialized) return null;
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return null;

  final client = SupabaseClientService.client;
  final token = client.auth.currentSession?.accessToken;
  if (token == null) return null;

  final res = await client.functions.invoke('support-chat',
      body: {'action': 'init'});

  if (res.status != 200) return null;
  final data = res.data as Map<String, dynamic>;
  if (data['thread'] == null) return null;
  return ChatThread.fromJson(data['thread'] as Map<String, dynamic>);
});

/// State notifier for sending support messages.
class SendSupportMessageNotifier extends StateNotifier<AsyncValue<void>> {
  SendSupportMessageNotifier() : super(const AsyncValue.data(null));

  Future<bool> send(String threadId, String message) async {
    state = const AsyncValue.loading();
    try {
      final client = SupabaseClientService.client;
      final res = await client.functions.invoke('support-chat',
          body: {'action': 'send', 'thread_id': threadId, 'message': message});

      if (res.status != 200) {
        state = AsyncValue.error('Failed to send', StackTrace.current);
        return false;
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final sendSupportMessageProvider =
    StateNotifierProvider<SendSupportMessageNotifier, AsyncValue<void>>((ref) {
  return SendSupportMessageNotifier();
});
