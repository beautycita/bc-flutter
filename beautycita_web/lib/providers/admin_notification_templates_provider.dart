import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

@immutable
class NotificationTemplate {
  final String id;
  final String eventType;
  final String? templateEs;
  final String? templateEn;
  final DateTime updatedAt;

  const NotificationTemplate({
    required this.id,
    required this.eventType,
    this.templateEs,
    this.templateEn,
    required this.updatedAt,
  });

  factory NotificationTemplate.fromJson(Map<String, dynamic> json) {
    return NotificationTemplate(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      templateEs: json['template_es'] as String?,
      templateEn: json['template_en'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  NotificationTemplate copyWith({
    String? templateEs,
    String? templateEn,
  }) {
    return NotificationTemplate(
      id: id,
      eventType: eventType,
      templateEs: templateEs ?? this.templateEs,
      templateEn: templateEn ?? this.templateEn,
      updatedAt: updatedAt,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final adminNotificationTemplatesProvider =
    FutureProvider<List<NotificationTemplate>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  final data = await BCSupabase.client
      .from('notification_templates')
      .select()
      .order('event_type', ascending: true);

  return (data as List)
      .map((e) =>
          NotificationTemplate.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Save action ───────────────────────────────────────────────────────────────

@immutable
class TemplateSaveState {
  final String? savingId;
  final String? errorId;
  final Set<String> savedIds;

  const TemplateSaveState({
    this.savingId,
    this.errorId,
    this.savedIds = const {},
  });
}

class TemplateSaveNotifier extends StateNotifier<TemplateSaveState> {
  final Ref _ref;

  TemplateSaveNotifier(this._ref) : super(const TemplateSaveState());

  Future<void> save(String id, String? es, String? en) async {
    state = TemplateSaveState(savingId: id, savedIds: state.savedIds);
    try {
      await BCSupabase.client.from('notification_templates').update({
        'template_es': es,
        'template_en': en,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      final saved = {...state.savedIds, id};
      state = TemplateSaveState(savedIds: saved);
      _ref.invalidate(adminNotificationTemplatesProvider);
    } catch (e) {
      debugPrint('TemplateSaveNotifier.save error: $e');
      state = TemplateSaveState(
        errorId: id,
        savedIds: state.savedIds,
      );
    }
  }
}

final templateSaveProvider =
    StateNotifierProvider<TemplateSaveNotifier, TemplateSaveState>((ref) {
  return TemplateSaveNotifier(ref);
});
