import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:beautycita/providers/rp_provider.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';

class RPChatScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> salon;
  final String channel; // 'whatsapp' or 'email'

  const RPChatScreen({super.key, required this.salon, required this.channel});

  @override
  ConsumerState<RPChatScreen> createState() => _RPChatScreenState();
}

class _RPChatScreenState extends ConsumerState<RPChatScreen> {
  final _messageCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  String get salonId => widget.salon['id'] as String;
  String get salonName => widget.salon['business_name'] as String? ?? 'Salon';
  bool get isEmail => widget.channel == 'email';
  Color get channelColor =>
      isEmail ? const Color(0xFF1565C0) : const Color(0xFF25D366);

  @override
  void dispose() {
    _messageCtrl.dispose();
    _subjectCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(
        rpChatHistoryProvider((salonId: salonId, channel: widget.channel)));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: channelColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFFec4899), Color(0xFF9333ea)]),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${isEmail ? "Email" : "BC WhatsApp"} — $salonName',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildThread(history)),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ── Thread ──

  Widget _buildThread(AsyncValue<List<Map<String, dynamic>>> history) {
    return history.when(
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Text('Sin mensajes — envía el primero',
                style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
          );
        }
        final reversed = messages.reversed.toList();
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: reversed.length,
          itemBuilder: (_, i) {
            final msg = reversed[i];
            final prev = i > 0 ? reversed[i - 1] : null;
            return _buildMessage(msg, prev);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildMessage(
      Map<String, dynamic> msg, Map<String, dynamic>? prev) {
    final channel = msg['channel'] ?? '';
    final text = msg['message_text'] ?? msg['notes'] ?? '';
    final sentAt = msg['sent_at'] ?? '';
    final rpName = msg['rp_display_name'] ?? '';
    final isVisit = channel == 'in_person' || channel == 'phone_call';
    // Date separator
    Widget? dateSeparator;
    final msgDate = DateTime.tryParse(sentAt);
    final prevDate =
        prev != null ? DateTime.tryParse(prev['sent_at'] ?? '') : null;
    if (msgDate != null &&
        (prevDate == null || !_sameDay(msgDate, prevDate))) {
      dateSeparator = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(DateFormat('dd MMM yyyy').format(msgDate),
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
        ),
      );
    }

    if (isVisit) {
      return Column(
        children: [
          if (dateSeparator != null) dateSeparator,
          _systemCard(msg),
        ],
      );
    }

    // All salon_outreach_log entries are outbound
    return Column(
      children: [
        if (dateSeparator != null) dateSeparator,
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: channelColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.white)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rpName.isNotEmpty) ...[
                      Text('— $rpName',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFFec4899))),
                      const SizedBox(width: 8),
                    ],
                    Text(
                        msgDate != null
                            ? DateFormat('HH:mm').format(msgDate)
                            : '',
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _systemCard(Map<String, dynamic> msg) {
    final channel = msg['channel'] ?? '';
    final notes = msg['notes'] ?? '';
    final outcome = msg['outcome'] ?? '';
    final sentAt = msg['sent_at'] ?? '';
    final rpName = msg['rp_display_name'] ?? '';
    final icon = channel == 'in_person' ? Icons.person_pin : Icons.phone;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (outcome.isNotEmpty)
                  Text(outcome,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                if (notes.isNotEmpty)
                  Text(notes,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                Text('$rpName — ${_formatTime(sentAt)}',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Input Area ──

  Widget _buildInputArea() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.description, size: 16),
                label: Text('Plantillas',
                    style: GoogleFonts.poppins(fontSize: 12)),
                onPressed: _showTemplates,
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.person_pin_circle, size: 16),
                label: Text('Registrar visita',
                    style: GoogleFonts.poppins(fontSize: 12)),
                onPressed: _showVisitLog,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isEmail) ...[
            TextField(
              controller: _subjectCtrl,
              decoration: InputDecoration(
                hintText: 'Asunto',
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style:
                    IconButton.styleFrom(backgroundColor: channelColor),
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final sent = await rpSendMessage(
        salonId: salonId,
        channel: widget.channel,
        message: text,
        subject: isEmail ? _subjectCtrl.text.trim() : null,
      );
      if (sent) {
        _messageCtrl.clear();
        if (isEmail) _subjectCtrl.clear();
        ref.invalidate(rpChatHistoryProvider(
            (salonId: salonId, channel: widget.channel)));
        ToastService.showSuccess('Enviado');
      } else {
        ToastService.showError('Error al enviar');
      }
    } catch (e) {
      ToastService.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Template Picker ──

  void _showTemplates() {
    final channel = widget.channel;
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
        final templates = ref.watch(rpTemplatesProvider(channel));
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(20),
            child: templates.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                      child: Text('Sin plantillas disponibles',
                          style: GoogleFonts.poppins(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))));
                }
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (final t in list) {
                  final cat = t['category'] as String? ?? 'general';
                  grouped.putIfAbsent(cat, () => []).add(t);
                }
                return ListView(
                  controller: scrollController,
                  children: [
                    Text('Plantillas',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    for (final entry in grouped.entries) ...[
                      Text(entry.key.toUpperCase(),
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                      const SizedBox(height: 4),
                      ...entry.value.map((t) => ListTile(
                            title: Text(t['name'] ?? '',
                                style:
                                    GoogleFonts.poppins(fontSize: 14)),
                            subtitle: Text(
                              _truncate(
                                  t['body_template'] as String? ?? '',
                                  60),
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              var body =
                                  t['body_template'] as String? ?? '';
                              body = body
                                  .replaceAll('{salon_name}', salonName)
                                  .replaceAll(
                                      '{city}',
                                      widget.salon['location_city']
                                              as String? ??
                                          '')
                                  .replaceAll(
                                      '{rating}',
                                      '${widget.salon['rating_average'] ?? ''}')
                                  .replaceAll(
                                      '{review_count}',
                                      '${widget.salon['rating_count'] ?? ''}')
                                  .replaceAll(
                                      '{interest_count}',
                                      '${widget.salon['interest_count'] ?? 0}');
                              _messageCtrl.text = body;
                              if (isEmail && t['subject'] != null) {
                                _subjectCtrl.text =
                                    (t['subject'] as String)
                                        .replaceAll(
                                            '{salon_name}', salonName);
                              }
                              Navigator.pop(context);
                            },
                          )),
                      const Divider(),
                    ],
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        );
      },
    ),
    );
  }

  // ── Visit Log ──

  void _showVisitLog() {
    String? outcome;
    final notesCtrl = TextEditingController();
    final outcomes = [
      'Interesada',
      'No interesada',
      'Callback',
      'Sin respuesta',
      'Registrada'
    ];

    showBurstDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Registrar Visita',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resultado:', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: outcomes
                    .map((o) => ChoiceChip(
                          label: Text(o,
                              style: GoogleFonts.poppins(fontSize: 12)),
                          selected: outcome == o,
                          onSelected: (_) =>
                              setDialogState(() => outcome = o),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration:
                    const InputDecoration(hintText: 'Notas (opcional)'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: outcome == null
                  ? null
                  : () async {
                      try {
                        final res = await SupabaseClientService.client.functions
                            .invoke('outreach-contact', body: {
                          'action': 'log_call',
                          'discovered_salon_id': salonId,
                          'channel': 'in_person',
                          'outcome':
                              outcome!.toLowerCase().replaceAll(' ', '_'),
                          'notes': notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                        });
                        if (res.status != 200) {
                          if (mounted) {
                            ToastService.showError('Error al registrar visita');
                          }
                          return;
                        }
                        // Update rp_status to 'visited' if currently 'assigned'
                        final currentStatus = widget.salon['rp_status'] as String?;
                        if (currentStatus == 'assigned') {
                          await SupabaseClientService.client
                              .from('discovered_salons')
                              .update({'rp_status': 'visited'})
                              .eq('id', salonId);
                        }
                        ref.invalidate(rpChatHistoryProvider(
                            (salonId: salonId, channel: widget.channel)));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ToastService.showSuccess('Visita registrada');
                        }
                      } catch (e) {
                        if (mounted) {
                          ToastService.showError('Error al registrar visita: $e');
                        }
                      }
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  bool _sameDay(DateTime a, DateTime? b) =>
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt != null ? DateFormat('dd MMM HH:mm').format(dt) : '';
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;
}
