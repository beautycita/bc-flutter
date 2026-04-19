import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/toast_service.dart';

/// Column definition for CSV export.
class CsvColumn<T> {
  final String header;
  final String Function(T item) value;

  const CsvColumn(this.header, this.value);
}

/// Exports any list of items to CSV and shares via system sheet.
class CsvExporter {
  /// Export items to CSV file and share.
  static Future<void> export<T>({
    required BuildContext context,
    required String filename,
    required List<CsvColumn<T>> columns,
    required List<T> items,
  }) async {
    if (items.isEmpty) {
      ToastService.showWarning('No hay datos para exportar');
      return;
    }

    try {
      final buffer = StringBuffer();

      // BOM for Excel UTF-8 compatibility
      buffer.write('\uFEFF');

      // Header row
      buffer.writeln(columns.map((c) => _escCsv(c.header)).join(','));

      // Data rows
      for (final item in items) {
        buffer.writeln(columns.map((c) => _escCsv(c.value(item))).join(','));
      }

      // Write to temp file
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/${filename}_$timestamp.csv');
      await file.writeAsString(buffer.toString());

      // Share
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '$filename - ${items.length} registros',
      ));

      ToastService.showSuccess('${items.length} registros exportados');
    } catch (e) {
      ToastService.showError('Error al exportar: $e');
    }
  }

  /// Export raw maps (for screens that work with Map<String, dynamic>).
  static Future<void> exportMaps({
    required BuildContext context,
    required String filename,
    required List<String> headers,
    required List<String> keys,
    required List<Map<String, dynamic>> items,
  }) async {
    await export<Map<String, dynamic>>(
      context: context,
      filename: filename,
      columns: List.generate(
        headers.length,
        (i) => CsvColumn(headers[i], (item) => _formatValue(item[keys[i]])),
      ),
      items: items,
    );
  }

  static String _formatValue(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) return DateFormat('yyyy-MM-dd HH:mm').format(v);
    if (v is double) return v.toStringAsFixed(2);
    return v.toString();
  }

  static String _escCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
