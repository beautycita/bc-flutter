import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:beautycita/config/routes.dart';
import 'package:beautycita/providers/rp_provider.dart';
import 'package:beautycita/services/toast_service.dart';

class RPCentroScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> salon;
  const RPCentroScreen({super.key, required this.salon});

  @override
  ConsumerState<RPCentroScreen> createState() => _RPCentroScreenState();
}

class _RPCentroScreenState extends ConsumerState<RPCentroScreen> {
  Map<String, dynamic> get salon => widget.salon;
  String get salonId => salon['id'] as String;

  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(rpChecklistProvider(salonId));
    final nextMeeting = ref.watch(rpNextMeetingProvider(salonId));
    final chatHistory =
        ref.watch(rpChatHistoryProvider((salonId: salonId, channel: null)));

    final requiredChecked = checklist.whenOrNull(
          data: (items) => items
              .where((i) =>
                  kRpChecklistRequired.contains(i['item_key']) &&
                  i['checked_at'] != null)
              .length,
        ) ??
        0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(salon['business_name'] ?? 'Salon',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rpChecklistProvider(salonId));
          ref.invalidate(rpNextMeetingProvider(salonId));
          ref.invalidate(
              rpChatHistoryProvider((salonId: salonId, channel: null)));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(requiredChecked),
            const SizedBox(height: 20),
            _buildActionGrid(requiredChecked),
            const SizedBox(height: 20),
            _buildUltimoContacto(chatHistory),
            const SizedBox(height: 16),
            _buildProximaReunion(nextMeeting),
            const SizedBox(height: 16),
            _buildQuickLinks(),
            const SizedBox(height: 32),
            _buildCerrarProceso(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader(int requiredChecked) {
    final city = salon['location_city'] ?? '';
    final state = salon['location_state'] ?? '';
    final rating = salon['rating_average'];
    final reviews = salon['rating_count'] ?? 0;
    final status = salon['rp_status'] ?? 'unassigned';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (city.isNotEmpty || state.isNotEmpty)
          Text(
              '$city${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}$state',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Row(
          children: [
            if (rating != null) ...[
              Icon(Icons.star, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Text('$rating',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              Text(' ($reviews)',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(width: 12),
            ],
            _statusBadge(status),
            const Spacer(),
            Text('$requiredChecked/${kRpChecklistRequired.length} requeridos',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    const labels = {
      'unassigned': 'Sin asignar',
      'assigned': 'Sin visitar',
      'visited': 'Contactado',
      'contacted': 'Contactado',
      'onboarding': 'En onboarding',
      'onboarding_complete': 'Completado',
      'converted': 'Convertido',
      'declined': 'Rechazado',
    };
    final colors = {
      'unassigned': Colors.grey,
      'assigned': Colors.blue,
      'visited': Colors.orange,
      'contacted': Colors.orange,
      'onboarding': Colors.purple,
      'onboarding_complete': Colors.green,
      'converted': Colors.green.shade800,
      'declined': Colors.red,
    };
    final label = labels[status] ?? status;
    final color = colors[status] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── Action Grid ──

  Widget _buildActionGrid(int requiredChecked) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.chat,
                label: 'BC WhatsApp',
                subtitle: 'Enviar como BeautyCita',
                gradient: const [Color(0xFF25D366), Color(0xFF128C7E)],
                onTap: () => context.push(AppRoutes.rpChat,
                    extra: {'salon': salon, 'channel': 'whatsapp'}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.email,
                label: 'Email',
                subtitle: 'Enviar como BeautyCita',
                gradient: const [Color(0xFF2196F3), Color(0xFF1565C0)],
                onTap: () => context.push(AppRoutes.rpChat,
                    extra: {'salon': salon, 'channel': 'email'}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCardOutline(
                icon: Icons.checklist,
                label: 'Checklist',
                subtitle: '$requiredChecked de ${kRpChecklistRequired.length} requeridos',
                onTap: _showChecklist,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCardOutline(
                icon: Icons.calendar_month,
                label: 'Agendar',
                subtitle: 'Solicitar reunión',
                onTap: _showMeetingDialog,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              Text(subtitle,
                  style:
                      GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCardOutline({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.grey.shade700, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Último Contacto ──

  Widget _buildUltimoContacto(
      AsyncValue<List<Map<String, dynamic>>> chatHistory) {
    return chatHistory.when(
      data: (history) {
        if (history.isEmpty) {
          return _sectionCard('Último Contacto',
              child: Text('Sin contacto registrado',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade400)));
        }
        final last = history.first;
        final channel = last['channel'] ?? '';
        final time = last['sent_at'] ?? '';
        final text = last['message_text'] ?? last['notes'] ?? '';
        final icon = channel == 'whatsapp'
            ? Icons.chat
            : channel == 'email'
                ? Icons.email
                : Icons.person;

        return _sectionCard('Último Contacto',
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text.length > 80 ? '${text.substring(0, 80)}...' : text,
                    style: GoogleFonts.poppins(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_timeAgo(time),
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade400)),
              ],
            ));
      },
      loading: () => _sectionCard('Último Contacto',
          child: const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => _sectionCard('Último Contacto',
          child: Text('Error',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.red))),
    );
  }

  // ── Próxima Reunión ──

  Widget _buildProximaReunion(
      AsyncValue<Map<String, dynamic>?> nextMeeting) {
    return nextMeeting.when(
      data: (meeting) {
        if (meeting == null) {
          return _sectionCard('Próxima Reunión',
              child: Text('Sin reuniones programadas',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade400)));
        }
        final date = DateTime.tryParse(meeting['proposed_at'] ?? '');
        final status = meeting['status'] ?? 'pending';
        final note = meeting['note'] ?? '';
        const statusColors = {
          'pending': Colors.amber,
          'confirmed': Colors.green,
          'denied': Colors.red,
          'rescheduled': Colors.orange,
        };
        const statusLabels = {
          'pending': 'Pendiente',
          'confirmed': 'Confirmada',
          'denied': 'Rechazada',
          'rescheduled': 'Reagendada',
        };
        final color = statusColors[status] ?? Colors.grey;

        return _sectionCard('Próxima Reunión',
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (date != null)
                        Text(
                            DateFormat('dd MMM yyyy, HH:mm', 'es')
                                .format(date),
                            style: GoogleFonts.poppins(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      if (note.isNotEmpty)
                        Text(note,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusLabels[status] ?? status,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
              ],
            ));
      },
      loading: () => _sectionCard('Próxima Reunión',
          child: const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => _sectionCard('Próxima Reunión',
          child: Text('Error',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.red))),
    );
  }

  Widget _sectionCard(String title, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // ── Quick Links ──

  Widget _buildQuickLinks() {
    final web = salon['website'] as String?;
    final ig = salon['instagram_url'] as String?;
    final fb = salon['facebook_url'] as String?;
    final lat = salon['latitude'];
    final lng = salon['longitude'];

    final links = <Widget>[];
    if (web != null && web.isNotEmpty) {
      links.add(_linkChip(Icons.language, 'Web', web));
    }
    if (ig != null && ig.isNotEmpty) {
      links.add(_linkChip(Icons.camera_alt, 'Instagram', ig));
    }
    if (fb != null && fb.isNotEmpty) {
      links.add(_linkChip(Icons.facebook, 'Facebook', fb));
    }
    if (lat != null && lng != null) {
      links.add(_linkChip(Icons.navigation, 'Navegar',
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'));
    }
    if (links.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: links);
  }

  Widget _linkChip(IconData icon, String label, String url) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      onPressed: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }

  // ── Cerrar Proceso ──

  Widget _buildCerrarProceso() {
    return OutlinedButton.icon(
      onPressed: _showCerrarDialog,
      icon: const Icon(Icons.close, color: Colors.red),
      label: Text('Cerrar Proceso',
          style: GoogleFonts.poppins(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size(double.infinity, 48),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Checklist Sheet ──

  void _showChecklist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChecklistSheet(salonId: salonId),
    );
  }

  // ── Meeting Dialog ──

  void _showMeetingDialog() {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Solicitar Reunión',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(selectedDate != null
                    ? DateFormat('dd MMM yyyy').format(selectedDate!)
                    : 'Seleccionar fecha'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) setDialogState(() => selectedDate = d);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(selectedTime != null
                    ? selectedTime!.format(ctx)
                    : 'Seleccionar hora'),
                onTap: () async {
                  final t = await showTimePicker(
                      context: ctx,
                      initialTime: const TimeOfDay(hour: 10, minute: 0));
                  if (t != null) setDialogState(() => selectedTime = t);
                },
              ),
              TextField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(hintText: 'Nota (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
          ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: (selectedDate == null || selectedTime == null)
                  ? null
                  : () async {
                      try {
                        final proposedAt = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime!.hour,
                          selectedTime!.minute,
                        );
                        final note = noteCtrl.text.trim();
                        await rpCreateMeeting(
                          salonId: salonId,
                          proposedAt: proposedAt,
                          note: note.isEmpty ? null : note,
                        );
                        ref.invalidate(rpNextMeetingProvider(salonId));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ToastService.showSuccess('Reunión solicitada');
                        }

                        // Send WA to salon
                        final salonName =
                            salon['business_name'] ?? '';
                        final fecha =
                            DateFormat('dd MMM yyyy').format(proposedAt);
                        final hora =
                            DateFormat('HH:mm').format(proposedAt);
                        final msg =
                            'Hola $salonName, somos BeautyCita. Nos gustaría visitarte el $fecha a las $hora${note.isNotEmpty ? ' para $note' : ''}. ¿Te funciona? Puedes responder con: Sí / No / Proponer otro horario';
                        await rpSendMessage(
                            salonId: salonId,
                            channel: 'whatsapp',
                            message: msg);
                      } catch (e) {
                        if (mounted) {
                          ToastService.showError('Error al crear reunión: $e');
                        }
                      }
                    },
              child: const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cerrar Dialog ──

  void _showCerrarDialog() {
    String? outcome;
    String? selectedReason;
    final reasonCtrl = TextEditingController();
    const reasons = [
      'No interesado',
      'Ya tiene sistema',
      'Cerró el negocio',
      'No contactable',
      'Otro'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Cerrar Proceso',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿El salón se registró en BeautyCita?',
                  style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Sí, completado'),
                      selected: outcome == 'completed',
                      onSelected: (_) => setDialogState(() {
                        outcome = 'completed';
                        selectedReason = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('No'),
                      selected: outcome == 'not_converted',
                      onSelected: (_) =>
                          setDialogState(() => outcome = 'not_converted'),
                    ),
                  ),
                ],
              ),
              if (outcome == 'not_converted') ...[
                const SizedBox(height: 16),
                Text('Razón:',
                    style: GoogleFonts.poppins(fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons
                      .map((r) => ChoiceChip(
                            label: Text(r,
                                style:
                                    GoogleFonts.poppins(fontSize: 12)),
                            selected: selectedReason == r,
                            onSelected: (_) =>
                                setDialogState(() => selectedReason = r),
                          ))
                      .toList(),
                ),
                if (selectedReason == 'Otro') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Especificar razón'),
                  ),
                ],
              ],
            ],
          ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: outcome == null ||
                      (outcome == 'not_converted' &&
                          selectedReason == null)
                  ? null
                  : () async {
                      try {
                        final assignmentId =
                            await getActiveAssignmentId(salonId);
                        if (assignmentId == null) {
                          if (mounted) {
                            ToastService.showError(
                                'No se encontró asignación activa');
                          }
                          return;
                        }
                        final finalReason = selectedReason == 'Otro'
                            ? reasonCtrl.text.trim()
                            : selectedReason;
                        await rpCloseProcess(
                          salonId: salonId,
                          assignmentId: assignmentId,
                          outcome: outcome!,
                          reason: outcome == 'not_converted'
                              ? finalReason
                              : null,
                        );
                        ref.invalidate(rpAssignedSalonsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ToastService.showSuccess(
                              outcome == 'completed'
                                  ? 'Proceso cerrado: Convertido'
                                  : 'Proceso cerrado');
                          context.pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          ToastService.showError('Error al cerrar proceso: $e');
                        }
                      }
                    },
              child: const Text('Cerrar Proceso'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  String _timeAgo(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return DateFormat('dd MMM').format(dt);
  }
}

// ── Checklist Bottom Sheet ──

class _ChecklistSheet extends ConsumerStatefulWidget {
  final String salonId;
  const _ChecklistSheet({required this.salonId});

  @override
  ConsumerState<_ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends ConsumerState<_ChecklistSheet> {
  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(rpChecklistProvider(widget.salonId));
    final checkedKeys = checklist.whenOrNull(
          data: (items) => {
            for (final i in items)
              if (i['checked_at'] != null) i['item_key'] as String
          },
        ) ??
        <String>{};

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: scrollController,
          children: [
            Text('Checklist de Onboarding',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text('Requeridos',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ...kRpChecklistRequired
                .map((key) => _checkItem(key, checkedKeys.contains(key))),
            const SizedBox(height: 16),
            Text('Opcionales',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ...kRpChecklistOptional
                .map((key) => _checkItem(key, checkedKeys.contains(key))),
          ],
        ),
      ),
    );
  }

  Widget _checkItem(String key, bool checked) {
    return CheckboxListTile(
      value: checked,
      title: Text(kRpChecklistLabels[key] ?? key,
          style: GoogleFonts.poppins(fontSize: 14)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      onChanged: (val) async {
        try {
          await rpToggleChecklistItem(
              salonId: widget.salonId, itemKey: key, checked: val ?? false);
          ref.invalidate(rpChecklistProvider(widget.salonId));
        } catch (e) {
          if (!context.mounted) return;
          ToastService.showError('Error: $e');
        }
      },
    );
  }
}
