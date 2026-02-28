import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

enum ExportFormat { csv, excel, json, pdf, vcard }

class ExportColumn {
  final String key;
  final String label;
  const ExportColumn(this.key, this.label);
}

class ExportService {
  ExportService._();

  static Future<void> export({
    required List<Map<String, dynamic>> data,
    required List<ExportColumn> columns,
    required ExportFormat format,
    required String title,
    String? groupByKey,
  }) async {
    if (data.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final safeName = title.replaceAll(RegExp(r'[^\w]+'), '_').toLowerCase();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final ext = _extensionFor(format);
    final filePath = '${dir.path}/${safeName}_$timestamp.$ext';

    final File file;
    switch (format) {
      case ExportFormat.csv:
        file = await _generateCsv(filePath, data, columns);
      case ExportFormat.excel:
        file = await _generateExcel(filePath, data, columns, title, groupByKey);
      case ExportFormat.json:
        file = await _generateJson(filePath, data, columns);
      case ExportFormat.pdf:
        file = await _generatePdf(filePath, data, columns, title);
      case ExportFormat.vcard:
        file = await _generateVcard(filePath, data);
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '$title - ${data.length} registros',
    );
  }

  static String _extensionFor(ExportFormat format) {
    switch (format) {
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.excel:
        return 'xlsx';
      case ExportFormat.json:
        return 'json';
      case ExportFormat.pdf:
        return 'pdf';
      case ExportFormat.vcard:
        return 'vcf';
    }
  }

  // ---------------------------------------------------------------------------
  // CSV
  // ---------------------------------------------------------------------------

  static Future<File> _generateCsv(
    String path,
    List<Map<String, dynamic>> data,
    List<ExportColumn> columns,
  ) async {
    final rows = <List<dynamic>>[];

    // Header
    rows.add(columns.map((c) => c.label).toList());

    // Data rows
    for (final row in data) {
      rows.add(columns.map((c) => row[c.key]?.toString() ?? '').toList());
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final file = File(path);
    // UTF-8 BOM for Excel compatibility
    await file.writeAsString('\uFEFF$csvString', encoding: utf8);
    return file;
  }

  // ---------------------------------------------------------------------------
  // Excel
  // ---------------------------------------------------------------------------

  static Future<File> _generateExcel(
    String path,
    List<Map<String, dynamic>> data,
    List<ExportColumn> columns,
    String title,
    String? groupByKey,
  ) async {
    final workbook = xlsio.Workbook();
    // Remove default sheet — we'll create our own
    workbook.worksheets.clear();

    if (groupByKey != null) {
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final row in data) {
        final key = (row[groupByKey]?.toString() ?? 'Sin grupo');
        groups.putIfAbsent(key, () => []).add(row);
      }
      for (final entry in groups.entries) {
        final sheetName = entry.key.length > 31
            ? entry.key.substring(0, 31)
            : entry.key;
        final sheet = workbook.worksheets.addWithName(sheetName);
        _fillSheet(sheet, entry.value, columns);
      }
    } else {
      final sheetName = title.length > 31 ? title.substring(0, 31) : title;
      final sheet = workbook.worksheets.addWithName(sheetName);
      _fillSheet(sheet, data, columns);
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static void _fillSheet(
    xlsio.Worksheet sheet,
    List<Map<String, dynamic>> data,
    List<ExportColumn> columns,
  ) {
    // Header row (bold)
    for (var col = 0; col < columns.length; col++) {
      final cell = sheet.getRangeByIndex(1, col + 1);
      cell.setText(columns[col].label);
      cell.cellStyle.bold = true;
    }

    // Data rows
    for (var row = 0; row < data.length; row++) {
      for (var col = 0; col < columns.length; col++) {
        final cell = sheet.getRangeByIndex(row + 2, col + 1);
        final value = data[row][columns[col].key];
        if (value == null) {
          cell.setText('');
        } else if (value is num) {
          cell.setNumber(value.toDouble());
        } else {
          cell.setText(value.toString());
        }
      }
    }

    // Auto-fit columns
    for (var col = 1; col <= columns.length; col++) {
      sheet.autoFitColumn(col);
    }
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  static Future<File> _generateJson(
    String path,
    List<Map<String, dynamic>> data,
    List<ExportColumn> columns,
  ) async {
    final keys = columns.map((c) => c.key).toSet();
    final filtered = data.map((row) {
      return Map.fromEntries(
        row.entries.where((e) => keys.contains(e.key)),
      );
    }).toList();

    final encoder = const JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(filtered);

    final file = File(path);
    await file.writeAsString(jsonString, encoding: utf8);
    return file;
  }

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  static Future<File> _generatePdf(
    String path,
    List<Map<String, dynamic>> data,
    List<ExportColumn> columns,
    String title,
  ) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    const rowsPerPage = 30;
    final totalPages = (data.length / rowsPerPage).ceil();

    for (var page = 0; page < totalPages; page++) {
      final start = page * rowsPerPage;
      final end = (start + rowsPerPage).clamp(0, data.length);
      final pageData = data.sublist(start, end);

      final tableData = pageData.map((row) {
        return columns.map((c) => row[c.key]?.toString() ?? '').toList();
      }).toList();

      final currentPage = page + 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      dateStr,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${data.length} registros',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 12),
                // Table
                pw.Expanded(
                  child: pw.TableHelper.fromTextArray(
                    headers: columns.map((c) => c.label).toList(),
                    data: tableData,
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 7),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    cellAlignments: {
                      for (var i = 0; i < columns.length; i++)
                        i: pw.Alignment.centerLeft,
                    },
                  ),
                ),
                // Footer
                pw.SizedBox(height: 8),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Página $currentPage de $totalPages',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ---------------------------------------------------------------------------
  // vCard
  // ---------------------------------------------------------------------------

  static Future<File> _generateVcard(
    String path,
    List<Map<String, dynamic>> data,
  ) async {
    final buffer = StringBuffer();

    for (final row in data) {
      final name = (row['name'] ?? row['business_name'] ?? '').toString();
      final phone = (row['phone'] ?? '').toString();
      final address = (row['address'] ?? row['location_address'] ?? '').toString();
      final city = (row['city'] ?? row['location_city'] ?? '').toString();
      final state = (row['state'] ?? row['location_state'] ?? '').toString();
      final url = (row['url'] ?? row['website'] ?? '').toString();

      buffer.writeln('BEGIN:VCARD');
      buffer.writeln('VERSION:3.0');
      if (name.isNotEmpty) {
        buffer.writeln('FN:$name');
        buffer.writeln('ORG:$name');
      }
      if (phone.isNotEmpty) {
        buffer.writeln('TEL;TYPE=WORK:$phone');
      }
      if (address.isNotEmpty || city.isNotEmpty || state.isNotEmpty) {
        buffer.writeln('ADR;TYPE=WORK:;;$address;$city;;$state;');
      }
      if (url.isNotEmpty) {
        buffer.writeln('URL:$url');
      }
      buffer.writeln('END:VCARD');
      buffer.writeln();
    }

    final file = File(path);
    await file.writeAsString(buffer.toString(), encoding: utf8);
    return file;
  }
}
