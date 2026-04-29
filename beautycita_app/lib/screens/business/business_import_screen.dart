import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../config/fonts.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

/// Universal smart importer — drop a CSV/JSON/XML/TSV from any salon SaaS
/// (Fresha, Booksy, Vagaro, Square, Acuity, GlossGenius, Schedulicity, etc.)
/// or a generic file with the right kinds of columns. The edge function
/// detects the format, fingerprints headers against a multilingual semantic
/// dictionary, and maps onto BeautyCita's clients table. Preview before commit.
class BusinessImportScreen extends ConsumerStatefulWidget {
  const BusinessImportScreen({super.key});

  @override
  ConsumerState<BusinessImportScreen> createState() =>
      _BusinessImportScreenState();
}

class _BusinessImportScreenState extends ConsumerState<BusinessImportScreen> {
  String? _fileName;
  String? _fileText;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'json', 'xml', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        setState(() => _error = 'No se pudo leer el archivo');
        return;
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      setState(() {
        _fileName = f.name;
        _fileText = text;
        _preview = null;
        _result = null;
      });
      await _runPreview();
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }

  Future<void> _runPreview() async {
    final text = _fileText;
    if (text == null) return;
    final biz = await ref.read(currentBusinessProvider.future);
    final bizId = biz?['id'] as String?;
    if (bizId == null) {
      setState(() => _error = 'No se encontró tu negocio');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await SupabaseClientService.client.functions.invoke(
        'import-business-data',
        body: {
          'action': 'preview',
          'business_id': bizId,
          'file_name': _fileName ?? 'paste.csv',
          'text': text,
        },
      );
      final data = res.data;
      if (data is Map && data['error'] != null) {
        setState(() => _error = data['error'].toString());
      } else if (data is Map) {
        setState(() => _preview = Map<String, dynamic>.from(data));
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _commit() async {
    final text = _fileText;
    if (text == null) return;
    final biz = await ref.read(currentBusinessProvider.future);
    final bizId = biz?['id'] as String?;
    if (bizId == null) return;

    setState(() => _loading = true);
    try {
      final res = await SupabaseClientService.client.functions.invoke(
        'import-business-data',
        body: {
          'action': 'commit',
          'business_id': bizId,
          'file_name': _fileName ?? 'paste.csv',
          'text': text,
        },
      );
      final data = res.data;
      if (data is Map && data['error'] != null) {
        setState(() => _error = data['error'].toString());
      } else if (data is Map) {
        setState(() => _result = Map<String, dynamic>.from(data));
        if (mounted) {
          ToastService.showSuccess(
            'Importados: ${data['inserted_count']} nuevos, '
            '${data['updated_count']} actualizados',
          );
        }
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Importar clientes',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIntro(cs),
            const SizedBox(height: AppConstants.paddingLG),
            if (_result != null)
              _buildResultCard(cs)
            else ...[
              _buildPickerCard(cs),
              if (_loading) ...[
                const SizedBox(height: AppConstants.paddingLG),
                const Center(child: CircularProgressIndicator()),
              ] else if (_preview != null) ...[
                const SizedBox(height: AppConstants.paddingLG),
                _buildPreviewCard(cs),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: AppConstants.paddingMD),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: cs.onErrorContainer)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Universal — sin formato fijo',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        const SizedBox(height: 6),
        Text(
          'Sube tu lista de clientes desde Fresha, Booksy, Vagaro, Square, '
          'Acuity, GlossGenius, Schedulicity, Mangomint, o cualquier CSV/JSON/XML. '
          'Detectamos los campos automáticamente y los alineamos con BeautyCita.',
          style: GoogleFonts.nunito(
              fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildPickerCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_upload_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 12),
          Text(
            _fileName ?? 'Selecciona tu archivo',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'CSV · TSV · JSON · XML',
            style: GoogleFonts.nunito(
                fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(_fileName == null ? 'Elegir archivo' : 'Cambiar archivo'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(ColorScheme cs) {
    final p = _preview!;
    final detected = p['detected_source'] as String? ?? 'Genérico';
    final format = (p['detected_format'] as String? ?? '').toUpperCase();
    final total = p['total_rows'] as int? ?? 0;
    final mappable = p['mappable_count'] as int? ?? 0;
    final issues = p['issues_count'] as int? ?? 0;
    final headerMap = (p['header_map'] as Map?) ?? {};
    final rows = (p['preview_rows'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(cs, 'Detectado: $detected', cs.primary),
              _chip(cs, format, cs.secondary),
              _chip(cs, '$total filas', cs.tertiary),
              _chip(cs, '$mappable importables', Colors.green),
              if (issues > 0) _chip(cs, '$issues con problemas', cs.error),
            ],
          ),
          const SizedBox(height: 16),
          Text('Mapeo automático',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 6),
          ...headerMap.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${e.key}',
                          style: GoogleFonts.nunito(
                              fontSize: 12, color: cs.onSurface)),
                    ),
                    Icon(Icons.arrow_forward, size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: Text('${e.value}',
                          style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.primary)),
                    ),
                  ],
                ),
              )),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Vista previa (${rows.length} de $total)',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
            const SizedBox(height: 6),
            ...rows.map((r) {
              final m = r as Map;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['client_name']?.toString() ?? '(sin nombre)',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    if (m['phone'] != null)
                      Text(m['phone'].toString(),
                          style: GoogleFonts.nunito(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.7))),
                    if (m['email'] != null)
                      Text(m['email'].toString(),
                          style: GoogleFonts.nunito(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.7))),
                    if (m['issue'] != null)
                      Text('⚠ ${m['issue']}',
                          style: GoogleFonts.nunito(fontSize: 11, color: cs.error)),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loading || mappable == 0 ? null : _commit,
            icon: const Icon(Icons.check_circle_outline),
            label: Text('Importar $mappable clientes'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ColorScheme cs) {
    final r = _result!;
    final inserted = r['inserted_count'] as int? ?? 0;
    final updated = r['updated_count'] as int? ?? 0;
    final skipped = r['skipped_count'] as int? ?? 0;
    final errors = (r['errors'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.celebration, size: 56, color: Colors.green.shade600),
          const SizedBox(height: 12),
          Text('Importación completa',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 16),
          _resultRow('Nuevos clientes', inserted, Colors.green, cs),
          _resultRow('Actualizados', updated, cs.primary, cs),
          if (skipped > 0) _resultRow('Saltados', skipped, cs.error, cs),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: Text('Ver detalles (${errors.length})',
                  style: GoogleFonts.nunito(fontSize: 13, color: cs.onSurface)),
              children: errors.take(20).map<Widget>((e) {
                final em = e as Map;
                return ListTile(
                  dense: true,
                  leading: Text('#${em['row_idx']}',
                      style: GoogleFonts.nunito(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                  title: Text(em['reason']?.toString() ?? '',
                      style: GoogleFonts.nunito(fontSize: 12, color: cs.onSurface)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _fileName = null;
                _fileText = null;
                _preview = null;
                _result = null;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Importar otro archivo'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, int count, Color color, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.nunito(fontSize: 14, color: cs.onSurface)),
          ),
          Text('$count',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _chip(ColorScheme cs, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: GoogleFonts.nunito(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
