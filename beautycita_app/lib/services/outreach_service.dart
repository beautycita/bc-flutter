import 'supabase_client.dart';

class OutreachException implements Exception {
  final String message;
  final int? statusCode;
  OutreachException(this.message, {this.statusCode});
  @override
  String toString() => 'OutreachException($statusCode): $message';
}

class OutreachTemplate {
  final String id;
  final String name;
  final String channel; // 'whatsapp' | 'email'
  final String? subject;
  final String body;
  final String? category;
  final String? recipientTable; // 'discovered_salons' | 'businesses' | 'both' | null
  final bool isInvite;
  final List<String> requiredVariables;
  final List<String> manualVariables;
  final Map<String, dynamic>? gatingRule;

  OutreachTemplate({
    required this.id,
    required this.name,
    required this.channel,
    this.subject,
    required this.body,
    this.category,
    this.recipientTable,
    required this.isInvite,
    required this.requiredVariables,
    required this.manualVariables,
    this.gatingRule,
  });

  factory OutreachTemplate.fromJson(Map<String, dynamic> j) => OutreachTemplate(
        id: j['id'] as String,
        name: j['name'] as String,
        channel: j['channel'] as String,
        subject: j['subject'] as String?,
        body: j['body_template'] as String,
        category: j['category'] as String?,
        recipientTable: j['recipient_table'] as String?,
        isInvite: (j['is_invite'] as bool?) ?? false,
        requiredVariables: ((j['required_variables'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        manualVariables: ((j['manual_variables'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        gatingRule: j['gating_rule'] as Map<String, dynamic>?,
      );

  String get prettyLabel {
    final cat = category ?? 'general';
    return '$name · $cat';
  }
}

class EligibilityCounts {
  final int eligible;
  final int optedOut;
  final int cooldown;
  final int noChannel;
  final int total;
  EligibilityCounts({
    required this.eligible,
    required this.optedOut,
    required this.cooldown,
    required this.noChannel,
    required this.total,
  });
  factory EligibilityCounts.fromJson(Map<String, dynamic> j) => EligibilityCounts(
        eligible: (j['eligible'] as num?)?.toInt() ?? 0,
        optedOut: (j['opted_out'] as num?)?.toInt() ?? 0,
        cooldown: (j['cooldown'] as num?)?.toInt() ?? 0,
        noChannel: (j['no_channel'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

class OutreachPreview {
  final String? subject;
  final String body;
  final String salonName;
  final String unsubscribeLink;
  final bool optedOut;
  final bool cooldownActive;
  final bool hasPhone;
  final bool hasEmail;

  OutreachPreview({
    this.subject,
    required this.body,
    required this.salonName,
    required this.unsubscribeLink,
    required this.optedOut,
    required this.cooldownActive,
    required this.hasPhone,
    required this.hasEmail,
  });

  factory OutreachPreview.fromJson(Map<String, dynamic> j) => OutreachPreview(
        subject: j['subject'] as String?,
        body: j['body'] as String,
        salonName: (j['salon_name'] as String?) ?? '',
        unsubscribeLink: (j['unsubscribe_link'] as String?) ?? '',
        optedOut: (j['opted_out'] as bool?) ?? false,
        cooldownActive: (j['cooldown_active'] as bool?) ?? false,
        hasPhone: (j['has_phone'] as bool?) ?? false,
        hasEmail: (j['has_email'] as bool?) ?? false,
      );
}

class BulkJobSummary {
  final String id;
  final int total;
  final String preview;
  BulkJobSummary({required this.id, required this.total, required this.preview});
}

class OutreachService {
  /// List active templates filtered by recipient table (and optionally invite-only).
  static Future<List<OutreachTemplate>> listTemplates({
    required String recipientTable, // 'discovered_salons' | 'businesses'
    bool? inviteOnly,
  }) async {
    final client = SupabaseClientService.client;
    var query = client
        .from('outreach_templates')
        .select(
          'id, name, channel, subject, body_template, category, '
          'recipient_table, is_invite, required_variables, manual_variables, gating_rule',
        )
        .eq('is_active', true);
    final res = await query.order('sort_order');

    final list = (res as List)
        .cast<Map<String, dynamic>>()
        .where((row) {
          final rt = row['recipient_table'] as String?;
          if (rt != null && rt != 'both' && rt != recipientTable) return false;
          if (inviteOnly == true && (row['is_invite'] as bool?) != true) return false;
          if (inviteOnly == false && (row['is_invite'] as bool?) == true) return false;
          return true;
        })
        .map(OutreachTemplate.fromJson)
        .toList();
    return list;
  }

  /// Pre-send eligibility counts for a candidate recipient list.
  static Future<EligibilityCounts> countEligible({
    required String recipientTable,
    required List<String> recipientIds,
    required String channel, // 'wa' | 'email'
    required bool isInvite,
  }) async {
    final client = SupabaseClientService.client;
    final res = await client.rpc('count_eligible_recipients', params: {
      'p_recipient_table': recipientTable,
      'p_recipient_ids': recipientIds,
      'p_channel': channel,
      'p_is_invite': isInvite,
    });
    final list = (res as List?) ?? const [];
    if (list.isEmpty) {
      return EligibilityCounts(eligible: 0, optedOut: 0, cooldown: 0, noChannel: 0, total: 0);
    }
    return EligibilityCounts.fromJson(list.first as Map<String, dynamic>);
  }

  /// Render a template against one recipient — returns the exact text + flags.
  static Future<OutreachPreview> previewTemplate({
    required String templateId,
    required String recipientTable,
    required String recipientId,
    required String channel,
    Map<String, String> manualVars = const {},
  }) async {
    final client = SupabaseClientService.client;
    final response = await client.functions.invoke(
      'outreach-bulk-send',
      body: {
        'action': 'preview',
        'template_id': templateId,
        'recipient_table': recipientTable,
        'recipient_id': recipientId,
        'channel': channel,
        'manual_vars': manualVars,
      },
    );
    if (response.status != 200) {
      final err = response.data is Map ? response.data['error'] : null;
      throw OutreachException('preview failed: $err', statusCode: response.status);
    }
    return OutreachPreview.fromJson(response.data as Map<String, dynamic>);
  }

  /// Enqueue a bulk send job. Returns the job id + first-recipient preview.
  static Future<BulkJobSummary> enqueueBulk({
    required String channel,
    required String templateId,
    required String recipientTable,
    required List<String> recipientIds,
    Map<String, String> manualVars = const {},
  }) async {
    final client = SupabaseClientService.client;
    final response = await client.functions.invoke(
      'outreach-bulk-send',
      body: {
        'action': 'enqueue',
        'channel': channel,
        'template_id': templateId,
        'recipient_table': recipientTable,
        'recipient_ids': recipientIds,
        'manual_vars': manualVars,
      },
    );
    if (response.status != 200) {
      final err = response.data is Map ? response.data['error'] : null;
      throw OutreachException('enqueue failed: $err', statusCode: response.status);
    }
    final data = response.data as Map<String, dynamic>;
    return BulkJobSummary(
      id: data['job_id'] as String,
      total: (data['total'] as num).toInt(),
      preview: (data['preview'] as String?) ?? '',
    );
  }

  /// Cancel a bulk job (queued or draining).
  static Future<void> cancelJob(String jobId) async {
    final client = SupabaseClientService.client;
    final response = await client.functions.invoke(
      'outreach-bulk-send',
      body: {'action': 'cancel_job', 'job_id': jobId},
    );
    if (response.status != 200) {
      final err = response.data is Map ? response.data['error'] : null;
      throw OutreachException('cancel failed: $err', statusCode: response.status);
    }
  }

  /// Validate gating_rule against a single recipient row. Returns null if
  /// allowed, or a human-readable reason if blocked.
  static String? gatingBlockReason({
    required OutreachTemplate template,
    required Map<String, dynamic> row,
  }) {
    final rule = template.gatingRule;
    if (rule == null) return null;
    final minInterest = rule['min_interest_count'];
    if (minInterest is num) {
      final v = (row['interest_count'] as num?)?.toInt() ?? 0;
      if (v < minInterest.toInt()) {
        return 'Esta plantilla requiere mínimo $minInterest búsquedas (actual: $v).';
      }
    }
    final minRating = rule['min_rating'];
    if (minRating is num) {
      final v = (row['rating_average'] as num?)?.toDouble() ??
          (row['average_rating'] as num?)?.toDouble() ??
          0.0;
      if (v < minRating.toDouble()) {
        return 'Esta plantilla requiere ⭐ mínimo $minRating (actual: ${v.toStringAsFixed(1)}).';
      }
    }
    final minReviewCount = rule['min_review_count'];
    if (minReviewCount is num) {
      final v = (row['rating_count'] as num?)?.toInt() ??
          (row['total_reviews'] as num?)?.toInt() ??
          0;
      if (v < minReviewCount.toInt()) {
        return 'Esta plantilla requiere mínimo $minReviewCount reseñas (actual: $v).';
      }
    }
    return null;
  }
}
