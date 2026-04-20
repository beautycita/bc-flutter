// Unit tests for the base64url codec used by the WebAuthn wire protocol
// (registration challenge, attestationObject, clientDataJSON, signatures).
//
// This file is platform-agnostic (pure Dart) so it runs under the default
// `flutter test` target without needing Chrome. The WebAuthn browser API
// itself is tested in webauthn_service_test.dart with @TestOn('browser').

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_web/utils/base64url.dart';

Uint8List _bytes(List<int> xs) => Uint8List.fromList(xs);

void main() {
  group('base64urlEncode', () {
    test('empty bytes → empty string', () {
      expect(base64urlEncode(_bytes([])), '');
    });

    test('single byte round-trips without padding markers', () {
      // 0xFF → standard b64 "/w==" → url "_w"
      expect(base64urlEncode(_bytes([0xFF])), '_w');
    });

    test('two bytes strip padding', () {
      // 0xFF 0xFF → std "//8=" → url "__8"
      expect(base64urlEncode(_bytes([0xFF, 0xFF])), '__8');
    });

    test('three bytes need no padding', () {
      // 0x14 0xFB 0x9C → std "FPuc" → url "FPuc"
      expect(base64urlEncode(_bytes([0x14, 0xFB, 0x9C])), 'FPuc');
    });

    test('encodes "+" and "/" as "-" and "_"', () {
      // 0xFB → would produce "+" in std; 0xFF 0xFF 0xBF uses both "+" and "/"
      final encoded = base64urlEncode(_bytes([0xFB, 0xEF, 0xFF]));
      expect(encoded.contains('+'), isFalse, reason: '+ must become -');
      expect(encoded.contains('/'), isFalse, reason: '/ must become _');
      expect(encoded.contains('='), isFalse, reason: 'padding must be stripped');
    });

    test('ASCII string encodes like dart:convert with url-safe chars', () {
      final input = Uint8List.fromList(utf8.encode('Hello, world!'));
      final got = base64urlEncode(input);
      // "Hello, world!" std b64 = "SGVsbG8sIHdvcmxkIQ=="
      expect(got, 'SGVsbG8sIHdvcmxkIQ');
    });
  });

  group('base64urlDecode', () {
    test('empty string → empty bytes', () {
      expect(base64urlDecode('').length, 0);
    });

    test('decodes with no padding', () {
      expect(base64urlDecode('FPuc'), equals(_bytes([0x14, 0xFB, 0x9C])));
    });

    test('decodes with missing padding (1-char tail)', () {
      expect(base64urlDecode('_w'), equals(_bytes([0xFF])));
    });

    test('decodes with missing padding (2-char tail)', () {
      expect(base64urlDecode('__8'), equals(_bytes([0xFF, 0xFF])));
    });

    test('accepts url-safe chars "-" and "_"', () {
      // "-" should be treated as "+", "_" as "/"
      final a = base64urlDecode('-_');
      final b = base64urlDecode('+/');
      expect(a, equals(b));
    });

    test('tolerates padding if present (backwards compat)', () {
      expect(base64urlDecode('FPuc='), equals(_bytes([0x14, 0xFB, 0x9C])));
      expect(base64urlDecode('_w=='), equals(_bytes([0xFF])));
    });
  });

  group('round-trip', () {
    test('arbitrary byte arrays survive encode→decode', () {
      final samples = <List<int>>[
        [],
        [0],
        [255],
        [0, 255],
        [0, 127, 255],
        List.generate(32, (i) => i * 7 & 0xFF),      // 32 bytes
        List.generate(64, (i) => (i * 31 + 13) & 0xFF), // 64 bytes (like a challenge)
        List.generate(128, (i) => (i * 251 + 17) & 0xFF), // 128 bytes
        List.generate(256, (i) => (i * 199 + 3) & 0xFF),  // 256 bytes
      ];
      for (final s in samples) {
        final bytes = _bytes(s);
        final encoded = base64urlEncode(bytes);
        final decoded = base64urlDecode(encoded);
        expect(decoded, equals(bytes),
            reason: 'round-trip failed for length ${s.length}');
      }
    });

    test('webauthn-sized challenge (32 random bytes)', () {
      // Simulates a server-issued challenge.
      final challenge = _bytes([
        0x3a, 0xe1, 0x74, 0xc9, 0x4d, 0x7b, 0x22, 0xf0,
        0x91, 0x44, 0xbc, 0xfe, 0x5d, 0x19, 0x82, 0x33,
        0xaa, 0x55, 0xee, 0x00, 0x7c, 0xb8, 0xd1, 0xe7,
        0x03, 0x88, 0xff, 0x22, 0x66, 0x09, 0xad, 0x42,
      ]);
      final encoded = base64urlEncode(challenge);
      // Length: 32 bytes → ceil(32*4/3) = 43 chars (no padding in url form)
      expect(encoded.length, 43);
      expect(encoded.contains('='), isFalse);
      expect(base64urlDecode(encoded), equals(challenge));
    });
  });
}
