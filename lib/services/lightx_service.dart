import 'dart:typed_data';
import 'supabase_client.dart';

/// Client-side wrapper for LightX virtual try-on, rebranded as BeautyCita features.
/// All actual API calls go through the aphrodite-chat edge function.
class LightXService {
  /// Available try-on types, rebranded for BeautyCita.
  static const Map<String, TryOnType> tryOnTypes = {
    'hair_color': TryOnType(
      id: 'hair_color',
      nameEs: 'Prueba de Color',
      icon: '🎨',
      descriptionEs: 'Prueba un nuevo color de cabello',
      defaultPrompts: [
        'Rubio platino',
        'Rojo cobrizo',
        'Castaño chocolate',
        'Negro azulado',
        'Rosa pastel',
        'Mechas balayage caramelo',
      ],
    ),
    'makeup': TryOnType(
      id: 'makeup',
      nameEs: 'Prueba de Maquillaje',
      icon: '💄',
      descriptionEs: 'Ve cómo te queda un look de maquillaje',
      defaultPrompts: [
        'Maquillaje natural día',
        'Smokey eyes noche',
        'Glam fiesta',
        'Look novia clásico',
        'Editorial bold',
        'Fresh no-makeup makeup',
      ],
    ),
    'full_look': TryOnType(
      id: 'full_look',
      nameEs: 'Mi Nuevo Look',
      icon: '💇',
      descriptionEs: 'Transformación completa de look',
      defaultPrompts: [
        'Look profesional elegante',
        'Bohemio relajado',
        'K-beauty glass skin',
        'Old Hollywood glam',
        'Festival colorido',
        'Minimalista chic',
      ],
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

    // The edge function handles encoding and API calls
    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: {
        'action': 'try_on',
        'image_base64': _bytesToBase64(imageBytes),
        'style_prompt': '$tryOnTypeId: $stylePrompt',
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

  String _bytesToBase64(Uint8List bytes) {
    // Use dart:convert in the calling code (aphrodite_service.dart already handles this)
    // This is a fallback for direct usage
    final buffer = StringBuffer();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final pad = (3 - bytes.length % 3) % 3;
    final data = Uint8List(bytes.length + pad)..setRange(0, bytes.length, bytes);

    for (var i = 0; i < data.length; i += 3) {
      final n = (data[i] << 16) | (data[i + 1] << 8) | data[i + 2];
      buffer
        ..write(chars[(n >> 18) & 63])
        ..write(chars[(n >> 12) & 63])
        ..write(i + 1 < bytes.length ? chars[(n >> 6) & 63] : '=')
        ..write(i + 2 < bytes.length ? chars[n & 63] : '=');
    }
    return buffer.toString();
  }
}

/// Represents a type of virtual try-on feature.
class TryOnType {
  final String id;
  final String nameEs;
  final String icon;
  final String descriptionEs;
  final List<String> defaultPrompts;

  const TryOnType({
    required this.id,
    required this.nameEs,
    required this.icon,
    required this.descriptionEs,
    required this.defaultPrompts,
  });
}

class LightXException implements Exception {
  final String message;

  LightXException(this.message);

  @override
  String toString() => message;
}
