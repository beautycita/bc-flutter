import 'dart:async';
import 'package:flutter/material.dart';

import '../../services/outreach_service.dart';
import '../../services/toast_service.dart';

/// Persistent banner that surfaces active outreach bulk jobs across the admin
/// shell. Polls every 5s while at least one job is active. Hides itself when
/// no jobs are running. Tap → expand to see per-job progress + cancel.
class OutreachJobsBanner extends StatefulWidget {
  const OutreachJobsBanner({super.key});

  @override
  State<OutreachJobsBanner> createState() => _OutreachJobsBannerState();
}

class _OutreachJobsBannerState extends State<OutreachJobsBanner> {
  Timer? _poller;
  List<BulkJobStatus> _jobs = [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final jobs = await OutreachService.listActiveJobs();
      if (!mounted) return;
      setState(() => _jobs = jobs);
    } catch (_) {
      // Silent — banner is non-critical, don't disturb user with toasts on
      // poll errors.
    }
  }

  Future<void> _cancel(BulkJobStatus job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar el envío?'),
        content: Text(
          'Se cancelarán los ${job.totalCount - job.processed} mensajes restantes. '
          'Los ${job.sentCount} ya enviados no se pueden recuperar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar enviando'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancelar envío'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await OutreachService.cancelJob(job.id);
      ToastService.showSuccess('Envío cancelado');
      await _refresh();
    } catch (e) {
      ToastService.showError('No se pudo cancelar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jobs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final totalActive = _jobs.length;
    final totalSent = _jobs.fold<int>(0, (a, j) => a + j.sentCount);
    final totalQueued = _jobs.fold<int>(0, (a, j) => a + j.totalCount);

    return Material(
      elevation: 6,
      color: theme.colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact summary row — always visible
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          totalActive == 1
                              ? 'Enviando: $totalSent de $totalQueued'
                              : '$totalActive envíos activos · $totalSent de $totalQueued',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_more : Icons.expand_less,
                        size: 20,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
              // Expanded per-job details
              if (_expanded)
                Container(
                  color: theme.colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                  child: Column(
                    children: _jobs.map((j) => _JobRow(job: j, onCancel: () => _cancel(j))).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  final BulkJobStatus job;
  final VoidCallback onCancel;
  const _JobRow({required this.job, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final channelLabel = job.channel == 'wa' ? 'WhatsApp' : 'Email';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                job.channel == 'wa' ? Icons.chat : Icons.mail_outline,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$channelLabel · ${job.templateName ?? "—"}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${job.processed}/${job.totalCount}',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              IconButton(
                tooltip: 'Cancelar este envío',
                icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                visualDensity: VisualDensity.compact,
                onPressed: onCancel,
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: job.progress,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          if (job.skippedCount > 0 || job.failedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (job.skippedCount > 0) '${job.skippedCount} omitidos',
                  if (job.failedCount > 0) '${job.failedCount} fallidos',
                ].join(' · '),
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange[800]),
              ),
            ),
        ],
      ),
    );
  }
}
