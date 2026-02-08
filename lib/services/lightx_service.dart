import 'dart:convert';
import 'dart:typed_data';
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
    'avatar': TryOnType(
      id: 'avatar',
      nameEs: 'Mi Avatar',
      icon: '🎭',
      descriptionEs: 'Crea un avatar estilizado',
      defaultPrompt: 'Glamorous portrait style',
    ),
    'face_swap': TryOnType(
      id: 'face_swap',
      nameEs: 'Cambio de Cara',
      icon: '🔄',
      descriptionEs: 'Prueba un look completamente nuevo',
      defaultPrompt: 'Celebrity glam look',
    ),
  };

  /// Requests a virtual try-on through the edge function.
  /// Returns the URL of the processed image.
  Future<String> processTryOn({
    required Uint8List imageBytes,
    required String stylePrompt,
    required String tryOnTypeId,
  }) async {
    if (!SupabaseClientService.isInitialized) {
      throw LightXException('Supabase not initialized');
    }

    final client = SupabaseClientService.client;

    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: {
        'action': 'try_on',
        'image_base64': base64Encode(imageBytes),
        'tool_type': tryOnTypeId,
        'style_prompt': stylePrompt,
      },
    );

    if (response.status != 200) {
      final errorBody = response.data;
      final message = errorBody is Map ? errorBody['error'] : 'Unknown error';
      throw LightXException('Try-on failed: $message');
    }

    final data = response.data as Map<String, dynamic>;
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
