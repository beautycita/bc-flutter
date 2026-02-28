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
  final String dataType; // 'string', 'int', 'double', 'bool', 'json'
  final String? groupName;
  final String? description;
  final DateTime? updatedAt;

  const ConfigEntry({
    required this.id,
    required this.key,
    required this.value,
    required this.dataType,
    this.groupName,
    this.description,
    this.updatedAt,
  });

  static ConfigEntry fromMap(Map<String, dynamic> row) {
    return ConfigEntry(
      id: row['id'] as String? ?? '',
      key: row['key'] as String? ?? '',
      value: row['value']?.toString() ?? '',
      dataType: row['data_type'] as String? ?? 'string',
      groupName: row['group_name'] as String?,
      description: row['description_es'] as String?,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }
}

/// Feature toggle entry.
@immutable
class FeatureToggle {
  final String key;
  final String name;
  final String description;
  final String group;
  final bool enabled;

  const FeatureToggle({
    required this.key,
    required this.name,
    required this.description,
    required this.group,
    required this.enabled,
  });
}

// ── Providers ────────────────────────────────────────────────────────────────

/// All app config entries (non-toggle entries only).
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

/// Feature toggles read from app_config where data_type = 'bool'.
final featureTogglesProvider =
    FutureProvider<List<FeatureToggle>>((ref) async {
  // Display names and descriptions for known toggle keys
  const toggleMeta = <String, (String name, String desc)>{
    'enable_stripe_payments': (
      'Pagos Stripe',
      'Pagos con tarjeta via Stripe Connect'
    ),
    'enable_btc_payments': (
      'Pagos Bitcoin',
      'Pagos con Bitcoin via BTCPay Server'
    ),
    'enable_cash_payments': (
      'Pagos en efectivo',
      'Permitir pagos en efectivo en el salon'
    ),
    'enable_deposit_required': (
      'Deposito requerido',
      'Exigir deposito para confirmar reserva'
    ),
    'enable_instant_booking': (
      'Reserva instantanea',
      'Confirmar reservas automaticamente sin aprobacion del salon'
    ),
    'enable_time_inference': (
      'Inferencia de horario',
      'Motor inteligente sugiere hora basado en contexto del usuario'
    ),
    'enable_uber_integration': (
      'Integracion Uber',
      'Transporte Uber automatico ida y vuelta'
    ),
    'enable_waitlist': (
      'Lista de espera',
      'Permitir unirse a lista de espera cuando no hay disponibilidad'
    ),
    'enable_push_notifications': (
      'Push Notifications',
      'Recordatorios y notificaciones push'
    ),
    'enable_reviews': (
      'Resenas',
      'Sistema de resenas y calificaciones'
    ),
    'enable_salon_chat': (
      'Chat salon',
      'Chat directo entre cliente y salon'
    ),
    'enable_referrals': (
      'Referidos',
      'Sistema de referidos "Recomienda tu salon"'
    ),
    'enable_analytics': (
      'Analiticas',
      'Recoleccion de datos analiticos de uso'
    ),
    'enable_maintenance_mode': (
      'Modo mantenimiento',
      'Desactivar acceso a la app para todos los usuarios'
    ),
    'enable_ai_recommendations': (
      'Aphrodite AI',
      'Recomendaciones personalizadas con inteligencia artificial'
    ),
    'enable_virtual_studio': (
      'Estudio Virtual',
      'Probar looks virtuales con AR antes de reservar'
    ),
    'enable_voice_booking': (
      'Reserva por voz',
      'Reservar servicios usando comandos de voz'
    ),
  };

  if (!BCSupabase.isInitialized) {
    return toggleMeta.entries
        .map((e) => FeatureToggle(
              key: e.key,
              name: e.value.$1,
              description: e.value.$2,
              group: '',
              enabled: false,
            ))
        .toList();
  }

  try {
    final data = await BCSupabase.client
        .from('app_config')
        .select('key, value, group_name')
        .eq('data_type', 'bool')
        .order('group_name')
        .order('key');

    return (data as List).map((row) {
      final key = row['key'] as String? ?? '';
      final value = row['value']?.toString() ?? 'false';
      final group = row['group_name'] as String? ?? '';
      final meta = toggleMeta[key];

      return FeatureToggle(
        key: key,
        name: meta?.$1 ?? _humanize(key),
        description: meta?.$2 ?? '',
        group: group,
        enabled: value == 'true',
      );
    }).toList();
  } catch (e) {
    debugPrint('Feature toggles error: $e');
    return [];
  }
});

/// Convert a snake_case key like 'enable_btc_payments' to 'Btc payments'.
String _humanize(String key) {
  final cleaned = key.replaceFirst('enable_', '').replaceAll('_', ' ');
  if (cleaned.isEmpty) return key;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}
