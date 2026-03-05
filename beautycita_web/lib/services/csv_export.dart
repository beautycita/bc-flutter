import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
