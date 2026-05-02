// Web Outreach → Envío de templates
//
// Mirror of mobile's three-step bulk-send: Audiencia / Canal / Template +
// recipient list + preview + send + recent jobs. Wired to outreach-bulk-send
// edge fn (same pipes as mobile — no parallel infrastructure).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

import '../../providers/admin_outreach_send_provider.dart';
import '../../widgets/web_design_system.dart';

class OutreachSendPanel extends ConsumerStatefulWidget {
  const OutreachSendPanel({super.key});

  @override
  ConsumerState<OutreachSendPanel> createState() => _State();
}

class _State extends ConsumerState<OutreachSendPanel> {
  OutreachAudience _audience = OutreachAudience.discovered;
  OutreachChannel _channel = OutreachChannel.wa;
  OutreachTemplate? _template;
  final Set<String> _selected = <String>{};
  String _query = '';
  String? _previewBody;
  String? _previewSubject;
  bool _previewBusy = false;
  String? _previewError;
  String? _runningJobId;
  Timer? _jobTimer;
  Map<String, dynamic>? _runningJob;

  @override
  void dispose() {
    _jobTimer?.cancel();
    super.dispose();
  }

  void _resetPreview() {
    setState(() {
      _previewBody = null;
      _previewSubject = null;
      _previewError = null;
    });
  }

  Future<OutreachTemplate?> _pickTemplate(List<OutreachTemplate> templates) {
    return showDialog<OutreachTemplate>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Templates para ${_audience.label} · ${_channel.label}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${templates.length} template${templates.length == 1 ? '' : 's'} activo${templates.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: templates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final t = templates[i];
                      final isSelected = _template?.id == t.id;
                      final preview = t.bodyTemplate.replaceAll(RegExp(r'\s+'), ' ').trim();
                      return InkWell(
                        onTap: () => Navigator.of(ctx).pop(t),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (t.isInvite)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Invitación',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(ctx).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (t.category.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(t.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                preview,
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _renderPreview(OutreachRecipient firstSelected) async {
    if (_template == null) return;
    setState(() {
      _previewBusy = true;
      _previewError = null;
    });
    try {
      final res = await BCSupabase.client.functions.invoke(
        'outreach-bulk-send',
        body: {
          'action': 'preview',
          'template_id': _template!.id,
          'recipient_table': _audience.table,
          'recipient_id': firstSelected.id,
          'channel': _channel.apiValue,
          'manual_vars': const <String, String>{},
        },
      );
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>?;
      if (res.status != 200 || data == null) {
        setState(() {
          _previewError = (data?['error'] as String?) ?? 'Error de preview (${res.status})';
          _previewBody = null;
          _previewSubject = null;
          _previewBusy = false;
        });
        return;
      }
      setState(() {
        _previewBody = (data['body'] as String?) ?? (data['message'] as String?) ?? '';
        _previewSubject = data['subject'] as String?;
        _previewBusy = false;
        _previewError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewError = '$e';
        _previewBusy = false;
      });
    }
  }

  Future<void> _send(List<OutreachRecipient> selected) async {
    if (_template == null || selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar mensajes'),
        content: Text(
          'Se enviarán ${selected.length} mensajes (${_channel.label}) a ${_audience.label.toLowerCase()} usando el template "${_template!.name}". El sistema respeta opt-outs y cooldowns automáticamente. ¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final res = await BCSupabase.client.functions.invoke(
        'outreach-bulk-send',
        body: {
          'action': 'enqueue',
          'channel': _channel.apiValue,
          'template_id': _template!.id,
          'recipient_table': _audience.table,
          'recipient_ids': selected.map((r) => r.id).toList(),
          'manual_vars': const <String, String>{},
        },
      );
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>?;
      if (res.status != 200 || data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((data?['error'] as String?) ?? 'Error al encolar (${res.status})')),
        );
        return;
      }
      final jobId = data['job_id'] as String?;
      if (jobId == null) return;
      setState(() {
        _runningJobId = jobId;
        _selected.clear();
      });
      _startJobPolling(jobId);
      ref.invalidate(outreachRecentJobsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Encolado · $jobId')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _startJobPolling(String jobId) {
    _jobTimer?.cancel();
    _pollJob(jobId);
    _jobTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollJob(jobId));
  }

  Future<void> _pollJob(String jobId) async {
    try {
      final res = await BCSupabase.client.functions.invoke(
        'outreach-bulk-send',
        body: {'action': 'get_job', 'job_id': jobId},
      );
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>?;
      if (res.status == 200 && data != null) {
        setState(() => _runningJob = data['job'] as Map<String, dynamic>? ?? data);
        final status = _runningJob?['status'] as String?;
        if (status == 'completed' || status == 'cancelled') {
          _jobTimer?.cancel();
        }
      }
    } catch (_) {/* keep polling */}
  }

  @override
  Widget build(BuildContext context) {
    final filter = OutreachTemplateFilter(audience: _audience, channel: _channel);
    final templatesAsync = ref.watch(outreachSendTemplatesProvider(filter));
    final recipientsAsync = ref.watch(outreachSendRecipientsProvider(_audience));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Step 1-3 setup card ───────────────────────────────────────
            WebCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Envío de templates',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tres pasos: audiencia → canal → template. El servidor aplica opt-outs, cooldowns y rate-limits automáticamente.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  _stepLabel('1. Audiencia'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final a in OutreachAudience.values) ...[
                        Expanded(
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(a.label, textAlign: TextAlign.center),
                            ),
                            selected: _audience == a,
                            onSelected: (_) => setState(() {
                              _audience = a;
                              _template = null;
                              _selected.clear();
                              _resetPreview();
                            }),
                          ),
                        ),
                        if (a != OutreachAudience.values.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  _stepLabel('2. Canal'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final ch in OutreachChannel.values) ...[
                        Expanded(
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ch == OutreachChannel.wa ? Icons.chat_outlined : Icons.email_outlined,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(ch.label),
                              ],
                            ),
                            selected: _channel == ch,
                            onSelected: (_) => setState(() {
                              _channel = ch;
                              _template = null;
                              _resetPreview();
                            }),
                          ),
                        ),
                        if (ch != OutreachChannel.values.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  _stepLabel('3. Template para ${_audience.label} · ${_channel.label}'),
                  const SizedBox(height: 8),
                  templatesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => _errorBox('$e'),
                    data: (templates) {
                      return InkWell(
                        onTap: templates.isEmpty
                            ? null
                            : () async {
                                final picked = await _pickTemplate(templates);
                                if (picked != null) {
                                  setState(() {
                                    _template = picked;
                                    _resetPreview();
                                  });
                                }
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _template != null
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _template != null ? Icons.check_circle_outline : Icons.unfold_more_rounded,
                                size: 20,
                                color: _template != null
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _template?.name ??
                                          (templates.isEmpty
                                              ? 'Sin templates activos para esta combinación'
                                              : 'Toca para elegir un template (${templates.length} disponible${templates.length == 1 ? '' : 's'})'),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_template != null && _template!.category.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _template!.category,
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (templates.isNotEmpty)
                                Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade600),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_runningJobId != null) _jobProgressCard(),

            // ── Recipients ───────────────────────────────────────────────
            WebCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Destinatarios  ·  ${_selected.length} seleccionados',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Filtrar por nombre / ciudad',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  recipientsAsync.when(
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                    error: (e, _) => _errorBox('$e'),
                    data: (all) {
                      final filtered = all.where((r) {
                        if (_channel == OutreachChannel.wa && (r.phone?.isEmpty ?? true)) return false;
                        if (_channel == OutreachChannel.email && (r.email?.isEmpty ?? true)) return false;
                        if (_query.isEmpty) return true;
                        return '${r.name} ${r.subtitle}'.toLowerCase().contains(_query);
                      }).toList();
                      if (filtered.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Sin destinatarios', style: TextStyle(color: Colors.grey.shade600)),
                        );
                      }
                      final allSelectedNow = filtered.every((r) => _selected.contains(r.id));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${filtered.length} disponibles',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => setState(() {
                                  if (allSelectedNow) {
                                    _selected.removeAll(filtered.map((r) => r.id));
                                  } else {
                                    _selected.addAll(filtered.map((r) => r.id));
                                  }
                                }),
                                child: Text(allSelectedNow ? 'Deseleccionar todos' : 'Seleccionar todos'),
                              ),
                            ],
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 420),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final r = filtered[i];
                                final selected = _selected.contains(r.id);
                                return CheckboxListTile(
                                  value: selected,
                                  dense: true,
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(r.id);
                                    } else {
                                      _selected.remove(r.id);
                                    }
                                  }),
                                  title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    [r.subtitle, _channel == OutreachChannel.wa ? (r.phone ?? '') : (r.email ?? '')]
                                        .where((s) => s.isNotEmpty)
                                        .join(' · '),
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Preview ──────────────────────────────────────────────────
            WebCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vista previa',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (_previewError != null)
                    Text(_previewError!, style: const TextStyle(color: Colors.red))
                  else if (_previewBody == null)
                    Text(
                      _template == null
                          ? 'Selecciona un template para previsualizar el mensaje.'
                          : _selected.isEmpty
                              ? 'Selecciona al menos un destinatario y luego "Renderizar previa".'
                              : 'Toca "Renderizar previa" para ver el primer mensaje exacto que se enviará.',
                      style: TextStyle(color: Colors.grey.shade700),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_previewSubject != null) ...[
                          Text('Asunto', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          Text(_previewSubject!, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                        ],
                        Text('Mensaje', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_previewBody!),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: _previewBusy
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.visibility_outlined, size: 16),
                      label: Text(_previewBody == null ? 'Renderizar previa' : 'Volver a renderizar'),
                      onPressed: (_template == null || _selected.isEmpty || _previewBusy)
                          ? null
                          : () async {
                              final firstId = _selected.first;
                              final list = ref.read(outreachSendRecipientsProvider(_audience)).valueOrNull ?? [];
                              final r = list.firstWhere((x) => x.id == firstId, orElse: () => list.first);
                              await _renderPreview(r);
                            },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Send button ──────────────────────────────────────────────
            FilledButton.icon(
              onPressed: (_template == null || _selected.isEmpty)
                  ? null
                  : () async {
                      final list = ref.read(outreachSendRecipientsProvider(_audience)).valueOrNull ?? [];
                      final selected = list.where((r) => _selected.contains(r.id)).toList();
                      await _send(selected);
                    },
              icon: const Icon(Icons.send),
              label: Text(
                _selected.isEmpty
                    ? 'Selecciona destinatarios'
                    : 'Enviar a ${_selected.length} destinatario${_selected.length == 1 ? '' : 's'}',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              ),
            ),
            const SizedBox(height: 24),

            // ── Recent jobs ──────────────────────────────────────────────
            _RecentJobs(),
          ],
        ),
      ),
    );
  }

  Widget _stepLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      );

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(msg, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
      );

  Widget _jobProgressCard() {
    final j = _runningJob;
    if (j == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    final total = (j['total_count'] as int?) ?? 0;
    final sent = (j['sent_count'] as int?) ?? 0;
    final skipped = (j['skipped_count'] as int?) ?? 0;
    final failed = (j['failed_count'] as int?) ?? 0;
    final status = (j['status'] as String?) ?? '?';
    final progress = total > 0 ? ((sent + skipped + failed) / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: WebCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Trabajo · $status',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _runningJobId = null;
                    _runningJob = null;
                    _jobTimer?.cancel();
                  }),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _kpi('Total', '$total'),
                _kpi('Encolados', '$sent'),
                _kpi('Saltados', '$skipped'),
                _kpi('Fallidos', '$failed', alert: failed > 0),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'WA: la barra refleja "encolados al throttle global"; la entrega real ocurre a 1 mensaje cada 20s.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value, {bool alert = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: alert ? Colors.red.shade700 : Colors.black87,
            ),
          ),
        ],
      );
}

class _RecentJobs extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncJobs = ref.watch(outreachRecentJobsProvider);
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Trabajos recientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(outreachRecentJobsProvider),
                child: const Text('Refrescar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          asyncJobs.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            data: (jobs) {
              if (jobs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Sin trabajos recientes', style: TextStyle(color: Colors.grey.shade600)),
                );
              }
              return Column(
                children: [for (final j in jobs) _jobRow(context, j)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _jobRow(BuildContext ctx, Map<String, dynamic> job) {
    final ch = (job['channel'] as String?) ?? '?';
    final tbl = (job['recipient_table'] as String?) ?? '?';
    final status = (job['status'] as String?) ?? '?';
    final sent = (job['sent_count'] as int?) ?? 0;
    final total = (job['total_count'] as int?) ?? 0;
    final failed = (job['failed_count'] as int?) ?? 0;
    final created = (job['created_at'] as String?) ?? '';
    final color = switch (status) {
      'completed' => Colors.green,
      'cancelled' => Colors.grey,
      'failed' => Colors.red,
      _ => Theme.of(ctx).colorScheme.primary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text('$ch · $tbl', style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(
            '$sent / $total${failed > 0 ? ' · $failed fallidos' : ''}',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(_short(created), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  String _short(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final ago = DateTime.now().difference(dt);
      if (ago.inMinutes < 60) return 'hace ${ago.inMinutes}m';
      if (ago.inHours < 24) return 'hace ${ago.inHours}h';
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
