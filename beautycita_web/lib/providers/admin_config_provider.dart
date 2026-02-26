import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

/// A config key-value entry.
@immutable
class ConfigEntry {
  final String id;
  final String key;
  final String value;
  final String type; // 'string', 'int', 'double', 'bool', 'json'
  final DateTime? updatedAt;

  const ConfigEntry({
    required this.id,
    required this.key,
    required this.value,
    required this.type,
    this.updatedAt,
  });

  static ConfigEntry fromMap(Map<String, dynamic> row) {
    return ConfigEntry(
      id: row['id'] as String? ?? '',
      key: row['key'] as String? ?? '',
      value: row['value']?.toString() ?? '',
      type: row['type'] as String? ?? 'string',
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }
}

/// Status of an external API connection.
@immutable
class ApiStatus {
  final String name;
  final bool isConnected;
  final String statusText;

  const ApiStatus({
    required this.name,
    required this.isConnected,
    required this.statusText,
  });
}

/// Feature toggle entry.
@immutable
class FeatureToggle {
  final String key;
  final String name;
  final String description;
  final bool enabled;

  const FeatureToggle({
    required this.key,
    required this.name,
    required this.description,
    required this.enabled,
  });
}

// ── Providers ────────────────────────────────────────────────────────────────

/// All app config entries.
final appConfigProvider = FutureProvider<List<ConfigEntry>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final data = await BCSupabase.client
        .from('app_config')
        .select()
        .order('key');

    return data.map((row) => ConfigEntry.fromMap(row)).toList();
  } catch (e) {
    debugPrint('App config error: $e');
    return [];
  }
});

/// API status indicators — these check config keys and external endpoints.
final apiStatusProvider = FutureProvider<List<ApiStatus>>((ref) async {
  if (!BCSupabase.isInitialized) {
    return [
      const ApiStatus(
          name: 'Stripe', isConnected: false, statusText: 'Offline'),
      const ApiStatus(
          name: 'Mapbox', isConnected: false, statusText: 'Offline'),
      const ApiStatus(
          name: 'Google OAuth', isConnected: false, statusText: 'Offline'),
      const ApiStatus(
          name: 'Google Places', isConnected: false, statusText: 'Offline'),
      const ApiStatus(
          name: 'BTCPay', isConnected: false, statusText: 'Offline'),
      const ApiStatus(
          name: 'OpenAI', isConnected: false, statusText: 'Offline'),
      const ApiStatus(
          name: 'Beautypi WA API',
          isConnected: false,
          statusText: 'Offline'),
    ];
  }

  try {
    final data = await BCSupabase.client
        .from('app_config')
        .select('key, value')
        .inFilter('key', [
      'stripe_key',
      'mapbox_key',
      'google_oauth_key',
      'google_places_key',
      'btcpay_url',
      'openai_key',
      'wa_api_url',
    ]);

    final configMap = <String, String>{};
    for (final row in data) {
      configMap[row['key'] as String] = row['value']?.toString() ?? '';
    }

    bool hasKey(String key) =>
        configMap.containsKey(key) && configMap[key]!.isNotEmpty;

    return [
      ApiStatus(
        name: 'Stripe',
        isConnected: hasKey('stripe_key'),
        statusText: hasKey('stripe_key') ? 'Conectado' : 'Sin configurar',
      ),
      ApiStatus(
        name: 'Mapbox',
        isConnected: hasKey('mapbox_key'),
        statusText: hasKey('mapbox_key') ? 'Conectado' : 'Sin configurar',
      ),
      ApiStatus(
        name: 'Google OAuth',
        isConnected: hasKey('google_oauth_key'),
        statusText:
            hasKey('google_oauth_key') ? 'Conectado' : 'Sin configurar',
      ),
      ApiStatus(
        name: 'Google Places',
        isConnected: hasKey('google_places_key'),
        statusText:
            hasKey('google_places_key') ? 'Conectado' : 'Sin configurar',
      ),
      ApiStatus(
        name: 'BTCPay',
        isConnected: hasKey('btcpay_url'),
        statusText: hasKey('btcpay_url') ? 'Conectado' : 'Sin configurar',
      ),
      ApiStatus(
        name: 'OpenAI',
        isConnected: hasKey('openai_key'),
        statusText: hasKey('openai_key') ? 'Conectado' : 'Sin configurar',
      ),
      ApiStatus(
        name: 'Beautypi WA API',
        isConnected: hasKey('wa_api_url'),
        statusText: hasKey('wa_api_url') ? 'Conectado' : 'Sin configurar',
      ),
    ];
  } catch (e) {
    debugPrint('API status error: $e');
    return [];
  }
});

/// Feature toggles derived from app config.
final featureTogglesProvider =
    FutureProvider<List<FeatureToggle>>((ref) async {
  const toggleDefs = [
    ('toggle_bitcoin_payments', 'Pagos Bitcoin',
        'Permitir pagos con Bitcoin via BTCPay Server'),
    ('toggle_uber_integration', 'Integracion Uber',
        'Transporte Uber automatico ida y vuelta'),
    ('toggle_virtual_studio', 'Estudio Virtual',
        'Probar looks virtuales con AR antes de reservar'),
    ('toggle_aphrodite_ai', 'Aphrodite AI',
        'Asistente inteligente para recomendaciones personalizadas'),
    ('toggle_google_calendar', 'Google Calendar Sync',
        'Sincronizar citas con Google Calendar del usuario'),
    ('toggle_qr_auth', 'QR Auth',
        'Autenticacion por codigo QR escaneado desde el celular'),
    ('toggle_cita_express', 'Cita Express',
        'Reserva ultra-rapida en un solo tap para servicios frecuentes'),
    ('toggle_push_notifications', 'Push Notifications',
        'Notificaciones push para recordatorios y promociones'),
  ];

  if (!BCSupabase.isInitialized) {
    return toggleDefs
        .map((t) => FeatureToggle(
              key: t.$1,
              name: t.$2,
              description: t.$3,
              enabled: false,
            ))
        .toList();
  }

  try {
    final keys = toggleDefs.map((t) => t.$1).toList();
    final data = await BCSupabase.client
        .from('app_config')
        .select('key, value')
        .inFilter('key', keys);

    final configMap = <String, String>{};
    for (final row in data) {
      configMap[row['key'] as String] = row['value']?.toString() ?? '';
    }

    return toggleDefs
        .map((t) => FeatureToggle(
              key: t.$1,
              name: t.$2,
              description: t.$3,
              enabled: configMap[t.$1] == 'true',
            ))
        .toList();
  } catch (e) {
    debugPrint('Feature toggles error: $e');
    return toggleDefs
        .map((t) => FeatureToggle(
              key: t.$1,
              name: t.$2,
              description: t.$3,
              enabled: false,
            ))
        .toList();
  }
});
