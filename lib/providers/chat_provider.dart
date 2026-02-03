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
    return const Stream.empty();
  }
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return const Stream.empty();

  final client = SupabaseClientService.client;
  return client
      .from('chat_threads')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((rows) {
    final threads = rows.map((r) => ChatThread.fromJson(r)).toList();
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
    return const Stream.empty();
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
  return service.getOrCreateAphroditeThread();
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
    String stylePrompt,
  ) async {
    state = const AsyncValue.loading();
    try {
      final msg = await _service.requestTryOn(threadId, imageBytes, stylePrompt);
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
