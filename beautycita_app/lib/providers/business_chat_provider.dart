/// Business-side chat providers.
///
/// Mirror of the customer-side chat_provider.dart but scoped to threads
/// where contact_type='salon' and contact_id matches a business the
/// authenticated user owns. RLS policies added in migration
/// 20260419000000 enforce the ownership check server-side; these
/// providers handle the client-side streaming + optimistic writes.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_thread.dart';
import '../services/supabase_client.dart';
import 'package:beautycita_core/supabase.dart';

/// Businesses owned by the current user. Stream so we react to new
/// registrations or ownership changes without a manual reload.
final ownedBusinessIdsProvider = StreamProvider<List<String>>((ref) {
  if (!SupabaseClientService.isInitialized) return Stream.value(const []);
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return Stream.value(const []);

  return SupabaseClientService.client
      .from(BCTables.businesses)
      .stream(primaryKey: ['id'])
      .eq('owner_id', userId)
      .map((rows) => rows.map((r) => r['id'] as String).toList());
});

/// Customer chat threads for every business this user owns, newest
/// message first. Works across multiple-business accounts automatically.
final businessChatThreadsProvider =
    StreamProvider<List<BusinessThread>>((ref) {
  if (!SupabaseClientService.isInitialized) return Stream.value(const []);
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return Stream.value(const []);

  final client = SupabaseClientService.client;

  // Stream every chat_threads row the caller can see. RLS already scopes
  // a business owner to threads whose contact_id is one of their shops
  // (chat_threads_business_read). We deliberately do NOT add a server-side
  // .eq('contact_type','salon') filter here: Supabase Realtime's filter
  // syntax on a non-key string column has bitten this exact screen before.
  // We filter client-side instead — RLS guarantees no leakage either way.
  return client
      .from(BCTables.chatThreads)
      .stream(primaryKey: ['id'])
      .asyncMap((allRows) async {
    final rows = allRows
        .where((r) => r['contact_type'] == 'salon')
        .toList();
    if (rows.isEmpty) return const <BusinessThread>[];

    // Hydrate customer profiles in one round-trip so the list can show
    // the customer's name + avatar rather than just a UUID. Profiles RLS
    // may strip rows we can't see — that's fine; BusinessThread.fromRow
    // falls back to "Cliente" when the profile isn't accessible.
    final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
    Map<String, Map<String, dynamic>> byId = const {};
    if (userIds.isNotEmpty) {
      try {
        final profiles = await client
            .from(BCTables.profiles)
            .select('id, username, full_name, avatar_url')
            .inFilter('id', userIds);
        byId = {
          for (final p in profiles as List)
            (p['id'] as String): p as Map<String, dynamic>,
        };
      } catch (_) {
        // Profiles fetch is best-effort; the inbox still renders without
        // names. Keep going rather than failing the whole stream.
      }
    }

    final result = rows
        .where((r) => r['archived_at'] == null)
        .map((r) => BusinessThread.fromRow(r, byId[r['user_id']]))
        .toList();

    // Newest activity first. last_message_at can be null if the thread
    // exists but no message has landed yet; fall back to created_at.
    result.sort((a, b) {
      final aTime = a.thread.lastMessageAt ?? a.thread.createdAt;
      final bTime = b.thread.lastMessageAt ?? b.thread.createdAt;
      return bTime.compareTo(aTime);
    });
    return result;
  });
});

/// Sum of unread messages across all business threads. Drives the chat
/// tab badge in business_shell_screen.
final businessTotalUnreadProvider = StreamProvider<int>((ref) {
  if (!SupabaseClientService.isInitialized) return Stream.value(0);
  // Same Realtime-filter caveat as businessChatThreadsProvider: filter
  // contact_type client-side, let RLS scope the rest server-side.
  return SupabaseClientService.client
      .from(BCTables.chatThreads)
      .stream(primaryKey: ['id'])
      .map((rows) => rows
          .where((r) =>
              r['contact_type'] == 'salon' && r['archived_at'] == null)
          .fold<int>(0, (sum, r) => sum + ((r['unread_count'] as int?) ?? 0)));
});

const int _maxMessageLength = 2000;

/// Strip angle-bracketed tags, trim whitespace, cap at 2000 chars. Exposed
/// for unit tests — callers should still go through [SendBusinessMessageNotifier].
@visibleForTesting
String sanitizeBusinessMessage(String raw) {
  var cleaned = raw.replaceAll(RegExp(r'<[^>]*>'), '');
  cleaned = cleaned.trim();
  if (cleaned.length > _maxMessageLength) {
    cleaned = cleaned.substring(0, _maxMessageLength);
  }
  return cleaned;
}

/// Send a text message as the business. sender_type='salon' is gated by
/// the chat_messages_business_insert RLS policy — the INSERT only
/// succeeds if the caller owns a business matching the thread's contact_id.
class SendBusinessMessageNotifier extends StateNotifier<AsyncValue<void>> {
  SendBusinessMessageNotifier() : super(const AsyncValue.data(null));

  Future<bool> send(String threadId, String text) async {
    final clean = sanitizeBusinessMessage(text);
    if (clean.isEmpty) return false;
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseClientService.currentUserId;
      await SupabaseClientService.client.from(BCTables.chatMessages).insert({
        'thread_id': threadId,
        'sender_type': 'salon',
        'sender_id': userId,
        'content_type': 'text',
        'text_content': clean,
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final sendBusinessMessageProvider = StateNotifierProvider<
    SendBusinessMessageNotifier, AsyncValue<void>>((ref) {
  return SendBusinessMessageNotifier();
});

/// Reset the business-side unread count on the thread when the owner
/// opens the conversation. Unread is shared by both sides today (same
/// column); when we split roles we'll add a separate unread_count_business.
Future<void> markBusinessThreadRead(String threadId) async {
  try {
    await SupabaseClientService.client
        .from(BCTables.chatThreads)
        .update({'unread_count': 0})
        .eq('id', threadId);
  } catch (_) {
    // Non-fatal; stale badge is better than crashing the UI.
  }
}

/// Thread + customer profile joined at the provider layer.
class BusinessThread {
  final ChatThread thread;
  final String customerName;
  final String? customerAvatarUrl;

  const BusinessThread({
    required this.thread,
    required this.customerName,
    this.customerAvatarUrl,
  });

  factory BusinessThread.fromRow(
    Map<String, dynamic> row,
    Map<String, dynamic>? profile,
  ) {
    final thread = ChatThread.fromJson(row);
    final name = profile?['full_name'] as String? ??
        profile?['username'] as String? ??
        'Cliente';
    return BusinessThread(
      thread: thread,
      customerName: name,
      customerAvatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
