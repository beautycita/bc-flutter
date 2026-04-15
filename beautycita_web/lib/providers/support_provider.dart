import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/models.dart';

// ── Tab state ────────────────────────────────────────────────────────────────

enum SupportTab { eros, human }

final supportTabProvider = StateProvider<SupportTab>((ref) => SupportTab.eros);

// ── Eros thread ──────────────────────────────────────────────────────────────

final erosThreadProvider = FutureProvider<ChatThread?>((ref) async {
  if (!BCSupabase.isInitialized || !BCSupabase.isAuthenticated) return null;
  try {
    final response = await BCSupabase.client.functions.invoke(
      'eros-chat',
      body: {'action': 'init'},
    );
    if (response.status != 200) return null;
    final data = response.data as Map<String, dynamic>;
    if (data['thread'] == null) return null;
    return ChatThread.fromJson(data['thread'] as Map<String, dynamic>);
  } catch (e) {
    debugPrint('erosThreadProvider error: $e');
    return null;
  }
});

// ── Human support thread ─────────────────────────────────────────────────────

final humanSupportThreadProvider = FutureProvider<ChatThread?>((ref) async {
  if (!BCSupabase.isInitialized || !BCSupabase.isAuthenticated) return null;
  try {
    final response = await BCSupabase.client.functions.invoke(
      'support-chat',
      body: {'action': 'init'},
    );
    if (response.status != 200) return null;
    final data = response.data as Map<String, dynamic>;
    if (data['thread'] == null) return null;
    return ChatThread.fromJson(data['thread'] as Map<String, dynamic>);
  } catch (e) {
    debugPrint('humanSupportThreadProvider error: $e');
    return null;
  }
});

// ── Chat messages (fetch-based, invalidated after send) ──────────────────────

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, threadId) async {
  if (!BCSupabase.isInitialized) return [];

  final data = await BCSupabase.client
      .from(BCTables.chatMessages)
      .select()
      .eq('thread_id', threadId)
      .order('created_at', ascending: true)
      .limit(100);

  return (data as List)
      .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Send message ─────────────────────────────────────────────────────────────

@immutable
class SendState {
  final bool isSending;
  final String? error;

  const SendState({this.isSending = false, this.error});
}

class SendErosMessageNotifier extends StateNotifier<SendState> {
  final Ref _ref;

  SendErosMessageNotifier(this._ref) : super(const SendState());

  Future<String?> send(String threadId, String text) async {
    state = const SendState(isSending: true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'eros-chat',
        body: {
          'action': 'send_message',
          'thread_id': threadId,
          'message': text,
        },
      );
      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        state = SendState(error: data?['error'] as String? ?? 'Error');
        return null;
      }
      final data = response.data as Map<String, dynamic>;
      state = const SendState();
      // Refresh messages
      _ref.invalidate(chatMessagesProvider(threadId));
      return data['response'] as String?;
    } catch (e) {
      state = SendState(error: e.toString());
      return null;
    }
  }
}

final sendErosMessageProvider =
    StateNotifierProvider<SendErosMessageNotifier, SendState>((ref) {
  return SendErosMessageNotifier(ref);
});

class SendHumanMessageNotifier extends StateNotifier<SendState> {
  final Ref _ref;

  SendHumanMessageNotifier(this._ref) : super(const SendState());

  Future<bool> send(String threadId, String text) async {
    state = const SendState(isSending: true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'support-chat',
        body: {
          'action': 'send',
          'thread_id': threadId,
          'message': text,
        },
      );
      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        state = SendState(error: data?['error'] as String? ?? 'Error');
        return false;
      }
      state = const SendState();
      // Refresh messages
      _ref.invalidate(chatMessagesProvider(threadId));
      return true;
    } catch (e) {
      state = SendState(error: e.toString());
      return false;
    }
  }
}

final sendHumanMessageProvider =
    StateNotifierProvider<SendHumanMessageNotifier, SendState>((ref) {
  return SendHumanMessageNotifier(ref);
});
