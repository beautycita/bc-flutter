// Operaciones → Salud
//
// Real-time view of system_health_probes. Shows last probe's metrics +
// 60-min trend strip per metric. No external Grafana / no broken links —
// every signal lives in our own DB.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/admin_v3_queue_provider.dart';
import '../../../../widgets/admin/v2/data_viz/kpi_tile.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';

class OperacionesSalud extends ConsumerWidget {
  const OperacionesSalud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRows = ref.watch(adminHealthProbesProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminHealthProbesProvider),
      child: asyncRows.when(
        loading: () => const AdminEmptyState(kind: AdminEmptyKind.loading),
        error: (e, _) => Center(child: AdminEmptyState(kind: AdminEmptyKind.error, body: '$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin lecturas'));
          }
          final latest = rows.first;
          final dbLatency = (latest['db_latency_ms'] as num?)?.toDouble();
          final fiveXX = (latest['edge_fn_5xx_last_5min'] as num?)?.toInt();
          final activeConn = (latest['active_connections'] as num?)?.toInt();
          final cronFailing = (latest['cron_jobs_failing'] as num?)?.toInt();
          final backupAge = (latest['backup_age_hours'] as num?)?.toDouble();
          final stripeChg = (latest['stripe_charges_24h_success_pct'] as num?)?.toDouble();
          final stripePay = (latest['stripe_payouts_24h_success_pct'] as num?)?.toDouble();
          final waUp = latest['wa_service_up'] == true;

          return ListView(
            padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
            children: [
              AdminCard(
                title: 'Última lectura',
                trailing: Text(
                  _fmtAge(latest['probed_at'] as String?),
                  style: AdminV2Tokens.muted(context),
                ),
                child: Wrap(
                  spacing: AdminV2Tokens.spacingLG,
                  runSpacing: AdminV2Tokens.spacingMD,
                  children: [
                    AdminKpiTile(label: 'DB latencia', value: dbLatency?.toStringAsFixed(2) ?? '—', unit: 'ms'),
                    AdminKpiTile(label: 'Edge 5xx (5m)', value: '${fiveXX ?? 0}'),
                    AdminKpiTile(label: 'Conexiones', value: '${activeConn ?? 0}'),
                    AdminKpiTile(label: 'Cron caídos', value: '${cronFailing ?? 0}'),
                  ],
                ),
              ),
              AdminCard(
                title: 'Servicios externos',
                child: Column(
                  children: [
                    _ServiceLine(
                      label: 'Stripe charges 24h',
                      valuePct: stripeChg,
                      noDataHint: 'Sin actividad de pagos en 24h',
                    ),
                    _ServiceLine(
                      label: 'Stripe payouts 24h',
                      valuePct: stripePay,
                      noDataHint: 'Sin payouts hasta que cuentas bancarias estén activas',
                    ),
                    _ServiceLine(
                      label: 'WhatsApp gateway',
                      valuePct: null,
                      explicitOk: waUp,
                      noDataHint: 'Sin probe — wa_service_up no se está escribiendo',
                    ),
                    _ServiceLine(
                      label: 'Backup edad',
                      valueText: backupAge != null ? '${backupAge.toStringAsFixed(1)}h' : null,
                      okIfText: backupAge != null && backupAge < 24,
                      noDataHint: 'Sin probe — backup_age_hours no se está escribiendo',
                    ),
                  ],
                ),
              ),
              AdminCard(
                title: 'Latencia DB — últimos 60',
                child: SizedBox(
                  height: 64,
                  child: _LatencySparkline(rows: rows),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmtAge(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final ago = DateTime.now().difference(dt);
      if (ago.inSeconds < 60) return 'hace ${ago.inSeconds}s';
      if (ago.inMinutes < 60) return 'hace ${ago.inMinutes}m';
      return 'hace ${ago.inHours}h';
    } catch (_) {
      return '';
    }
  }
}

class _ServiceLine extends StatelessWidget {
  const _ServiceLine({
    required this.label,
    this.valuePct,
    this.valueText,
    this.explicitOk,
    this.okIfText,
    this.noDataHint,
  });
  final String label;
  final double? valuePct;
  final String? valueText;
  final bool? explicitOk;
  final bool? okIfText;

  /// Shown beneath the row label when no probe value exists (e.g. nobody
  /// has run a charge in the last 24h, or the probe writer doesn't fill
  /// this column yet). Distinguishes "no data" from "service down".
  final String? noDataHint;

  @override
  Widget build(BuildContext context) {
    final hasValue = valuePct != null || valueText != null || explicitOk != null;
    final ok = explicitOk ?? (valuePct != null ? valuePct! >= 95.0 : (okIfText ?? false));
    final color = !hasValue
        ? AdminV2Tokens.subtle(context)
        : (ok ? AdminV2Tokens.success(context) : AdminV2Tokens.warning(context));
    final value = !hasValue
        ? 'Sin datos'
        : valuePct != null
            ? '${valuePct!.toStringAsFixed(1)}%'
            : (valueText ?? (explicitOk == true ? 'OK' : 'Caído'));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AdminV2Tokens.spacingSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: AdminV2Tokens.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AdminV2Tokens.body(context)),
                if (!hasValue && noDataHint != null) ...[
                  const SizedBox(height: 2),
                  Text(noDataHint!, style: AdminV2Tokens.muted(context).copyWith(fontSize: 11)),
                ],
              ],
            ),
          ),
          Text(value, style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _LatencySparkline extends StatelessWidget {
  const _LatencySparkline({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.fromHeight(64),
      painter: _SparkPainter(
        values: rows.reversed.map((r) => (r['db_latency_ms'] as num?)?.toDouble() ?? 0).toList(),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).clamp(0.001, double.infinity);
    final stepX = size.width / (values.length - 1).clamp(1, double.infinity);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final yNorm = (values[i] - minV) / range;
      final y = size.height - (yNorm * size.height * 0.85) - size.height * 0.075;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.color != color;
}
