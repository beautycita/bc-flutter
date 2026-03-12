// outreach_contact_provider.dart
// Riverpod providers and service for the outreach-contact edge function.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class OutreachTemplate {
  const OutreachTemplate({
    required this.id,
    required this.channel,
    required this.name,
    this.subject,
    required this.bodyTemplate,
    required this.isActive,
  });

  final String id;
  final String channel;
  final String name;
  final String? subject;
  final String bodyTemplate;
  final bool isActive;

  factory OutreachTemplate.fromJson(Map<String, dynamic> json) {
    return OutreachTemplate(
      id: json['id'] as String,
      channel: json['channel'] as String,
      name: json['name'] as String,
      subject: json['subject'] as String?,
      bodyTemplate: json['body_template'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class OutreachLogEntry {
  const OutreachLogEntry({
    required this.id,
    required this.discoveredSalonId,
    required this.channel,
    this.messageText,
    this.outcome,
    this.notes,
    this.durationSeconds,
    this.recordingUrl,
    this.transcript,
    this.templateId,
    this.rpId,
    this.rpDisplayName,
    required this.testMode,
    required this.sentAt,
  });

  final String id;
  final String discoveredSalonId;
  final String channel;
  final String? messageText;
  final String? outcome;
  final String? notes;
  final int? durationSeconds;
  final String? recordingUrl;
  final String? transcript;
  final String? templateId;
  final String? rpId;
  final String? rpDisplayName;
  final bool testMode;
  final DateTime sentAt;

  factory OutreachLogEntry.fromJson(Map<String, dynamic> json) {
    return OutreachLogEntry(
      id: json['id'] as String,
      discoveredSalonId: json['discovered_salon_id'] as String,
      channel: json['channel'] as String,
      messageText: json['message_text'] as String?,
      outcome: json['outcome'] as String?,
      notes: json['notes'] as String?,
      durationSeconds: json['call_duration_seconds'] as int?,
      recordingUrl: json['recording_url'] as String?,
      transcript: json['transcript'] as String?,
      templateId: json['template_id'] as String?,
      rpId: json['rp_user_id'] as String?,
      rpDisplayName: json['rp_display_name'] as String?,
      testMode: json['test_mode'] as bool? ?? false,
      sentAt: DateTime.parse(json['sent_at'] as String),
    );
  }

  IconData get channelIcon => switch (channel) {
        'wa_message' => Icons.chat,
        'wa_call' => Icons.call,
        'phone' || 'phone_call' => Icons.phone,
        'email' => Icons.email,
        'sms' => Icons.sms,
        _ => Icons.circle_notifications,
      };

  String get channelLabel => switch (channel) {
        'wa_message' => 'WhatsApp',
        'wa_call' => 'Llamada WA',
        'phone' || 'phone_call' => 'Llamada',
        'email' => 'Email',
        'sms' => 'SMS',
        _ => channel,
      };

  Color? get outcomeColor => switch (outcome) {
        'interested' => Colors.green,
        'not_interested' => Colors.red,
        'callback' => Colors.orange,
        'no_answer' => Colors.grey,
        'wrong_number' => Colors.red.shade200,
        'voicemail' => Colors.blue.shade200,
        _ => null,
      };
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Fetch active outreach templates for a given channel (whatsapp|email|sms).
final outreachTemplatesProvider =
    FutureProvider.family<List<OutreachTemplate>, String>((ref, channel) async {
  final res = await SupabaseClientService.client.functions.invoke(
    'outreach-contact',
    body: {'action': 'get_templates', 'channel': channel},
  );
  final data = res.data as Map<String, dynamic>?;
  if (data == null) throw Exception('outreach-contact: get_templates returned null');
  final list = (data['templates'] as List).cast<Map<String, dynamic>>();
  return list.map(OutreachTemplate.fromJson).toList();
});

/// Fetch full outreach history for a discovered salon.
final salonOutreachHistoryProvider =
    FutureProvider.family<List<OutreachLogEntry>, String>((ref, salonId) async {
  final res = await SupabaseClientService.client.functions.invoke(
    'outreach-contact',
    body: {'action': 'get_history', 'discovered_salon_id': salonId},
  );
  final data = res.data as Map<String, dynamic>?;
  if (data == null) throw Exception('outreach-contact: get_history returned null');
  final list = (data['history'] as List).cast<Map<String, dynamic>>();
  return list.map(OutreachLogEntry.fromJson).toList();
});

// ─── Service ──────────────────────────────────────────────────────────────────

/// Static helpers that call the outreach-contact edge function and return
/// the raw response map. Callers should check `res['success'] == true`.
class OutreachContactService {
  OutreachContactService._();

  static Future<Map<String, dynamic>> sendWa({
    required String salonId,
    required String message,
    String? templateId,
  }) async {
    final res = await SupabaseClientService.client.functions.invoke(
      'outreach-contact',
      body: {
        'action': 'send_wa',
        'discovered_salon_id': salonId,
        'message': message,
        'template_id': ?templateId,
      },
    );
    return (res.data as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> sendEmail({
    required String salonId,
    required String subject,
    required String body,
    String? templateId,
  }) async {
    final res = await SupabaseClientService.client.functions.invoke(
      'outreach-contact',
      body: {
        'action': 'send_email',
        'discovered_salon_id': salonId,
        'subject': subject,
        'message': body,
        'template_id': ?templateId,
      },
    );
    return (res.data as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> sendSms({
    required String salonId,
    required String message,
    String? templateId,
  }) async {
    final res = await SupabaseClientService.client.functions.invoke(
      'outreach-contact',
      body: {
        'action': 'send_sms',
        'discovered_salon_id': salonId,
        'message': message,
        'template_id': ?templateId,
      },
    );
    return (res.data as Map<String, dynamic>?) ?? {};
  }

  /// [channel] must be `'phone'` or `'wa_call'`.
  /// [outcome] must be one of: interested|not_interested|callback|no_answer|wrong_number|voicemail
  static Future<Map<String, dynamic>> logCall({
    required String salonId,
    required String channel,
    required String outcome,
    int? durationSeconds,
    String? notes,
  }) async {
    final res = await SupabaseClientService.client.functions.invoke(
      'outreach-contact',
      body: {
        'action': 'log_call',
        'discovered_salon_id': salonId,
        'channel': channel,
        'outcome': outcome,
        'duration_seconds': ?durationSeconds,
        'notes': ?notes,
      },
    );
    return (res.data as Map<String, dynamic>?) ?? {};
  }

  /// Triggers OpenAI Whisper transcription of the recording attached to [logId].
  /// Returns `{'success': true, 'transcript': '...'}` on success.
  static Future<Map<String, dynamic>> transcribe({
    required String logId,
  }) async {
    final res = await SupabaseClientService.client.functions.invoke(
      'outreach-contact',
      body: {'action': 'transcribe', 'log_id': logId},
    );
    return (res.data as Map<String, dynamic>?) ?? {};
  }
}
