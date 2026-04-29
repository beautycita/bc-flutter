import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('send-push-notification callers', () {
    test('all callers use notification_type, not type', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final violations = <String>[];

      for (final file in dartFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].contains("'send-push-notification'")) continue;

          // Inspect next 30 lines for body shape
          final window = lines
              .sublist(i, (i + 30).clamp(0, lines.length))
              .join('\n');

          // Must use notification_type, not bare 'type'
          // (data: {'type': ...} nested inside data is allowed)
          final bareTypeRegex = RegExp(r"^\s*'type'\s*:", multiLine: true);
          if (bareTypeRegex.hasMatch(window) &&
              !window.contains('notification_type')) {
            violations.add('${file.path}:${i + 1}');
          }
          // If using custom_title/body keys, both must be present
          if (window.contains('custom_title') &&
              !window.contains('custom_body')) {
            violations.add(
                '${file.path}:${i + 1} (custom_title without custom_body)');
          }
          if (window.contains("'title'") &&
              !window.contains('custom_title')) {
            violations.add(
                '${file.path}:${i + 1} (raw title without custom_title)');
          }
        }
      }

      expect(violations, isEmpty,
          reason:
              'send-push-notification body-shape violations:\n${violations.join('\n')}');
    });
  });
}
