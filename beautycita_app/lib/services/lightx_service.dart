import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'supabase_client.dart';

/// Client-side wrapper for LightX virtual try-on, rebranded as BeautyCita features.
/// All actual API calls go through the aphrodite-chat edge function (v2 API).
class LightXService {
  /// Available try-on types matching LightX v2 API endpoints.
  static const Map<String, TryOnType> tryOnTypes = {
    'hair_color': TryOnType(
      id: 'hair_color',
      nameEs: 'Prueba de Color',
      icon: '🎨',
      descriptionEs: 'Prueba un nuevo color de cabello',
      defaultPrompt: 'Rubio platino',
    ),
    'hairstyle': TryOnType(
      id: 'hairstyle',
      nameEs: 'Nuevo Peinado',
      icon: '✂️',
      descriptionEs: 'Prueba un peinado diferente',
      defaultPrompt: 'Bob corto moderno',
    ),
    'headshot': TryOnType(
      id: 'headshot',
      nameEs: 'Retrato Pro',
      icon: '📸',
      descriptionEs: 'Foto profesional estilo headshot',
      defaultPrompt: 'Professional corporate headshot',
    ),
    'face_swap': TryOnType(
      id: 'face_swap',
      nameEs: 'Cambio de Look',
      icon: '🔄',
      descriptionEs: 'Tu cara sobre una foto de referencia',
      defaultPrompt: '',
    ),
  };

  /// Requests a virtual try-on through the edge function.
  /// Returns the URL of the processed image.
  /// For face_swap, [targetImageBytes] is the reference photo (body/hairstyle to swap onto).
  Future<String> processTryOn({
    required Uint8List imageBytes,
    required String stylePrompt,
    required String tryOnTypeId,
    Uint8List? targetImageBytes,
  }) async {
    debugPrint('[LightX] processTryOn called — tool=$tryOnTypeId, imageSize=${imageBytes.length}, prompt=$stylePrompt');

    if (!SupabaseClientService.isInitialized) {
      debugPrint('[LightX] ERROR: Supabase not initialized');
      throw LightXException('Supabase not initialized');
    }

    final client = SupabaseClientService.client;

    final imageB64 = base64Encode(imageBytes);
    debugPrint('[LightX] Base64 encoded image: ${imageB64.length} chars');

    final body = <String, dynamic>{
      'action': 'try_on',
      'image_base64': imageB64,
      'tool_type': tryOnTypeId,
      'style_prompt': stylePrompt,
    };
    if (targetImageBytes != null) {
      body['target_image_base64'] = base64Encode(targetImageBytes);
    }

    debugPrint('[LightX] Invoking aphrodite-chat edge function...');
    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: body,
    );
    debugPrint('[LightX] Edge function response status: ${response.status}');

    if (response.status != 200) {
      final errorBody = response.data;
      debugPrint('[LightX] ERROR response body: $errorBody');
      final message = errorBody is Map ? errorBody['error'] : 'Unknown error';
      throw LightXException('Try-on failed: $message');
    }

    final data = response.data as Map<String, dynamic>;
    debugPrint('[LightX] Success — result_url: ${data['result_url']}');
    return data['result_url'] as String;
  }
}

/// Represents a type of virtual try-on feature.
class TryOnType {
  final String id;
  final String nameEs;
  final String icon;
  final String descriptionEs;
  final String defaultPrompt;

  const TryOnType({
    required this.id,
    required this.nameEs,
    required this.icon,
    required this.descriptionEs,
    required this.defaultPrompt,
  });
}

class LightXException implements Exception {
  final String message;

  LightXException(this.message);

  @override
  String toString() => message;
}
