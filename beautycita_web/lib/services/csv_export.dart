import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Escapes a single CSV field value.
/// Wraps in double-quotes if it contains commas, quotes, or newlines.
/// Internal double-quotes are escaped by doubling them.
String _escapeCsvField(String value) {
  if (value.contains('"') || value.contains(',') || value.contains('\n') || value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Generates a CSV string from [headers] and [rows].
///
/// Each row is a list of string values corresponding to the headers.
String generateCsv({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  final buffer = StringBuffer();

  // BOM for Excel UTF-8 detection
  buffer.write('\uFEFF');

  // Header row
  buffer.writeln(headers.map(_escapeCsvField).join(','));

  // Data rows
  for (final row in rows) {
    buffer.writeln(row.map(_escapeCsvField).join(','));
  }

  return buffer.toString();
}

/// Triggers a CSV file download in the browser.
void downloadCsv(String csvContent, String filename) {
  final bytes = utf8.encode(csvContent);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
