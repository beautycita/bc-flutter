import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
  /// Max upload size (10 MB).
  static const int _maxUploadBytes = 10 * 1024 * 1024;

  /// JPEG magic bytes (FF D8).
  static const List<int> _jpegMagic = [0xFF, 0xD8];

  /// PNG magic bytes (89 50 4E 47).
  static const List<int> _pngMagic = [0x89, 0x50, 0x4E, 0x47];

  /// Validates that [bytes] is a supported image under the size limit.
  static void _validateUpload(Uint8List bytes) {
    if (bytes.isEmpty) throw Exception('El archivo esta vacio');
    if (bytes.length > _maxUploadBytes) {
      throw Exception(
        'El archivo excede el limite de 10 MB (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)',
      );
    }
    final isJpeg = bytes.length >= 2 &&
        bytes[0] == _jpegMagic[0] &&
        bytes[1] == _jpegMagic[1];
    final isPng = bytes.length >= 4 &&
        bytes[0] == _pngMagic[0] &&
        bytes[1] == _pngMagic[1] &&
        bytes[2] == _pngMagic[2] &&
        bytes[3] == _pngMagic[3];
    if (!isJpeg && !isPng) {
      throw Exception('Formato no soportado. Usa JPEG o PNG.');
    }
  }
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
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return false;

      final result = await ImageGallerySaverPlus.saveImage(
        response.bodyBytes,
        quality: 95,
        name: 'BeautyCita_${DateTime.now().millisecondsSinceEpoch}',
      );

      return result['isSuccess'] == true;
    } catch (e) {
      if (kDebugMode) debugPrint('MediaService: Failed to save to gallery: $e');
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
      if (kDebugMode) debugPrint('MediaService: Failed to save to gallery: $e');
      ToastService.showError('Error al guardar imagen');
      return false;
    }
  }

  /// Share an image by URL using native share sheet.
  Future<void> shareImage(String url, {String? text}) async {
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
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
      if (kDebugMode) debugPrint('MediaService: Failed to share: $e');
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
    if (kDebugMode) debugPrint('MediaService.uploadMedia: called with ${bytes.length} bytes, section=$section');

    // Validate file size and format before uploading
    _validateUpload(bytes);

    if (!SupabaseClientService.isInitialized) {
      if (kDebugMode) debugPrint('MediaService.uploadMedia: Supabase not initialized');
      return null;
    }
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      if (kDebugMode) debugPrint('MediaService.uploadMedia: userId is null');
      return null;
    }
    final maskedId = userId.length >= 8 ? '${userId.substring(0, 8)}...' : userId;
    if (kDebugMode) debugPrint('MediaService.uploadMedia: userId=$maskedId');

    final client = SupabaseClientService.client;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$userId/$section/$timestamp.jpg';
    if (kDebugMode) debugPrint('MediaService.uploadMedia: fileName=$maskedId/$section/$timestamp.jpg');

    try {
      // Upload to storage bucket
      if (kDebugMode) debugPrint('MediaService.uploadMedia: bucket=user-media, path=$maskedId/$section/$timestamp.jpg');
      await client.storage.from('user-media').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      if (kDebugMode) debugPrint('MediaService.uploadMedia: storage upload success');

      // Get public URL
      final publicUrl =
          client.storage.from('user-media').getPublicUrl(fileName);
      if (kDebugMode) debugPrint('MediaService.uploadMedia: publicUrl=[masked]');

      // Insert record into user_media table
      final row = {
        'user_id': userId,
        'media_type': 'image',
        'source': 'upload',
        'url': publicUrl,
        'metadata': {
          'description': ?description,
        },
        'section': section,
      };
      if (kDebugMode) debugPrint('MediaService.uploadMedia: inserting into user_media...');

      final result = await client
          .from('user_media')
          .insert(row)
          .select()
          .single();
      if (kDebugMode) debugPrint('MediaService.uploadMedia: insert success, id=${result['id']}');

      return MediaItem.fromJson(result);
    } catch (e) {
      if (kDebugMode) debugPrint('MediaService.uploadMedia: FAILED: $e');
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
