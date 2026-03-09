import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class AdminTaxReportsScreen extends ConsumerStatefulWidget {
  const AdminTaxReportsScreen({super.key});

  @override
  ConsumerState<AdminTaxReportsScreen> createState() =>
      _AdminTaxReportsScreenState();
}

class _AdminTaxReportsScreenState
    extends ConsumerState<AdminTaxReportsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  Map<String, dynamic>? _report;
  bool _loading = false;
  bool _generating = false;

  // Monthly reports list
  List<Map<String, dynamic>> _savedReports = [];

  @override
  void initState() {
    super.initState();
    _loadSavedReports();
  }

  Future<void> _loadSavedReports() async {
    try {
      final data = await SupabaseClientService.client
          .from('sat_monthly_reports')
          .select()
          .order('period_year', ascending: false)
          .order('period_month', ascending: false)
          .limit(24);
      if (mounted) {
        setState(() => _savedReports = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('[TaxReports] Failed to load saved reports: $e');
    }
  }

  Future<void> _generateReport() async {
    setState(() => _generating = true);

    try {
      final res = await SupabaseClientService.client.functions.invoke(
        'sat-reporting',
        body: {
          'year': _selectedYear,
          'month': _selectedMonth,
        },
      );

      final data = res.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(data['error'] as String);
      }

      setState(() => _report = data);
      await _loadSavedReports();
      ToastService.showSuccess('Reporte generado');
    } catch (e) {
      ToastService.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _loadReport(int year, int month) async {
    setState(() {
      _loading = true;
      _selectedYear = year;
      _selectedMonth = month;
    });

    try {
      final data = await SupabaseClientService.client
          .from('sat_monthly_reports')
          .select()
          .eq('period_year', year)
          .eq('period_month', month)
          .single();

      setState(() => _report = data['report_data'] as Map<String, dynamic>?);
    } catch (e) {
      setState(() => _report = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _monthNames = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        // Period selector
        _SectionCard(
          title: 'Periodo',
          icon: Icons.calendar_month,
          colors: colors,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Mes',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: List.generate(12, (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(_monthNames[i + 1]),
                  )),
                  onChanged: (v) => setState(() => _selectedMonth = v ?? 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Ano',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: List.generate(5, (i) {
                    final y = DateTime.now().year - i;
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }),
                  onChanged: (v) => setState(() => _selectedYear = v ?? DateTime.now().year),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _generating ? null : _generateReport,
                icon: _generating
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Generar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Current report summary
        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ))
        else if (_report != null) ...[
          _SectionCard(
            title: 'Resumen: ${_monthNames[_selectedMonth]} $_selectedYear',
            icon: Icons.receipt_long,
            colors: colors,
            child: _buildReportSummary(_report!),
          ),
          const SizedBox(height: 16),

          // Provider breakdown
          if (_report!['providers'] != null)
            _SectionCard(
              title: 'Desglose por Proveedor',
              icon: Icons.store,
              colors: colors,
              child: _buildProviderBreakdown(
                List<Map<String, dynamic>>.from(_report!['providers']),
              ),
            ),
        ] else
          _SectionCard(
            title: 'Sin datos',
            icon: Icons.info_outline,
            colors: colors,
            child: Text(
              'Selecciona un periodo y genera el reporte.',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
          ),

        const SizedBox(height: 24),

        // Saved reports list
        if (_savedReports.isNotEmpty) ...[
          Text(
            'REPORTES GUARDADOS',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          ..._savedReports.map((r) => _buildSavedReportTile(r, colors)),
        ],
      ],
    );
  }

  Widget _buildReportSummary(Map<String, dynamic> report) {
    final totals = report['totals'] as Map<String, dynamic>? ?? {};
    final dueDates = report['due_dates'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricRow('Transacciones', '${totals['transactions'] ?? 0}'),
        _MetricRow('Ingreso bruto', _fmtMXN(totals['gross'])),
        const Divider(),
        _MetricRow('ISR retenido', _fmtMXN(totals['isr_withheld']),
            highlight: true),
        _MetricRow('IVA retenido', _fmtMXN(totals['iva_withheld']),
            highlight: true),
        _MetricRow('Total retenido', _fmtMXN(totals['total_withheld']),
            highlight: true, bold: true),
        const Divider(),
        _MetricRow('Comision plataforma', _fmtMXN(totals['platform_fees'])),
        if (dueDates['informative'] != null)
          _MetricRow('Fecha limite informativa', '${dueDates['informative']}'),
        if (dueDates['remittance'] != null)
          _MetricRow('Fecha limite entero', '${dueDates['remittance']}'),
      ],
    );
  }

  Widget _buildProviderBreakdown(List<Map<String, dynamic>> providers) {
    if (providers.isEmpty) {
      return Text('Sin proveedores en este periodo.',
          style: GoogleFonts.nunito(fontSize: 13));
    }

    return Column(
      children: providers.map((p) {
        final rfc = p['rfc'] as String?;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    rfc != null ? Icons.verified : Icons.warning_amber,
                    size: 16,
                    color: rfc != null ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    p['business_id']?.toString().substring(0, 8) ?? 'N/A',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  if (rfc != null)
                    Text('RFC: $rfc',
                        style: GoogleFonts.nunito(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              _MetricRow('Transacciones', '${p['transactions'] ?? 0}'),
              _MetricRow('Bruto', _fmtMXN(p['gross'])),
              _MetricRow('ISR', _fmtMXN(p['isr_withheld'])),
              _MetricRow('IVA', _fmtMXN(p['iva_withheld'])),
              _MetricRow('Neto proveedor', _fmtMXN(p['provider_net'])),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSavedReportTile(Map<String, dynamic> r, ColorScheme colors) {
    final year = r['period_year'] as int;
    final month = r['period_month'] as int;
    final status = r['status'] as String? ?? 'pending';
    final totalIsr = r['total_isr_withheld'];
    final totalIva = r['total_iva_withheld'];

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(
          status == 'submitted' ? Icons.check_circle : Icons.schedule,
          color: status == 'submitted' ? Colors.green : colors.primary,
        ),
        title: Text(
          '${_monthNames[month]} $year',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'ISR: ${_fmtMXN(totalIsr)} | IVA: ${_fmtMXN(totalIva)} | Estado: $status',
          style: GoogleFonts.nunito(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _loadReport(year, month),
      ),
    );
  }

  String _fmtMXN(dynamic amount) {
    if (amount == null) return '\$0.00';
    final num val = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
    return '\$${val.toStringAsFixed(2)} MXN';
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool bold;

  const _MetricRow(this.label, this.value,
      {this.highlight = false, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.grey.shade700,
              )),
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? Colors.red.shade700 : null,
              )),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme colors;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
