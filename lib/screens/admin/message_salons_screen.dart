import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../services/supabase_client.dart';

/// Provider to fetch discovered salons with WA-verified status for messaging.
final _messageSalonsProvider = FutureProvider.family<List<Map<String, dynamic>>, _SalonFilter>(
  (ref, filter) async {
    var query = SupabaseClientService.client
        .from('discovered_salons')
        .select('id, business_name, phone, whatsapp, location_city, location_address, latitude, longitude, rating_average, interest_count, status, whatsapp_verified, outreach_count, last_outreach_at, feature_image_url');

    if (filter.city != null && filter.city!.isNotEmpty) {
      query = query.eq('location_city', filter.city!);
    }
    if (filter.waVerifiedOnly) {
      query = query.eq('whatsapp_verified', true);
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

/// Provider for distinct cities grouped by country in discovered_salons.
final _citiesByCountryProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  final data = await SupabaseClientService.client
      .from('discovered_salons')
      .select('location_city, country')
      .not('location_city', 'is', null)
      .limit(1000);

  final grouped = <String, Set<String>>{};
  for (final row in (data as List)) {
    final city = row['location_city'] as String?;
    final country = row['country'] as String? ?? 'Otro';
    if (city != null && city.isNotEmpty) {
      grouped.putIfAbsent(country, () => <String>{}).add(city);
    }
  }
  // Sort countries and cities within each
  final result = <String, List<String>>{};
  final sortedCountries = grouped.keys.toList()..sort();
  for (final country in sortedCountries) {
    result[country] = grouped[country]!.toList()..sort();
  }
  return result;
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

String _countryName(String code) {
  switch (code.toUpperCase()) {
    case 'MX': return 'Mexico';
    case 'US': return 'Estados Unidos';
    case 'CO': return 'Colombia';
    case 'AR': return 'Argentina';
    case 'ES': return 'Espana';
    case 'CL': return 'Chile';
    case 'PE': return 'Peru';
    case 'BR': return 'Brasil';
    default: return code;
  }
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
    final citiesAsync = ref.watch(_citiesByCountryProvider);

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
              // City dropdown grouped by country
              citiesAsync.when(
                data: (citiesByCountry) {
                  final items = <DropdownMenuItem<String?>>[];
                  items.add(const DropdownMenuItem(value: null, child: Text('Todas')));
                  final countries = citiesByCountry.keys.toList();
                  for (int ci = 0; ci < countries.length; ci++) {
                    final country = countries[ci];
                    final cities = citiesByCountry[country]!;
                    // Country header (disabled, acts as separator)
                    if (countries.length > 1) {
                      final countryLabel = _countryName(country);
                      items.add(DropdownMenuItem<String?>(
                        enabled: false,
                        value: '__header_$country',
                        child: Text(countryLabel,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700,
                            color: const Color(0xFFC2185B))),
                      ));
                    }
                    for (final c in cities) {
                      items.add(DropdownMenuItem(value: c,
                        child: Padding(
                          padding: EdgeInsets.only(left: countries.length > 1 ? 8 : 0),
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        )));
                    }
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
                    child: DropdownButtonFormField<String?>(
                      value: _selectedCity,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Ciudad',
                        labelStyle: GoogleFonts.nunito(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      items: items,
                      onChanged: (v) {
                        if (v != null && v.startsWith('__header_')) return;
                        setState(() => _selectedCity = v);
                      },
                    ),
                  );
                },
                loading: () => const SizedBox(width: 200, height: 40, child: LinearProgressIndicator()),
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
                return ListView.builder(
                  itemCount: salons.length,
                  itemBuilder: (context, index) {
                    final salon = salons[index];
                    return _SalonCard(
                      salon: salon,
                      onTap: () => _showSalonDetail(salon),
                      onMessage: () => _showMessageDialog(salon),
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

    // Pre-fill with launch announcement template
    const template = '✨ ¡Bienvenidos a BeautyCita.com! ✨\n\n'
        'BeautyCita nace con una misión clara:\n'
        '💄 Conectar a clientes que quieren verse increíbles\n'
        '💼 Con profesionales que desean crecer y organizar su negocio\n\n'
        'Si eres cliente:\n'
        '📅 Agenda tus citas fácil y rápido\n'
        '✨ Descubre nuevos servicios\n'
        '💖 Vive una experiencia sin estrés\n\n'
        'Si eres profesional de belleza:\n'
        '📲 Organiza tu agenda\n'
        '📈 Atrae más clientes\n'
        '💅 Haz crecer tu marca personal\n\n'
        'BeautyCita.com es el punto de encuentro donde la belleza y la organización se unen 💕\n\n'
        'Gracias por ser parte de este sueño 💗\n'
        'Esto apenas comienza 🚀\n\n'
        '#BeautyCita #AgendaTuBelleza #Emprendedoras #BeautyTech';

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
      final response = await SupabaseClientService.client.functions.invoke(
        'outreach-discovered-salon',
        body: {
          'action': 'cold_outreach',
          'discovered_salon_id': salon['id'],
          'message': message,
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

  void _showSalonDetail(Map<String, dynamic> salon) {
    final salonId = salon['id'] as String;
    final nameCtrl = TextEditingController(text: salon['business_name'] ?? '');
    final phoneCtrl = TextEditingController(text: salon['phone'] ?? '');
    final waCtrl = TextEditingController(text: salon['whatsapp'] ?? '');
    final cityCtrl = TextEditingController(text: salon['location_city'] ?? '');
    final ratingVal = (salon['rating_average'] as num?)?.toDouble();
    final interest = salon['interest_count'] as int? ?? 0;
    final outreach = salon['outreach_count'] as int? ?? 0;
    final waVerified = salon['whatsapp_verified'] == true;
    final status = salon['status'] as String? ?? 'discovered';
    final lastOutreach = salon['last_outreach_at'] as String?;
    final imageUrl = salon['feature_image_url'] as String?;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: Colors.grey[200],
                            child: const Icon(Icons.store, color: Colors.grey))),
                      )
                    else
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.store, color: Colors.grey, size: 28),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(salon['business_name'] ?? 'Sin nombre',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: waVerified ? Colors.green[50] : Colors.orange[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(waVerified ? 'WA Verificado' : 'Sin verificar',
                                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
                                    color: waVerified ? Colors.green[700] : Colors.orange[700])),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC2185B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(status,
                                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
                                    color: const Color(0xFFC2185B))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Stats row
                Wrap(
                  spacing: 12,
                  children: [
                    if (ratingVal != null)
                      _StatChip(icon: Icons.star, label: '$ratingVal', color: Colors.amber),
                    _StatChip(icon: Icons.favorite, label: '$interest interes', color: const Color(0xFFC2185B)),
                    _StatChip(icon: Icons.send, label: '$outreach envios', color: Colors.blue),
                  ],
                ),
                const Divider(height: 24),
                // Editable fields
                _EditField(label: 'Nombre', controller: nameCtrl),
                const SizedBox(height: 10),
                _EditField(
                  label: waVerified ? 'WhatsApp (verificado)' : 'Telefono',
                  controller: waVerified ? waCtrl : phoneCtrl,
                ),
                const SizedBox(height: 10),
                // City dropdown grouped by country
                Consumer(builder: (context, ref, _) {
                  final citiesAsync = ref.watch(_citiesByCountryProvider);
                  return citiesAsync.when(
                    data: (citiesByCountry) {
                      final items = <DropdownMenuItem<String>>[];
                      final countries = citiesByCountry.keys.toList();
                      for (final country in countries) {
                        final cities = citiesByCountry[country]!;
                        if (countries.length > 1) {
                          items.add(DropdownMenuItem<String>(
                            enabled: false,
                            value: '__hdr_$country',
                            child: Text(_countryName(country),
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700,
                                color: const Color(0xFFC2185B))),
                          ));
                        }
                        for (final c in cities) {
                          items.add(DropdownMenuItem(value: c,
                            child: Padding(
                              padding: EdgeInsets.only(left: countries.length > 1 ? 8 : 0),
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            )));
                        }
                      }
                      // Ensure current value is in the list
                      final currentVal = cityCtrl.text.trim();
                      final validValues = items.where((i) => i.enabled != false).map((i) => i.value).toSet();
                      return DropdownButtonFormField<String>(
                        value: validValues.contains(currentVal) ? currentVal : null,
                        decoration: InputDecoration(
                          labelText: 'Ciudad',
                          labelStyle: GoogleFonts.nunito(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        items: items,
                        onChanged: (v) {
                          if (v != null && !v.startsWith('__hdr_')) {
                            cityCtrl.text = v;
                          }
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => _EditField(label: 'Ciudad', controller: cityCtrl),
                  );
                }),
                if (lastOutreach != null) ...[
                  const SizedBox(height: 12),
                  Text('Ultimo contacto: ${DateTime.tryParse(lastOutreach)?.toLocal().toString().substring(0, 16) ?? lastOutreach}',
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(height: 16),
                // Action buttons — icons with labels below, no wrapping
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionIcon(
                      icon: Icons.history,
                      label: 'Historial',
                      color: Colors.grey[700]!,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showOutreachLog(salon);
                      },
                    ),
                    _ActionIcon(
                      icon: Icons.send_rounded,
                      label: 'Mensaje',
                      color: const Color(0xFFC2185B),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showMessageDialog(salon);
                      },
                    ),
                    Builder(builder: (_) {
                      final lat = (salon['latitude'] as num?)?.toDouble();
                      final lng = (salon['longitude'] as num?)?.toDouble();
                      final hasCoords = lat != null && lng != null;
                      return _ActionIcon(
                        icon: Icons.map_rounded,
                        label: 'Mapa',
                        color: hasCoords ? Colors.blue[700]! : Colors.grey[400]!,
                        onTap: hasCoords ? () {
                          // Mapbox street view style URL
                          final url = Uri.parse(
                            'https://www.google.com/maps/@$lat,$lng,3a,75y,90t/data=!3m6!1e1!3m4!1s!2e0!7i16384!8i8192');
                          final fallback = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                          launchUrl(fallback, mode: LaunchMode.externalApplication);
                        } : null,
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                // Save changes
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: saving ? null : () async {
                      setDialogState(() => saving = true);
                      try {
                        await SupabaseClientService.client
                            .from('discovered_salons')
                            .update({
                              'business_name': nameCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                              'whatsapp': waCtrl.text.trim(),
                              'location_city': cityCtrl.text.trim(),
                            })
                            .eq('id', salonId);
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.invalidate(_messageSalonsProvider(_filter));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Salon actualizado', style: GoogleFonts.nunito()),
                              backgroundColor: Colors.green[600]),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[600]),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDialogState(() => saving = false);
                      }
                    },
                    icon: saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 16),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                    label: Text('Guardar', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Dispose controllers when dialog closes
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

class _SalonCard extends StatelessWidget {
  final Map<String, dynamic> salon;
  final VoidCallback onTap;
  final VoidCallback onMessage;

  const _SalonCard({
    required this.salon,
    required this.onTap,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = salon['business_name'] ?? 'Sin nombre';
    final city = salon['location_city'] ?? '';
    final rating = (salon['rating_average'] as num?)?.toDouble();
    final interest = salon['interest_count'] as int? ?? 0;
    final outreachCount = salon['outreach_count'] as int? ?? 0;
    final waVerified = salon['whatsapp_verified'] == true;
    final status = salon['status'] as String? ?? 'discovered';
    final imageUrl = salon['feature_image_url'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar / image
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(waVerified)),
                  )
                else
                  _buildPlaceholder(waVerified),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                          ),
                          if (waVerified) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified, size: 14, color: Colors.green[600]),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$city${rating != null ? " | $rating" : ""} | $status',
                        style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Chips row
                      Row(
                        children: [
                          if (interest > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC2185B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$interest interes',
                                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: const Color(0xFFC2185B))),
                            ),
                          if (outreachCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$outreachCount envios',
                                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: Colors.blue[700])),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Send button
                IconButton(
                  icon: const Icon(Icons.send_rounded, size: 20, color: Color(0xFFC2185B)),
                  tooltip: 'Enviar mensaje',
                  onPressed: onMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool verified) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: verified ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        verified ? Icons.verified : Icons.store,
        color: verified ? Colors.green : Colors.grey,
        size: 22,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _EditField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.nunito(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionIcon({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap != null ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.nunito(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
