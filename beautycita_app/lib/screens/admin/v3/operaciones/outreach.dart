// Operaciones → Outreach
//
// Bulk + singular WA / Email send to discovered_salons or registered
// businesses. Wires the outreach-bulk-send edge fn — preview, enqueue,
// poll for progress. Pre-flight pre-checks (opt-out, cooldown) come from
// the edge fn's preview action; the UI never tries to enforce them
// independently.
//
// Reliability bar:
//   - Send button is disabled when no recipients are selected or no
//     template is picked.
//   - Preview must render successfully before send is allowed.
//   - On send, the screen switches to a job-progress card that polls
//     get_job every 5s until completed or cancelled.
//   - Recent jobs section shows the last 20 sends with their counts so
//     the operator can verify "messages went out" at a glance.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/admin_outreach_provider.dart';
import '../../../../services/supabase_client.dart';
import '../../../../services/toast_service.dart';
import '../../../../widgets/admin/v2/action/action_button.dart';
import '../../../../widgets/admin/v2/data_viz/kpi_tile.dart';
import '../../../../widgets/admin/v2/feedback/audit_indicator.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';

class OperacionesOutreach extends ConsumerStatefulWidget {
  const OperacionesOutreach({super.key});

  @override
  ConsumerState<OperacionesOutreach> createState() => _State();
}

class _State extends ConsumerState<OperacionesOutreach> {
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

  void _resetPreview() {
    setState(() {
      _previewBody = null;
      _previewSubject = null;
      _previewError = null;
    });
  }

  Future<void> _renderPreview(OutreachRecipient firstSelected) async {
    if (_template == null) return;
    setState(() {
      _previewBusy = true;
      _previewError = null;
    });
    try {
      final res = await SupabaseClientService.client.functions.invoke(
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
        _previewBody = data['body'] as String? ?? data['message'] as String? ?? '';
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
      final res = await SupabaseClientService.client.functions.invoke(
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
        ToastService.showError((data?['error'] as String?) ?? 'Error al encolar (${res.status})');
        return;
      }
      final jobId = data['job_id'] as String?;
      if (jobId == null) {
        ToastService.showError('Servidor no devolvió job_id');
        return;
      }
      setState(() {
        _runningJobId = jobId;
        _selected.clear();
      });
      AdminAuditIndicator.show(context, label: 'Encolado · $jobId');
      ref.invalidate(adminRecentJobsProvider);
    } catch (e, st) {
      if (!mounted) return;
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = OutreachTemplateFilter(audience: _audience, channel: _channel);
    final templatesAsync = ref.watch(outreachTemplatesProvider(filter));
    final recipientsAsync = ref.watch(outreachRecipientsProvider(_audience));

    return ListView(
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      children: [
        AdminCard(
          title: 'Envío de templates',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona audiencia, canal y template. Multi-selecciona destinatarios para envío masivo o uno solo para envío individual. El servidor aplica opt-outs, cooldowns de invitaciones y rate-limits automáticamente.',
                style: AdminV2Tokens.muted(context),
              ),
              const SizedBox(height: AdminV2Tokens.spacingMD),
              Wrap(
                spacing: AdminV2Tokens.spacingSM,
                runSpacing: AdminV2Tokens.spacingSM,
                children: [
                  for (final a in OutreachAudience.values)
                    ChoiceChip(
                      label: Text(a.label),
                      selected: _audience == a,
                      onSelected: (_) => setState(() {
                        _audience = a;
                        _template = null;
                        _selected.clear();
                        _resetPreview();
                      }),
                    ),
                  const SizedBox(width: AdminV2Tokens.spacingMD),
                  for (final ch in OutreachChannel.values)
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(ch == OutreachChannel.wa ? Icons.chat_outlined : Icons.email_outlined, size: 14),
                          const SizedBox(width: 4),
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
                ],
              ),
              const SizedBox(height: AdminV2Tokens.spacingMD),
              templatesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => AdminEmptyState(kind: AdminEmptyKind.error, body: '$e'),
                data: (templates) {
                  if (templates.isEmpty) {
                    return const AdminEmptyState(
                      kind: AdminEmptyKind.empty,
                      title: 'Sin templates',
                      body: 'No hay templates activos para esta combinación.',
                    );
                  }
                  return DropdownButtonFormField<String>(
                    value: _template?.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Template',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM)),
                    ),
                    items: [
                      for (final t in templates)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) {
                      final t = templates.firstWhere((x) => x.id == id);
                      setState(() {
                        _template = t;
                        _resetPreview();
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),
        if (_runningJobId != null)
          _JobProgressCard(
            jobId: _runningJobId!,
            onClose: () => setState(() => _runningJobId = null),
          ),
        AdminCard(
          title: 'Destinatarios  ·  ${_selected.length} seleccionados',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Filtrar por nombre / ciudad',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM)),
                ),
              ),
              const SizedBox(height: AdminV2Tokens.spacingSM),
              recipientsAsync.when(
                loading: () => const SizedBox(height: 80, child: AdminEmptyState(kind: AdminEmptyKind.loading)),
                error: (e, _) => AdminEmptyState(kind: AdminEmptyKind.error, body: '$e'),
                data: (recipients) {
                  final filtered = recipients.where((r) {
                    if (_channel == OutreachChannel.wa && (r.phone?.isEmpty ?? true)) return false;
                    if (_channel == OutreachChannel.email && (r.email?.isEmpty ?? true)) return false;
                    if (_query.isEmpty) return true;
                    final hay = '${r.name} ${r.subtitle}'.toLowerCase();
                    return hay.contains(_query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin destinatarios');
                  }

                  final allSelectedNow = filtered.every((r) => _selected.contains(r.id));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AdminV2Tokens.spacingXS),
                        child: Row(
                          children: [
                            Text('${filtered.length} disponibles', style: AdminV2Tokens.muted(context)),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  if (allSelectedNow) {
                                    _selected.removeAll(filtered.map((r) => r.id));
                                  } else {
                                    _selected.addAll(filtered.map((r) => r.id));
                                  }
                                });
                              },
                              child: Text(allSelectedNow ? 'Deseleccionar todos' : 'Seleccionar todos'),
                            ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final r = filtered[i];
                            final selected = _selected.contains(r.id);
                            return CheckboxListTile(
                              value: selected,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selected.add(r.id);
                                } else {
                                  _selected.remove(r.id);
                                }
                              }),
                              dense: true,
                              title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                [r.subtitle, _channel == OutreachChannel.wa ? (r.phone ?? '') : (r.email ?? '')].where((s) => s.isNotEmpty).join(' · '),
                                style: AdminV2Tokens.muted(context),
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
        AdminCard(
          title: 'Vista previa',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_previewError != null)
                Text(_previewError!, style: AdminV2Tokens.body(context).copyWith(color: AdminV2Tokens.destructive(context)))
              else if (_previewBody == null)
                Text(
                  _template == null
                      ? 'Selecciona un template para previsualizar el mensaje.'
                      : _selected.isEmpty
                          ? 'Selecciona al menos un destinatario y luego toca "Renderizar previa".'
                          : 'Toca "Renderizar previa" para ver el primer mensaje exacto que se enviará.',
                  style: AdminV2Tokens.muted(context),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_previewSubject != null) ...[
                      Text('Asunto', style: AdminV2Tokens.muted(context)),
                      const SizedBox(height: 2),
                      Text(_previewSubject!, style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AdminV2Tokens.spacingMD),
                    ],
                    Text('Mensaje', style: AdminV2Tokens.muted(context)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM),
                      ),
                      child: Text(_previewBody!, style: AdminV2Tokens.body(context)),
                    ),
                  ],
                ),
              const SizedBox(height: AdminV2Tokens.spacingMD),
              AdminActionButton(
                label: _previewBody == null ? 'Renderizar previa' : 'Volver a renderizar',
                icon: Icons.visibility_outlined,
                variant: AdminActionVariant.secondary,
                isLoading: _previewBusy,
                onPressed: (_template == null || _selected.isEmpty || _previewBusy)
                    ? null
                    : () async {
                        final firstId = _selected.first;
                        final list = ref.read(outreachRecipientsProvider(_audience)).valueOrNull ?? [];
                        final r = list.firstWhere((x) => x.id == firstId, orElse: () => list.first);
                        await _renderPreview(r);
                      },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AdminV2Tokens.spacingMD),
          child: AdminActionButton(
            label: _selected.isEmpty
                ? 'Selecciona destinatarios'
                : 'Enviar a ${_selected.length} destinatario${_selected.length == 1 ? '' : 's'}',
            icon: Icons.send,
            onPressed: (_template == null || _selected.isEmpty)
                ? null
                : () async {
                    final list = ref.read(outreachRecipientsProvider(_audience)).valueOrNull ?? [];
                    final selected = list.where((r) => _selected.contains(r.id)).toList();
                    await _send(selected);
                  },
          ),
        ),
        const _RecentJobs(),
      ],
    );
  }
}

class _JobProgressCard extends ConsumerStatefulWidget {
  const _JobProgressCard({required this.jobId, required this.onClose});
  final String jobId;
  final VoidCallback onClose;

  @override
  ConsumerState<_JobProgressCard> createState() => _JobProgressState();
}

class _JobProgressState extends ConsumerState<_JobProgressCard> {
  Timer? _timer;
  Map<String, dynamic>? _job;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final res = await SupabaseClientService.client.functions.invoke(
        'outreach-bulk-send',
        body: {'action': 'get_job', 'job_id': widget.jobId},
      );
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>?;
      if (res.status == 200 && data != null) {
        setState(() {
          _job = data['job'] as Map<String, dynamic>? ?? data;
          _error = null;
        });
        final status = _job?['status'] as String?;
        if (status == 'completed' || status == 'cancelled') {
          _timer?.cancel();
        }
      }
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _job;
    if (_error != null) {
      return AdminCard(
        title: 'Trabajo en curso',
        trailing: TextButton(onPressed: widget.onClose, child: const Text('Cerrar')),
        child: Text(_error!, style: AdminV2Tokens.body(context).copyWith(color: AdminV2Tokens.destructive(context))),
      );
    }
    if (j == null) {
      return const AdminCardSkeleton(heightHint: 120);
    }
    final total = (j['total_count'] as int?) ?? 0;
    final sent = (j['sent_count'] as int?) ?? 0;
    final skipped = (j['skipped_count'] as int?) ?? 0;
    final failed = (j['failed_count'] as int?) ?? 0;
    final status = (j['status'] as String?) ?? '?';
    final progress = total > 0 ? ((sent + skipped + failed) / total).clamp(0.0, 1.0) : 0.0;
    return AdminCard(
      title: 'Trabajo · $status',
      trailing: TextButton(onPressed: widget.onClose, child: const Text('Cerrar')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM),
            child: LinearProgressIndicator(value: progress, minHeight: 8),
          ),
          const SizedBox(height: AdminV2Tokens.spacingMD),
          Wrap(
            spacing: AdminV2Tokens.spacingLG,
            runSpacing: AdminV2Tokens.spacingMD,
            children: [
              AdminKpiTile(label: 'Total', value: '$total'),
              AdminKpiTile(label: 'Encolados', value: '$sent'),
              AdminKpiTile(label: 'Saltados', value: '$skipped'),
              AdminKpiTile(label: 'Fallidos', value: '$failed', deltaPositive: failed == 0 ? null : false),
            ],
          ),
          const SizedBox(height: AdminV2Tokens.spacingSM),
          Text(
            'WA: la barra refleja "encolados al throttle global"; la entrega real ocurre a 1 mensaje cada 20 s. Usa la pestaña Auditoría / log para confirmar entrega.',
            style: AdminV2Tokens.muted(context),
          ),
        ],
      ),
    );
  }
}

class _RecentJobs extends ConsumerWidget {
  const _RecentJobs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncJobs = ref.watch(adminRecentJobsProvider);
    return AdminCard(
      title: 'Trabajos recientes',
      trailing: TextButton(
        onPressed: () => ref.invalidate(adminRecentJobsProvider),
        child: const Text('Refrescar'),
      ),
      child: asyncJobs.when(
        loading: () => const SizedBox(height: 60, child: AdminEmptyState(kind: AdminEmptyKind.loading)),
        error: (e, _) => AdminEmptyState(kind: AdminEmptyKind.error, body: '$e'),
        data: (jobs) {
          if (jobs.isEmpty) {
            return const AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin trabajos recientes');
          }
          return Column(
            children: [
              for (final j in jobs) _JobRow(job: j),
            ],
          );
        },
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job});
  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final ch = (job['channel'] as String?) ?? '?';
    final tbl = (job['recipient_table'] as String?) ?? '?';
    final status = (job['status'] as String?) ?? '?';
    final sent = (job['sent_count'] as int?) ?? 0;
    final total = (job['total_count'] as int?) ?? 0;
    final failed = (job['failed_count'] as int?) ?? 0;
    final created = (job['created_at'] as String?) ?? '';
    final color = switch (status) {
      'completed' => AdminV2Tokens.success(context),
      'cancelled' => AdminV2Tokens.subtle(context),
      'failed' => AdminV2Tokens.destructive(context),
      _ => Theme.of(context).colorScheme.primary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AdminV2Tokens.spacingXS),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: AdminV2Tokens.spacingSM),
          Expanded(
            child: Text('$ch · $tbl', style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(
            '$sent / $total${failed > 0 ? ' · $failed fallidos' : ''}',
            style: AdminV2Tokens.muted(context),
          ),
          const SizedBox(width: AdminV2Tokens.spacingSM),
          Text(_short(created), style: AdminV2Tokens.muted(context)),
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
