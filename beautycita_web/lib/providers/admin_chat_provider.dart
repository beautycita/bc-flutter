import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Thread list ───────────────────────────────────────────────────────────────

final adminChatThreadsProvider =
    FutureProvider<List<ChatThread>>((ref) async {
  if (!BCSupabase.isInitialized) return [];
  final user = BCSupabase.client.auth.currentUser;
  if (user == null) return [];

  final data = await BCSupabase.client
      .from('chat_threads')
      .select()
      .inFilter('contact_type', ['support', 'support_ai', 'salon'])
      .order('last_message_at', ascending: false, nullsFirst: false)
      .limit(200);

  return (data as List)
      .map((e) => ChatThread.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Selected thread ───────────────────────────────────────────────────────────

final adminSelectedThreadProvider = StateProvider<ChatThread?>((ref) => null);

// ── Messages for selected thread ──────────────────────────────────────────────

final adminChatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, threadId) async {
  if (!BCSupabase.isInitialized) return [];
  final user = BCSupabase.client.auth.currentUser;
  if (user == null) return [];

  final data = await BCSupabase.client
      .from('chat_messages')
      .select()
      .eq('thread_id', threadId)
      .order('created_at', ascending: true)
      .limit(200);

  return (data as List)
      .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Send message ──────────────────────────────────────────────────────────────

@immutable
class AdminChatSendState {
  final bool isSending;
  final String? error;

  const AdminChatSendState({this.isSending = false, this.error});
}

class AdminChatSendNotifier extends StateNotifier<AdminChatSendState> {
  final Ref _ref;

  AdminChatSendNotifier(this._ref) : super(const AdminChatSendState());

  Future<bool> send(String threadId, String text) async {
    if (text.trim().isEmpty) return false;
    state = const AdminChatSendState(isSending: true);
    try {
      await BCSupabase.client.from('chat_messages').insert({
        'thread_id': threadId,
        'sender_type': 'support',
        'sender_id': BCSupabase.client.auth.currentUser?.id,
        'content_type': 'text',
        'text_content': text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      state = const AdminChatSendState();
      _ref.invalidate(adminChatMessagesProvider(threadId));
      _ref.invalidate(adminChatThreadsProvider);
      return true;
    } catch (e) {
      debugPrint('AdminChatSendNotifier.send error: $e');
      state = AdminChatSendState(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = const AdminChatSendState();
  }
}

final adminChatSendProvider =
    StateNotifierProvider<AdminChatSendNotifier, AdminChatSendState>((ref) {
  return AdminChatSendNotifier(ref);
});

// ── Thread filter ─────────────────────────────────────────────────────────────

final adminChatSearchProvider = StateProvider<String>((ref) => '');
