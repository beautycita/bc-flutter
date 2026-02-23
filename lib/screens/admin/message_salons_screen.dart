import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../services/supabase_client.dart';

/// Provider to fetch discovered salons with WA-verified status for messaging.
final _messageSalonsProvider = FutureProvider.family<List<Map<String, dynamic>>, _SalonFilter>(
  (ref, filter) async {
    var query = SupabaseClientService.client
        .from('discovered_salons')
        .select('id, business_name, phone, whatsapp, location_city, rating_average, interest_count, status, wa_verified, outreach_count, last_outreach_at, feature_image_url');

    if (filter.city != null && filter.city!.isNotEmpty) {
      query = query.eq('location_city', filter.city!);
    }
    if (filter.waVerifiedOnly) {
      query = query.eq('wa_verified', true);
    }
    if (filter.hasInterestOnly) {
      query = query.gt('interest_count', 0);
    }

    final data = await query.order('interest_count', ascending: false).limit(100);
    return (data as List).cast<Map<String, dynamic>>();
  },
);

/// Provider to fetch outreach log for a salon.
final _outreachLogProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, salonId) async {
    final data = await SupabaseClientService.client
        .from('salon_outreach_log')
        .select('*')
        .eq('discovered_salon_id', salonId)
        .order('sent_at', ascending: false)
        .limit(20);
    return (data as List).cast<Map<String, dynamic>>();
  },
);

/// Provider for distinct cities in discovered_salons.
final _citiesProvider = FutureProvider<List<String>>((ref) async {
  final data = await SupabaseClientService.client
      .from('discovered_salons')
      .select('location_city')
      .not('location_city', 'is', null)
      .limit(1000);

  final cities = <String>{};
  for (final row in (data as List)) {
    final city = row['location_city'] as String?;
    if (city != null && city.isNotEmpty) cities.add(city);
  }
  final sorted = cities.toList()..sort();
  return sorted;
});

class _SalonFilter {
  final String? city;
  final bool waVerifiedOnly;
  final bool hasInterestOnly;

  const _SalonFilter({
    this.city,
    this.waVerifiedOnly = false,
    this.hasInterestOnly = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SalonFilter &&
          city == other.city &&
          waVerifiedOnly == other.waVerifiedOnly &&
          hasInterestOnly == other.hasInterestOnly;

  @override
  int get hashCode => Object.hash(city, waVerifiedOnly, hasInterestOnly);
}

class MessageSalonsScreen extends ConsumerStatefulWidget {
  const MessageSalonsScreen({super.key});

  @override
  ConsumerState<MessageSalonsScreen> createState() => _MessageSalonsScreenState();
}

class _MessageSalonsScreenState extends ConsumerState<MessageSalonsScreen> {
  String? _selectedCity;
  bool _waVerifiedOnly = false;
  bool _hasInterestOnly = true;
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  _SalonFilter get _filter => _SalonFilter(
        city: _selectedCity,
        waVerifiedOnly: _waVerifiedOnly,
        hasInterestOnly: _hasInterestOnly,
      );

  @override
  Widget build(BuildContext context) {
    final salonsAsync = ref.watch(_messageSalonsProvider(_filter));
    final citiesAsync = ref.watch(_citiesProvider);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // City dropdown
              citiesAsync.when(
                data: (cities) => SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedCity,
                    decoration: InputDecoration(
                      labelText: 'Ciudad',
                      labelStyle: GoogleFonts.nunito(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...cities.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _selectedCity = v),
                  ),
                ),
                loading: () => const SizedBox(width: 180, height: 40, child: LinearProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
              FilterChip(
                label: Text('WA verificado', style: GoogleFonts.nunito(fontSize: 12)),
                selected: _waVerifiedOnly,
                onSelected: (v) => setState(() => _waVerifiedOnly = v),
              ),
              FilterChip(
                label: Text('Con interes', style: GoogleFonts.nunito(fontSize: 12)),
                selected: _hasInterestOnly,
                onSelected: (v) => setState(() => _hasInterestOnly = v),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Salon list
          Expanded(
            child: salonsAsync.when(
              data: (salons) {
                if (salons.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay salones con estos filtros',
                      style: GoogleFonts.nunito(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: salons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final salon = salons[index];
                    return _SalonTile(
                      salon: salon,
                      onMessage: () => _showMessageDialog(salon),
                      onViewLog: () => _showOutreachLog(salon),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageDialog(Map<String, dynamic> salon) {
    final name = salon['business_name'] ?? 'Salon';
    final phone = salon['whatsapp'] ?? salon['phone'] ?? '';
    final interestCount = salon['interest_count'] ?? 0;
    final salonId = salon['id'] as String;

    // Pre-fill with appropriate outreach template
    final link = 'https://beautycita.com/salon/$salonId';
    String template;
    if (interestCount >= 20) {
      template = '$name, $interestCount clientas y contando. Los salones registrados reciben su primera reserva en promedio en 48 hrs: $link';
    } else if (interestCount >= 10) {
      template = '$name, $interestCount clientas te buscan. Estas perdiendo reservas cada semana. 60 seg y listo: $link';
    } else if (interestCount >= 5) {
      template = '$name, $interestCount personas intentaron reservar contigo esta semana. BeautyCita te conecta con ellas, gratis: $link';
    } else if (interestCount >= 3) {
      template = '$name, 3 clientas te buscan en BeautyCita. No pierdas reservas. Registrate gratis: $link';
    } else {
      template = 'Hola $name! Una clienta quiere reservar contigo en BeautyCita. Registrate gratis en 60 seg: $link';
    }

    _messageController.text = template;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mensaje a $name', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tel: $phone', style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 6,
                style: GoogleFonts.nunito(fontSize: 14),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Escribe el mensaje...',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'TEST MODE: se enviara a tu esposa, no al salon',
                style: GoogleFonts.nunito(fontSize: 11, color: Colors.orange[700], fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _sending ? null : () => _sendMessage(ctx, salon),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2185B),
              foregroundColor: Colors.white,
            ),
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(BuildContext dialogCtx, Map<String, dynamic> salon) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _sending = true);

    try {
      await SupabaseClientService.client.functions.invoke(
        'outreach-discovered-salon',
        body: {
          'action': 'invite',
          'discovered_salon_id': salon['id'],
        },
      );

      if (mounted && dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mensaje enviado (test mode)', style: GoogleFonts.nunito()),
            backgroundColor: Colors.green[600],
          ),
        );
        // Refresh the list
        ref.invalidate(_messageSalonsProvider(_filter));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.nunito()),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showOutreachLog(Map<String, dynamic> salon) {
    final salonId = salon['id'] as String;
    final name = salon['business_name'] ?? 'Salon';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Consumer(
          builder: (context, ref, _) {
            final logAsync = ref.watch(_outreachLogProvider(salonId));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Historial: $name', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: logAsync.when(
                    data: (logs) {
                      if (logs.isEmpty) {
                        return Center(child: Text('Sin historial', style: GoogleFonts.nunito(color: Colors.grey)));
                      }
                      return ListView.builder(
                        controller: scrollCtrl,
                        itemCount: logs.length,
                        itemBuilder: (_, i) {
                          final log = logs[i];
                          final sentAt = DateTime.tryParse(log['sent_at'] ?? '')?.toLocal();
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              log['test_mode'] == true ? Icons.science : Icons.send,
                              color: log['test_mode'] == true ? Colors.orange : Colors.green,
                              size: 20,
                            ),
                            title: Text(
                              log['message_text'] ?? '',
                              style: GoogleFonts.nunito(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${log['channel']} | ${sentAt != null ? "${sentAt.day}/${sentAt.month} ${sentAt.hour}:${sentAt.minute.toString().padLeft(2, '0')}" : ""}${log['test_mode'] == true ? " (TEST)" : ""}',
                              style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SalonTile extends StatelessWidget {
  final Map<String, dynamic> salon;
  final VoidCallback onMessage;
  final VoidCallback onViewLog;

  const _SalonTile({
    required this.salon,
    required this.onMessage,
    required this.onViewLog,
  });

  @override
  Widget build(BuildContext context) {
    final name = salon['business_name'] ?? 'Sin nombre';
    final city = salon['location_city'] ?? '';
    final rating = (salon['rating_average'] as num?)?.toDouble();
    final interest = salon['interest_count'] as int? ?? 0;
    final outreachCount = salon['outreach_count'] as int? ?? 0;
    final waVerified = salon['wa_verified'] == true;
    final status = salon['status'] as String? ?? 'discovered';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: waVerified ? Colors.green[50] : Colors.grey[100],
        child: Icon(
          waVerified ? Icons.verified : Icons.store,
          color: waVerified ? Colors.green : Colors.grey,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (interest > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFC2185B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$interest',
                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFC2185B)),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '$city${rating != null ? " | $rating" : ""} | $status${outreachCount > 0 ? " | $outreachCount msgs" : ""}',
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.history, size: 20),
            tooltip: 'Historial',
            onPressed: onViewLog,
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFFC2185B)),
            tooltip: 'Enviar mensaje',
            onPressed: onMessage,
          ),
        ],
      ),
    );
  }
}
