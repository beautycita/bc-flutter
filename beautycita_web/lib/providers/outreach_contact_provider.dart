import 'dart:convert';

import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Models ───────────────────────────────────────────────────────────────────

@immutable
class OutreachTemplate {
  final String id;
  final String name;
  final String channel;
  final String? subject;
  final String bodyTemplate;
  final String? category;
  final int sortOrder;

  const OutreachTemplate({
    required this.id,
    required this.name,
    required this.channel,
    this.subject,
    required this.bodyTemplate,
    this.category,
    this.sortOrder = 0,
  });

  factory OutreachTemplate.fromJson(Map<String, dynamic> json) {
    return OutreachTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      subject: json['subject'] as String?,
      bodyTemplate: json['body_template'] as String? ?? '',
      category: json['category'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

@immutable
class OutreachLogEntry {
  final String id;
  final String discoveredSalonId;
  final String channel;
  final String? recipientPhone;
  final String? messageText;
  final String? subject;
  final int interestCount;
  final DateTime sentAt;
  final String? notes;
  final String? outcome;
  final String? rpUserId;
  final String? rpDisplayName;
  final String? recordingUrl;
  final String? transcript;
  final int? callDurationSeconds;
  final String? templateId;

  const OutreachLogEntry({
    required this.id,
    required this.discoveredSalonId,
    required this.channel,
    this.recipientPhone,
    this.messageText,
    this.subject,
    this.interestCount = 0,
    required this.sentAt,
    this.notes,
    this.outcome,
    this.rpUserId,
    this.rpDisplayName,
    this.recordingUrl,
    this.transcript,
    this.callDurationSeconds,
    this.templateId,
  });

  factory OutreachLogEntry.fromJson(Map<String, dynamic> json) {
    return OutreachLogEntry(
      id: json['id'] as String? ?? '',
      discoveredSalonId: json['discovered_salon_id'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      recipientPhone: json['recipient_phone'] as String?,
      messageText: json['message_text'] as String?,
      subject: json['subject'] as String?,
      interestCount: json['interest_count'] as int? ?? 0,
      sentAt: DateTime.tryParse(json['sent_at'] as String? ?? '') ??
          DateTime.now(),
      notes: json['notes'] as String?,
      outcome: json['outcome'] as String?,
      rpUserId: json['rp_user_id'] as String?,
      rpDisplayName: json['rp_display_name'] as String?,
      recordingUrl: json['recording_url'] as String?,
      transcript: json['transcript'] as String?,
      callDurationSeconds: json['call_duration_seconds'] as int?,
      templateId: json['template_id'] as String?,
    );
  }

  /// Icon for the channel type.
  IconData get channelIcon => switch (channel) {
        'wa_message' => Icons.chat,
        'wa_call' => Icons.phone_android,
        'email' => Icons.email_outlined,
        'sms' => Icons.sms_outlined,
        'phone' => Icons.phone,
        _ => Icons.message_outlined,
      };

  /// Human-readable label for the channel.
  String get channelLabel => switch (channel) {
        'wa_message' => 'WhatsApp',
        'wa_call' => 'Llamada WA',
        'email' => 'Email',
        'sms' => 'SMS',
        'phone' => 'Llamada',
        _ => channel,
      };

  /// Color for the outcome badge.
  Color get outcomeColor => switch (outcome) {
        'interested' => const Color(0xFF16A34A),
        'callback' => const Color(0xFFCA8A04),
        'not_interested' => const Color(0xFFDC2626),
        'no_answer' => const Color(0xFF9CA3AF),
        'wrong_number' => const Color(0xFFEF4444),
        'voicemail' => const Color(0xFF6B7280),
        _ => const Color(0xFF6B7280),
      };
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Fetches outreach templates, optionally filtered by channel.
final outreachTemplatesProvider =
    FutureProvider.family<List<OutreachTemplate>, String?>(
        (ref, channel) async {
  if (!BCSupabase.isInitialized) return [];

  final body = <String, dynamic>{
    'action': 'get_templates',
  };
  if (channel != null) body['channel'] = channel;

  final response = await BCSupabase.client.functions.invoke(
    'outreach-contact',
    body: body,
  );

  final data = response.data;
  if (data == null) return [];

  final parsed = data is String ? jsonDecode(data) : data;
  if (parsed is! Map || parsed['templates'] is! List) return [];

  return (parsed['templates'] as List)
      .map((e) => OutreachTemplate.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches outreach history for a specific salon.
final salonOutreachHistoryProvider =
    FutureProvider.family<List<OutreachLogEntry>, String>(
        (ref, salonId) async {
  if (!BCSupabase.isInitialized) return [];

  final response = await BCSupabase.client.functions.invoke(
    'outreach-contact',
    body: {
      'action': 'get_history',
      'discovered_salon_id': salonId,
    },
  );

  final data = response.data;
  if (data == null) return [];

  final parsed = data is String ? jsonDecode(data) : data;
  if (parsed is! Map || parsed['history'] is! List) return [];

  final entries = (parsed['history'] as List)
      .map((e) => OutreachLogEntry.fromJson(e as Map<String, dynamic>))
      .toList();

  // Newest first
  entries.sort((a, b) => b.sentAt.compareTo(a.sentAt));
  return entries;
});

// ── Service ──────────────────────────────────────────────────────────────────

/// Static methods for outreach actions against the outreach-contact edge
/// function.
abstract final class OutreachContactService {
  static Future<bool> sendWa({
    required String salonId,
    String? message,
    String? templateId,
    required String rpName,
    required String rpPhone,
  }) async {
    try {
      final response = await BCSupabase.client.functions.invoke(
        'outreach-contact',
        body: {
          'action': 'send_wa',
          'discovered_salon_id': salonId,
          if (message != null) 'message': message,
          if (templateId != null) 'template_id': templateId,
          'rp_name': rpName,
          'rp_phone': rpPhone,
        },
      );
      final data = response.data;
      final parsed = data is String ? jsonDecode(data) : data;
      return parsed is Map && parsed['success'] == true;
    } catch (e) {
      debugPrint('[OutreachContactService.sendWa] Error: $e');
      return false;
    }
  }

  static Future<bool> sendEmail({
    required String salonId,
    required String subject,
    required String message,
    String? templateId,
    String? recipientEmail,
    required String rpName,
    required String rpPhone,
  }) async {
    try {
      final response = await BCSupabase.client.functions.invoke(
        'outreach-contact',
        body: {
          'action': 'send_email',
          'discovered_salon_id': salonId,
          'subject': subject,
          'message': message,
          if (templateId != null) 'template_id': templateId,
          if (recipientEmail != null) 'recipient_email': recipientEmail,
          'rp_name': rpName,
          'rp_phone': rpPhone,
        },
      );
      final data = response.data;
      final parsed = data is String ? jsonDecode(data) : data;
      return parsed is Map && parsed['success'] == true;
    } catch (e) {
      debugPrint('[OutreachContactService.sendEmail] Error: $e');
      return false;
    }
  }

  static Future<bool> sendSms({
    required String salonId,
    required String message,
    required String rpName,
  }) async {
    try {
      final response = await BCSupabase.client.functions.invoke(
        'outreach-contact',
        body: {
          'action': 'send_sms',
          'discovered_salon_id': salonId,
          'message': message,
          'rp_name': rpName,
        },
      );
      final data = response.data;
      final parsed = data is String ? jsonDecode(data) : data;
      return parsed is Map && parsed['success'] == true;
    } catch (e) {
      debugPrint('[OutreachContactService.sendSms] Error: $e');
      return false;
    }
  }

  static Future<bool> logCall({
    required String salonId,
    required String channel,
    String? notes,
    String? outcome,
    int? durationSeconds,
  }) async {
    try {
      final response = await BCSupabase.client.functions.invoke(
        'outreach-contact',
        body: {
          'action': 'log_call',
          'discovered_salon_id': salonId,
          'channel': channel,
          if (notes != null) 'notes': notes,
          if (outcome != null) 'outcome': outcome,
          if (durationSeconds != null) 'duration_seconds': durationSeconds,
        },
      );
      final data = response.data;
      final parsed = data is String ? jsonDecode(data) : data;
      return parsed is Map && parsed['success'] == true;
    } catch (e) {
      debugPrint('[OutreachContactService.logCall] Error: $e');
      return false;
    }
  }

  static Future<String?> uploadRecording({
    required String salonId,
    required String logId,
    required List<int> audioBytes,
    String contentType = 'audio/webm',
  }) async {
    try {
      final response = await BCSupabase.client.functions.invoke(
        'outreach-contact',
        body: {
          'action': 'upload_recording',
          'discovered_salon_id': salonId,
          'log_id': logId,
          'audio_base64': base64Encode(audioBytes),
          'content_type': contentType,
        },
      );
      final data = response.data;
      final parsed = data is String ? jsonDecode(data) : data;
      if (parsed is Map && parsed['recording_url'] is String) {
        return parsed['recording_url'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('[OutreachContactService.uploadRecording] Error: $e');
      return null;
    }
  }

  static Future<String?> transcribe({required String logId}) async {
    try {
      final response = await BCSupabase.client.functions.invoke(
        'outreach-contact',
        body: {
          'action': 'transcribe',
          'log_id': logId,
        },
      );
      final data = response.data;
      final parsed = data is String ? jsonDecode(data) : data;
      if (parsed is Map && parsed['transcript'] is String) {
        return parsed['transcript'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('[OutreachContactService.transcribe] Error: $e');
      return null;
    }
  }
}
