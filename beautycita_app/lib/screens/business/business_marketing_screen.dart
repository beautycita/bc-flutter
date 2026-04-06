import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _automatedMessagesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  final data = await SupabaseClientService.client
      .from('automated_messages')
      .select()
      .eq('business_id', bizId)
      .order('trigger_type');
  return (data as List).cast<Map<String, dynamic>>();
});

final _messageLogProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  final data = await SupabaseClientService.client
      .from('automated_message_log')
      .select()
      .eq('business_id', bizId)
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
});

/// Per-trigger-type stats: {trigger_type: {sent: N, responded: N}}
final _messageStatsProvider =
    FutureProvider.family<Map<String, Map<String, int>>, String>((ref, bizId) async {
  final stats = <String, Map<String, int>>{};
  try {
    final data = await SupabaseClientService.client
        .from('automated_message_log')
        .select('trigger_type, status')
        .eq('business_id', bizId);
    final rows = (data as List).cast<Map<String, dynamic>>();
    for (final row in rows) {
      final type = row['trigger_type'] as String? ?? '';
      final status = row['status'] as String? ?? '';
      stats.putIfAbsent(type, () => {'sent': 0, 'responded': 0});
      if (status == 'sent') stats[type]!['sent'] = (stats[type]!['sent'] ?? 0) + 1;
      if (status == 'responded') stats[type]!['responded'] = (stats[type]!['responded'] ?? 0) + 1;
    }
  } catch (_) {
    // Table may not exist yet — return empty stats
  }
  return stats;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BusinessMarketingScreen extends ConsumerStatefulWidget {
  const BusinessMarketingScreen({super.key});

  @override
  ConsumerState<BusinessMarketingScreen> createState() => _BusinessMarketingScreenState();
}

class _BusinessMarketingScreenState extends ConsumerState<BusinessMarketingScreen> {
  static const _triggerTypes = [
    _TriggerDef('post_appointment', 'Despues de la cita', 'Envia un mensaje de agradecimiento despues de completar la cita',
        Icons.check_circle_outline, Color(0xFF059669), 24,
        'Gracias por visitarnos, {cliente}! Esperamos que hayas disfrutado tu {servicio}. Te esperamos pronto.'),
    _TriggerDef('review_request', 'Solicitar resena', 'Pide al cliente que deje una resena despues de su visita',
        Icons.star_outline, Color(0xFFF59E0B), 48,
        'Hola {cliente}! Como fue tu experiencia con tu {servicio}? Nos encantaria tu resena. Tu opinion nos ayuda a mejorar.'),
    _TriggerDef('no_show_followup', 'Seguimiento no-show', 'Contacta a clientes que no se presentaron',
        Icons.person_off_outlined, Color(0xFFEF4444), 2,
        'Hola {cliente}, notamos que no pudiste asistir a tu cita de {servicio}. Queremos saber si todo esta bien. Agenda de nuevo cuando gustes.'),
    _TriggerDef('birthday', 'Felicitacion cumpleanos', 'Envia un mensaje en el cumpleanos del cliente',
        Icons.cake_outlined, Color(0xFFEC4899), 0,
        'Feliz cumpleanos, {cliente}! Como regalo, te damos un 10% de descuento en tu proximo servicio. Valido por 30 dias.'),
    _TriggerDef('inactive_client', 'Cliente inactivo', 'Re-engancha a clientes que no han visitado en 30+ dias',
        Icons.schedule_outlined, Color(0xFF8B5CF6), 720,
        'Hola {cliente}! Te extrañamos. Ha pasado un tiempo desde tu ultima visita. Agenda tu proximo {servicio} y recibe atencion preferencial.'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        final bizId = biz['id'] as String;
        final messagesAsync = ref.watch(_automatedMessagesProvider(bizId));
        final logAsync = ref.watch(_messageLogProvider(bizId));
        final statsAsync = ref.watch(_messageStatsProvider(bizId));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_automatedMessagesProvider(bizId));
            ref.invalidate(_messageLogProvider(bizId));
            ref.invalidate(_messageStatsProvider(bizId));
          },
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.campaign_outlined, size: 24, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mensajes Automaticos', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('Configura mensajes que se envian automaticamente',
                            style: GoogleFonts.nunito(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Message type cards
              messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
                data: (existing) {
                  final existingMap = <String, Map<String, dynamic>>{};
                  for (final m in existing) {
                    existingMap[m['trigger_type'] as String] = m;
                  }
                  final statsMap = statsAsync.valueOrNull ?? {};

                  return Column(
                    children: _triggerTypes.map((trigger) {
                      final saved = existingMap[trigger.type];
                      final triggerStats = statsMap[trigger.type];
                      return _MessageTypeCard(
                        trigger: trigger,
                        saved: saved,
                        bizId: bizId,
                        sentCount: triggerStats?['sent'] ?? 0,
                        responseCount: triggerStats?['responded'] ?? 0,
                        onSaved: () {
                          ref.invalidate(_automatedMessagesProvider(bizId));
                          ref.invalidate(_messageStatsProvider(bizId));
                        },
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Recent activity log
              Text('Actividad Reciente', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              logAsync.when(
                loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, _) => Text('Error: $e'),
                data: (logs) {
                  if (logs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Los mensajes enviados apareceran aqui',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(color: colors.onSurface.withValues(alpha: 0.4)),
                      ),
                    );
                  }

                  return Column(
                    children: logs.take(10).map((log) {
                      final type = log['trigger_type'] as String? ?? '';
                      final status = log['status'] as String? ?? '';
                      final created = DateTime.tryParse(log['created_at']?.toString() ?? '');
                      final trigger = _triggerTypes.where((t) => t.type == type).firstOrNull;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(trigger?.icon ?? Icons.message, size: 16, color: trigger?.color ?? colors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(trigger?.label ?? type,
                                  style: GoogleFonts.nunito(fontSize: 13)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: status == 'sent' ? const Color(0xFF059669).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(status, style: GoogleFonts.nunito(fontSize: 10,
                                  color: status == 'sent' ? const Color(0xFF059669) : Colors.red,
                                  fontWeight: FontWeight.w700)),
                            ),
                            if (created != null) ...[
                              const SizedBox(width: 8),
                              Text(DateFormat('dd/MM HH:mm').format(created.toLocal()),
                                  style: GoogleFonts.nunito(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Trigger definition
// ---------------------------------------------------------------------------

class _TriggerDef {
  final String type;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final int defaultDelayHours;
  final String defaultTemplate;

  const _TriggerDef(this.type, this.label, this.description, this.icon, this.color, this.defaultDelayHours, this.defaultTemplate);
}

// ---------------------------------------------------------------------------
// Message type card
// ---------------------------------------------------------------------------

class _MessageTypeCard extends StatefulWidget {
  final _TriggerDef trigger;
  final Map<String, dynamic>? saved;
  final String bizId;
  final int sentCount;
  final int responseCount;
  final VoidCallback onSaved;

  const _MessageTypeCard({required this.trigger, this.saved, required this.bizId, this.sentCount = 0, this.responseCount = 0, required this.onSaved});

  @override
  State<_MessageTypeCard> createState() => _MessageTypeCardState();
}

class _MessageTypeCardState extends State<_MessageTypeCard> {
  late bool _isActive;
  late TextEditingController _templateCtrl;
  late int _delayHours;
  late String _channel;
  bool _expanded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.saved?['is_active'] as bool? ?? false;
    _templateCtrl = TextEditingController(
      text: widget.saved?['message_template'] as String? ?? widget.trigger.defaultTemplate,
    );
    _delayHours = widget.saved?['delay_hours'] as int? ?? widget.trigger.defaultDelayHours;
    _channel = widget.saved?['channel'] as String? ?? 'push';
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseClientService.client.from('automated_messages').upsert({
        if (widget.saved != null) 'id': widget.saved!['id'],
        'business_id': widget.bizId,
        'trigger_type': widget.trigger.type,
        'delay_hours': _delayHours,
        'channel': _channel,
        'message_template': _templateCtrl.text.trim(),
        'is_active': _isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'business_id,trigger_type');

      widget.onSaved();
      if (mounted) ToastService.showSuccess('${widget.trigger.label} guardado');
    } catch (e) {
      ToastService.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final t = widget.trigger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _isActive ? t.color.withValues(alpha: 0.3) : colors.outline.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(t.icon, size: 20, color: t.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(t.description, style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Enviados: ${widget.sentCount > 0 ? widget.sentCount.toString() : '--'}',
                              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Respuestas: ${widget.responseCount > 0 ? widget.responseCount.toString() : '--'}',
                              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (v) {
                      setState(() => _isActive = v);
                      _save();
                    },
                    activeColor: t.color,
                  ),
                ],
              ),
            ),
          ),

          // Expanded editor
          if (_expanded) ...[
            Divider(height: 1, color: colors.outline.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Template
                  Text('Mensaje', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _templateCtrl,
                    maxLines: 3,
                    style: GoogleFonts.nunito(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Usa {cliente} y {servicio} como variables',
                      hintStyle: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Variables: {cliente}, {servicio}, {salon}',
                      style: GoogleFonts.nunito(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),

                  const SizedBox(height: 14),

                  // Delay + Channel
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Enviar despues de', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            DropdownButton<int>(
                              value: _delayHours,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('Inmediato')),
                                DropdownMenuItem(value: 1, child: Text('1 hora')),
                                DropdownMenuItem(value: 2, child: Text('2 horas')),
                                DropdownMenuItem(value: 4, child: Text('4 horas')),
                                DropdownMenuItem(value: 12, child: Text('12 horas')),
                                DropdownMenuItem(value: 24, child: Text('24 horas')),
                                DropdownMenuItem(value: 48, child: Text('48 horas')),
                                DropdownMenuItem(value: 72, child: Text('3 dias')),
                                DropdownMenuItem(value: 168, child: Text('1 semana')),
                                DropdownMenuItem(value: 720, child: Text('30 dias')),
                              ],
                              onChanged: (v) => setState(() => _delayHours = v ?? _delayHours),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Canal', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            DropdownButton<String>(
                              value: _channel,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'push', child: Text('Push')),
                                DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                                DropdownMenuItem(value: 'both', child: Text('Ambos')),
                              ],
                              onChanged: (v) => setState(() => _channel = v ?? _channel),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Guardar', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
