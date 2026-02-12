import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'supabase_client.dart';
import 'toast_service.dart';

/// Represents a media item from user_media table or chat_messages.
class MediaItem {
  final String id;
  final String userId;
  final String mediaType;
  final String source;
  final String? sourceRef;
  final String url;
  final String? thumbnailUrl;
  final Map<String, dynamic> metadata;
  final String section;
  final DateTime createdAt;

  const MediaItem({
    required this.id,
    required this.userId,
    required this.mediaType,
    required this.source,
    this.sourceRef,
    required this.url,
    this.thumbnailUrl,
    this.metadata = const {},
    required this.section,
    required this.createdAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaType: json['media_type'] as String? ?? 'image',
      source: json['source'] as String,
      sourceRef: json['source_ref'] as String?,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      section: json['section'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Create a MediaItem from a chat_message row (for chat media tab).
  factory MediaItem.fromChatMessage(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      userId: '',
      mediaType: 'image',
      source: 'chat',
      sourceRef: json['thread_id'] as String?,
      url: json['media_url'] as String,
      section: 'chat',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get sourceLabel {
    switch (source) {
      case 'lightx':
        return 'Estudio Virtual';
      case 'chat':
        return 'Chat';
      case 'upload':
        return 'Subido';
      case 'review':
        return 'Resena';
      case 'portfolio':
        return 'Portafolio';
      default:
        return source;
    }
  }

  String? get toolLabel {
    final toolType = metadata['tool_type'] as String?;
    if (toolType == null) return null;
    switch (toolType) {
      case 'hair_color':
        return 'Color';
      case 'hairstyle':
        return 'Peinado';
      case 'headshot':
        return 'Retrato';
      case 'avatar':
        return 'Avatar';
      case 'face_swap':
        return 'Cambio';
      default:
        return toolType;
    }
  }
}

/// Service for media operations: save to gallery, share, delete, CRUD on user_media.
class MediaService {
  /// Save a LightX result to user_media and device gallery.
  /// Returns the created MediaItem.
  Future<MediaItem?> saveLightXResult({
    required String resultUrl,
    required String toolType,
    required String stylePrompt,
  }) async {
    if (!SupabaseClientService.isInitialized) return null;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return null;

    final client = SupabaseClientService.client;

    // Insert into user_media
    final row = {
      'user_id': userId,
      'media_type': 'image',
      'source': 'lightx',
      'url': resultUrl,
      'metadata': {
        'tool_type': toolType,
        'style_prompt': stylePrompt,
      },
      'section': 'personal',
    };

    final result = await client
        .from('user_media')
        .insert(row)
        .select()
        .single();

    // Download and save to device gallery
    await saveUrlToGallery(resultUrl);

    return MediaItem.fromJson(result);
  }

  /// Download image from URL and save to device gallery.
  Future<bool> saveUrlToGallery(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return false;

      final result = await ImageGallerySaverPlus.saveImage(
        response.bodyBytes,
        quality: 95,
        name: 'BeautyCita_${DateTime.now().millisecondsSinceEpoch}',
      );

      return result['isSuccess'] == true;
    } catch (e) {
      debugPrint('MediaService: Failed to save to gallery: $e');
      ToastService.showError('Error al guardar imagen');
      return false;
    }
  }

  /// Save an already-downloaded image to gallery.
  Future<bool> saveToGallery(Uint8List bytes, {String? name}) async {
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 95,
        name: name ?? 'BeautyCita_${DateTime.now().millisecondsSinceEpoch}',
      );
      return result['isSuccess'] == true;
    } catch (e) {
      debugPrint('MediaService: Failed to save to gallery: $e');
      ToastService.showError('Error al guardar imagen');
      return false;
    }
  }

  /// Share an image by URL using native share sheet.
  Future<void> shareImage(String url, {String? text}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/beautycita_share_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
      );
    } catch (e) {
      debugPrint('MediaService: Failed to share: $e');
      ToastService.showError('Error al compartir');
    }
  }

  /// Delete a media item from user_media.
  Future<void> deleteMedia(String mediaId) async {
    if (!SupabaseClientService.isInitialized) return;
    final client = SupabaseClientService.client;
    await client.from('user_media').delete().eq('id', mediaId);
  }

  /// Upload media to user-media bucket and create user_media record.
  /// Returns the created MediaItem on success, null on failure.
  Future<MediaItem?> uploadMedia({
    required Uint8List bytes,
    required String section, // 'personal' or 'business'
    String? description,
  }) async {
    debugPrint('MediaService.uploadMedia: called with ${bytes.length} bytes, section=$section');
    if (!SupabaseClientService.isInitialized) {
      debugPrint('MediaService.uploadMedia: Supabase not initialized');
      return null;
    }
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      debugPrint('MediaService.uploadMedia: userId is null');
      return null;
    }
    debugPrint('MediaService.uploadMedia: userId=$userId');

    final client = SupabaseClientService.client;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$userId/$section/$timestamp.jpg';
    debugPrint('MediaService.uploadMedia: fileName=$fileName');

    try {
      // Log storage URL for debugging
      debugPrint('MediaService.uploadMedia: bucket=user-media, path=$fileName');

      // First, test raw HTTP to storage endpoint to see exact response
      final testUrl = 'https://beautycita.com/supabase/storage/v1/bucket';
      final accessToken = client.auth.currentSession?.accessToken ?? '';
      debugPrint('MediaService.uploadMedia: testing raw HTTP to $testUrl');
      debugPrint('MediaService.uploadMedia: accessToken length=${accessToken.length}');
      try {
        final testResponse = await http.get(Uri.parse(testUrl));
        debugPrint('MediaService.uploadMedia: test status=${testResponse.statusCode}');
        final bodyPreview = testResponse.body.length > 200
            ? testResponse.body.substring(0, 200)
            : testResponse.body;
        debugPrint('MediaService.uploadMedia: test body=$bodyPreview...');
      } catch (e) {
        debugPrint('MediaService.uploadMedia: test error=$e');
      }

      // Upload to storage bucket
      debugPrint('MediaService.uploadMedia: uploading to storage...');
      await client.storage.from('user-media').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      debugPrint('MediaService.uploadMedia: storage upload success');

      // Get public URL
      final publicUrl =
          client.storage.from('user-media').getPublicUrl(fileName);
      debugPrint('MediaService.uploadMedia: publicUrl=$publicUrl');

      // Insert record into user_media table
      final row = {
        'user_id': userId,
        'media_type': 'image',
        'source': 'upload',
        'url': publicUrl,
        'metadata': {
          if (description != null) 'description': description,
        },
        'section': section,
      };
      debugPrint('MediaService.uploadMedia: inserting into user_media...');

      final result = await client
          .from('user_media')
          .insert(row)
          .select()
          .single();
      debugPrint('MediaService.uploadMedia: insert success, id=${result['id']}');

      return MediaItem.fromJson(result);
    } catch (e) {
      debugPrint('MediaService.uploadMedia: FAILED: $e');
      ToastService.showError(ToastService.friendlyError(e));
      return null;
    }
  }

  /// Fetch media items for a section.
  Future<List<MediaItem>> fetchMedia(String section, {int limit = 100}) async {
    if (!SupabaseClientService.isInitialized) return [];
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return [];

    final client = SupabaseClientService.client;
    final data = await client
        .from('user_media')
        .select()
        .eq('user_id', userId)
        .eq('section', section)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((r) => MediaItem.fromJson(r)).toList();
  }

  /// Fetch ALL user media regardless of section (for "Tus Medios" tab).
  Future<List<MediaItem>> fetchAllUserMedia({int limit = 200}) async {
    if (!SupabaseClientService.isInitialized) return [];
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return [];

    final client = SupabaseClientService.client;
    final data = await client
        .from('user_media')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((r) => MediaItem.fromJson(r)).toList();
  }

  /// Fetch chat media from chat_messages (images and tryon_results with media_url).
  Future<Map<String, List<MediaItem>>> fetchChatMedia() async {
    if (!SupabaseClientService.isInitialized) return {};
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return {};

    final client = SupabaseClientService.client;

    // Get user's thread IDs
    final threads = await client
        .from('chat_threads')
        .select('id, contact_type')
        .eq('user_id', userId);

    final threadMap = <String, String>{};
    for (final t in threads) {
      final contactType = t['contact_type'] as String;
      final label = contactType == 'aphrodite' ? 'Afrodita' : (t['contact_id'] as String? ?? 'Chat');
      threadMap[t['id'] as String] = label;
    }

    if (threadMap.isEmpty) return {};

    // Get all media messages from those threads
    final messages = await client
        .from('chat_messages')
        .select()
        .inFilter('thread_id', threadMap.keys.toList())
        .inFilter('content_type', ['image', 'tryon_result'])
        .not('media_url', 'is', null)
        .order('created_at', ascending: false)
        .limit(200);

    final grouped = <String, List<MediaItem>>{};
    for (final msg in messages) {
      final threadId = msg['thread_id'] as String;
      final label = threadMap[threadId] ?? 'Chat';
      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(MediaItem.fromChatMessage(msg));
    }

    return grouped;
  }
}
