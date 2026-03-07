import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:beautycita_core/models.dart';
import 'package:beautycita/services/supabase_client.dart';

class FeedService {
  /// Fetch paginated feed from the feed-public edge function.
  ///
  /// The edge function is a GET endpoint, so we construct the URL manually
  /// using the Supabase project URL from dotenv and attach auth headers.
  Future<List<FeedItem>> fetchFeed({
    int page = 0,
    int limit = 20,
    String? category,
  }) async {
    if (!SupabaseClientService.isInitialized) return [];

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    if (supabaseUrl.isEmpty) return [];

    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (category != null) 'category': category,
    };

    final uri = Uri.parse('$supabaseUrl/functions/v1/feed-public')
        .replace(queryParameters: params);

    final headers = <String, String>{
      'apikey': dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    };

    final session = SupabaseClientService.client.auth.currentSession;
    if (session != null) {
      headers['authorization'] = 'Bearer ${session.accessToken}';
    }

    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) {
        debugPrint('[FeedService] fetchFeed: HTTP ${response.statusCode}');
        return [];
      }
      final decoded = jsonDecode(response.body);
      // Edge function returns { page, limit, total, items: [...] }
      final List items;
      if (decoded is Map<String, dynamic> && decoded['items'] is List) {
        items = decoded['items'] as List;
      } else if (decoded is List) {
        items = decoded;
      } else {
        return [];
      }
      return items
          .whereType<Map<String, dynamic>>()
          .map(FeedItem.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[FeedService] fetchFeed: $e');
      return [];
    }
  }

  /// Toggle save/unsave for a feed item.
  ///
  /// Returns true if the item is now saved, false if it was unsaved.
  Future<bool> toggleSave({
    required String contentType, // 'photo', 'showcase', or 'product'
    required String contentId,
  }) async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return false;

    final client = SupabaseClientService.client;

    final existing = await client
        .from('feed_saves')
        .select('id')
        .eq('user_id', userId)
        .eq('content_type', contentType)
        .eq('content_id', contentId)
        .maybeSingle();

    if (existing != null) {
      await client
          .from('feed_saves')
          .delete()
          .eq('user_id', userId)
          .eq('content_type', contentType)
          .eq('content_id', contentId);
      return false;
    } else {
      await client.from('feed_saves').insert({
        'user_id': userId,
        'content_type': contentType,
        'content_id': contentId,
      });
      return true;
    }
  }

  /// Track a feed engagement event. Fire-and-forget; errors are silently ignored.
  Future<void> trackEngagement({
    required String contentType, // 'photo' or 'showcase'
    required String contentId,
    required String action, // 'view', 'save', 'product_tap'
  }) async {
    if (!SupabaseClientService.isInitialized) return;
    try {
      await SupabaseClientService.client.from('feed_engagement').insert({
        'user_id': SupabaseClientService.currentUserId,
        'content_type': contentType,
        'content_id': contentId,
        'action': action,
      });
    } catch (e) {
      debugPrint('[FeedService] trackEngagement: $e');
    }
  }

  /// Fetch all items saved by the current user, newest first.
  Future<List<Map<String, dynamic>>> fetchSaved() async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return [];

    try {
      final data = await SupabaseClientService.client
          .from('feed_saves')
          .select()
          .eq('user_id', userId)
          .order('saved_at', ascending: false);

      return (data as List).whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[FeedService] fetchSaved: $e');
      return [];
    }
  }
}
