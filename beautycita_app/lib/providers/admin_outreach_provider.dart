// Outreach providers — templates + recipient lists + job tracking.
// Wires the existing outreach_templates / bulk_outreach_jobs / outreach-bulk-send
// edge fn (no parallel pipes — uses what's already on prod).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_client.dart';

enum OutreachAudience { discovered, registered }
enum OutreachChannel { wa, email }

extension OutreachAudienceX on OutreachAudience {
  String get label => this == OutreachAudience.discovered ? 'Descubiertos' : 'Registrados';
  String get table => this == OutreachAudience.discovered ? 'discovered_salons' : 'businesses';
}

extension OutreachChannelX on OutreachChannel {
  /// API value sent to outreach-bulk-send.
  String get apiValue => this == OutreachChannel.wa ? 'wa' : 'email';

  /// Stored value in outreach_templates.channel.
  String get templateValue => this == OutreachChannel.wa ? 'whatsapp' : 'email';

  String get label => this == OutreachChannel.wa ? 'WhatsApp' : 'Email';
}

class OutreachTemplate {
  OutreachTemplate({
    required this.id,
    required this.name,
    required this.channel,
    required this.recipientTable,
    required this.subject,
    required this.bodyTemplate,
    required this.category,
    required this.sortOrder,
    required this.isInvite,
  });

  factory OutreachTemplate.fromMap(Map<String, dynamic> m) => OutreachTemplate(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '(sin nombre)',
        channel: (m['channel'] as String?) ?? 'whatsapp',
        recipientTable: (m['recipient_table'] as String?) ?? 'discovered_salons',
        subject: m['subject'] as String?,
        bodyTemplate: (m['body_template'] as String?) ?? '',
        category: (m['category'] as String?) ?? '',
        sortOrder: (m['sort_order'] as int?) ?? 99,
        isInvite: m['is_invite'] == true,
      );

  final String id;
  final String name;
  final String channel;
  final String recipientTable;
  final String? subject;
  final String bodyTemplate;
  final String category;
  final int sortOrder;
  final bool isInvite;
}

class OutreachTemplateFilter {
  const OutreachTemplateFilter({required this.audience, required this.channel});
  final OutreachAudience audience;
  final OutreachChannel channel;

  String get key => '${audience.table}|${channel.templateValue}';

  // == + hashCode are LOAD-BEARING: Riverpod's FutureProvider.family caches
  // by key equality. Without these, every screen rebuild creates a new
  // instance with a different identity → cache miss → refire the query →
  // never reach data state. Symptom: a loading bar that never finishes.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutreachTemplateFilter && other.audience == audience && other.channel == channel);

  @override
  int get hashCode => Object.hash(audience, channel);
}

final outreachTemplatesProvider = FutureProvider.family<List<OutreachTemplate>, OutreachTemplateFilter>((ref, filter) async {
  // inFilter is unambiguous when chained with subsequent .eq()s — the SDK's
  // .or() builder occasionally drops rows when combined with eq filters
  // in a particular order.
  final res = await SupabaseClientService.client
      .from('outreach_templates')
      .select()
      .eq('is_active', true)
      .inFilter('recipient_table', [filter.audience.table, 'both'])
      .eq('channel', filter.channel.templateValue)
      .order('sort_order', ascending: true);
  return (res as List)
      .cast<Map<String, dynamic>>()
      .map(OutreachTemplate.fromMap)
      .toList();
});

class OutreachRecipient {
  OutreachRecipient({required this.id, required this.name, required this.subtitle, required this.phone, required this.email});
  final String id;
  final String name;
  final String subtitle;
  final String? phone;
  final String? email;

  bool get hasContact => (phone?.isNotEmpty == true) || (email?.isNotEmpty == true);
}

final outreachRecipientsProvider = FutureProvider.family<List<OutreachRecipient>, OutreachAudience>((ref, audience) async {
  final c = SupabaseClientService.client;
  if (audience == OutreachAudience.discovered) {
    // discovered_salons uses different column names than businesses:
    //   name → business_name, city → location_city, state → location_state.
    // Filter out rows that already registered (registered_business_id set)
    // and rows that opted out, since those should never receive outreach.
    final res = await c.from('discovered_salons')
        .select('id, business_name, location_city, location_state, phone, email, opted_out, registered_business_id')
        .filter('registered_business_id', 'is', null)
        .neq('opted_out', true)
        .order('updated_at', ascending: false)
        .limit(500);
    return (res as List).cast<Map<String, dynamic>>().map((r) {
      final city = (r['location_city'] as String?) ?? '';
      final state = (r['location_state'] as String?) ?? '';
      return OutreachRecipient(
        id: r['id'] as String,
        name: (r['business_name'] as String?) ?? '(sin nombre)',
        subtitle: [city, state].where((s) => s.isNotEmpty).join(', '),
        phone: r['phone'] as String?,
        email: r['email'] as String?,
      );
    }).toList();
  } else {
    final res = await c.from('businesses')
        .select('id, name, city, state, phone, email, is_active, owner_id')
        .order('created_at', ascending: false)
        .limit(500);
    return (res as List).cast<Map<String, dynamic>>().map((r) {
      final city = (r['city'] as String?) ?? '';
      final state = (r['state'] as String?) ?? '';
      return OutreachRecipient(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '(sin nombre)',
        subtitle: [city, state].where((s) => s.isNotEmpty).join(', '),
        phone: r['phone'] as String?,
        email: r['email'] as String?,
      );
    }).toList();
  }
});

/// Recent bulk_outreach_jobs visible to the caller.
final adminRecentJobsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await SupabaseClientService.client
      .from('bulk_outreach_jobs')
      .select('id, channel, recipient_table, status, total_count, sent_count, skipped_count, failed_count, created_at, completed_at')
      .order('created_at', ascending: false)
      .limit(20);
  return (res as List).cast<Map<String, dynamic>>();
});
