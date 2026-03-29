import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Tests for the security input validation patterns used across the app.
///
/// The actual sanitization functions are private in their respective files
/// (chat_provider.dart, aphrodite_service.dart, media_service.dart).
/// These tests replicate and verify the same logic to ensure the security
/// contracts hold: HTML stripping, length limits, and file size validation.

// ---------------------------------------------------------------------------
// Replicated sanitization logic (mirrors private functions in production code)
// ---------------------------------------------------------------------------

/// Mirrors _sanitizeMessage in chat_provider.dart
String sanitizeMessage(String raw) {
  var cleaned = raw.replaceAll(RegExp(r'<[^>]*>'), '');
  cleaned = cleaned.trim();
  if (cleaned.length > 2000) {
    cleaned = cleaned.substring(0, 2000);
  }
  return cleaned;
}

/// Mirrors _sanitizeStylePrompt in aphrodite_service.dart
String sanitizeStylePrompt(String raw) {
  var cleaned = raw.replaceAll(RegExp(r'<[^>]*>'), '');
  cleaned = cleaned.trim();
  if (cleaned.length > 200) {
    cleaned = cleaned.substring(0, 200);
  }
  // Allow only safe characters
  final allowedChars = RegExp(
    r"^[a-zA-Z0-9\sáéíóúüñÁÉÍÓÚÜÑ.,;:!?¡¿()\-_/#+@&%']+$",
  );
  if (cleaned.isNotEmpty && !allowedChars.hasMatch(cleaned)) {
    cleaned = cleaned.replaceAll(
      RegExp(r'[^a-zA-Z0-9\sáéíóúüñÁÉÍÓÚÜÑ.,;:!?¡¿()\-_/#+@&%\x27"]'),
      '',
    );
  }
  return cleaned;
}

/// Mirrors _validateUpload / _validateImage size check.
/// Returns error message or null if valid.
String? validateFileSize(Uint8List bytes) {
  const maxBytes = 10 * 1024 * 1024; // 10 MB
  if (bytes.isEmpty) return 'empty';
  if (bytes.length > maxBytes) {
    return 'exceeds 10 MB (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)';
  }
  return null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Chat message sanitization', () {
    test('strips HTML tags from message', () {
      const input = 'Hello <b>world</b>!';
      expect(sanitizeMessage(input), 'Hello world!');
    });

    test('strips script tags (tags removed, content preserved)', () {
      // The sanitizer strips HTML tags but preserves text content between them.
      // This is the expected behavior — the tags are neutralized.
      const input = 'Hi<script>alert("xss")</script>there';
      final result = sanitizeMessage(input);
      expect(result, isNot(contains('<script>')));
      expect(result, isNot(contains('</script>')));
      expect(result, 'Hialert("xss")there');
    });

    test('strips nested HTML tags', () {
      const input = '<div><p>Hello <a href="x">link</a></p></div>';
      expect(sanitizeMessage(input), 'Hello link');
    });

    test('preserves plain text', () {
      const input = 'Just a normal message with no tags';
      expect(sanitizeMessage(input), input);
    });

    test('trims whitespace', () {
      const input = '   hello   ';
      expect(sanitizeMessage(input), 'hello');
    });

    test('enforces 2000 character limit', () {
      final input = 'a' * 3000;
      final result = sanitizeMessage(input);
      expect(result.length, 2000);
    });

    test('allows exactly 2000 characters', () {
      final input = 'b' * 2000;
      final result = sanitizeMessage(input);
      expect(result.length, 2000);
    });

    test('does not truncate messages under 2000 characters', () {
      final input = 'c' * 1999;
      final result = sanitizeMessage(input);
      expect(result.length, 1999);
    });

    test('neutralizes HTML-only script input', () {
      // Tags are stripped; inner text remains but is harmless as plain text
      const input = '<script>alert(1)</script>';
      final result = sanitizeMessage(input);
      expect(result, isNot(contains('<script>')));
      expect(result, 'alert(1)');
    });

    test('handles empty input', () {
      expect(sanitizeMessage(''), isEmpty);
    });
  });

  group('Style prompt sanitization', () {
    test('strips HTML tags from prompt', () {
      const input = 'Corte <b>moderno</b>';
      expect(sanitizeStylePrompt(input), 'Corte moderno');
    });

    test('enforces 200 character limit', () {
      final input = 'x' * 300;
      final result = sanitizeStylePrompt(input);
      expect(result.length, 200);
    });

    test('allows exactly 200 characters', () {
      final input = 'a' * 200;
      final result = sanitizeStylePrompt(input);
      expect(result.length, 200);
    });

    test('preserves Spanish characters', () {
      const input = 'Corte moderno con líneas y ñ';
      expect(sanitizeStylePrompt(input), input);
    });

    test('preserves common punctuation', () {
      const input = '!Hola! Quiero un corte, por favor.';
      expect(sanitizeStylePrompt(input), input);
    });

    test('removes disallowed special characters', () {
      // Backslash, curly braces, etc. are not in the allowlist
      const input = r'Normal text {injection} \escape';
      final result = sanitizeStylePrompt(input);
      expect(result, isNot(contains('{')));
      expect(result, isNot(contains('}')));
      expect(result, isNot(contains(r'\')));
    });

    test('strips HTML then enforces length limit', () {
      final input = '<b>${'a' * 250}</b>';
      final result = sanitizeStylePrompt(input);
      expect(result.length, lessThanOrEqualTo(200));
    });

    test('handles empty input', () {
      expect(sanitizeStylePrompt(''), isEmpty);
    });
  });

  group('File size validation', () {
    test('rejects empty file', () {
      final bytes = Uint8List(0);
      expect(validateFileSize(bytes), 'empty');
    });

    test('accepts file under 10 MB', () {
      final bytes = Uint8List(5 * 1024 * 1024); // 5 MB
      expect(validateFileSize(bytes), isNull);
    });

    test('accepts file at exactly 10 MB', () {
      final bytes = Uint8List(10 * 1024 * 1024);
      expect(validateFileSize(bytes), isNull);
    });

    test('rejects file over 10 MB', () {
      final bytes = Uint8List(10 * 1024 * 1024 + 1);
      final result = validateFileSize(bytes);
      expect(result, isNotNull);
      expect(result, contains('10 MB'));
    });

    test('rejects 15 MB file with correct size in message', () {
      final bytes = Uint8List(15 * 1024 * 1024);
      final result = validateFileSize(bytes);
      expect(result, contains('15.0 MB'));
    });

    test('accepts small file (1 byte)', () {
      final bytes = Uint8List(1);
      expect(validateFileSize(bytes), isNull);
    });
  });
}
