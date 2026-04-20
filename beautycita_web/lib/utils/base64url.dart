/// Base64url encode/decode helpers for WebAuthn + other crypto flows.
///
/// WebAuthn wire format uses base64url (RFC 4648 §5) — '+'→'-', '/'→'_',
/// padding stripped. Extracted from webauthn_service.dart so the encoding
/// can be unit-tested without importing dart:js_interop.
library;

import 'dart:typed_data';

/// Decode a base64url string to bytes. Accepts input with or without padding.
/// Returns an empty list for empty input. Silently ignores invalid characters
/// to match the permissive behavior of the original inline implementation.
Uint8List base64urlDecode(String input) {
  // Restore standard base64: '-' → '+', '_' → '/', pad to multiple of 4.
  var s = input.replaceAll('-', '+').replaceAll('_', '/');
  while (s.length % 4 != 0) {
    s += '=';
  }
  return _base64Decode(s);
}

/// Encode bytes to a base64url string. Strips trailing padding, replaces
/// '+' with '-' and '/' with '_' for URL safety.
String base64urlEncode(Uint8List bytes) {
  return _base64Encode(bytes)
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

// ── Internal standard-base64 helpers (intentionally not using dart:convert
// so this module stays tiny and its behavior is fully inspectable). ────────

Uint8List _base64Decode(String input) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final output = <int>[];
  final buf = <int>[];

  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (c == '=') break;
    final idx = alphabet.indexOf(c);
    if (idx == -1) continue;
    buf.add(idx);
    if (buf.length == 4) {
      output.add((buf[0] << 2) | (buf[1] >> 4));
      output.add(((buf[1] & 0x0F) << 4) | (buf[2] >> 2));
      output.add(((buf[2] & 0x03) << 6) | buf[3]);
      buf.clear();
    }
  }
  if (buf.length == 2) {
    output.add((buf[0] << 2) | (buf[1] >> 4));
  } else if (buf.length == 3) {
    output.add((buf[0] << 2) | (buf[1] >> 4));
    output.add(((buf[1] & 0x0F) << 4) | (buf[2] >> 2));
  }

  return Uint8List.fromList(output);
}

String _base64Encode(Uint8List bytes) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final buf = StringBuffer();
  var i = 0;
  while (i < bytes.length) {
    final b0 = bytes[i++];
    buf.write(alphabet[b0 >> 2]);
    if (i < bytes.length) {
      final b1 = bytes[i++];
      buf.write(alphabet[((b0 & 0x03) << 4) | (b1 >> 4)]);
      if (i < bytes.length) {
        final b2 = bytes[i++];
        buf.write(alphabet[((b1 & 0x0F) << 2) | (b2 >> 6)]);
        buf.write(alphabet[b2 & 0x3F]);
      } else {
        buf.write(alphabet[(b1 & 0x0F) << 2]);
        buf.write('=');
      }
    } else {
      buf.write(alphabet[(b0 & 0x03) << 4]);
      buf.write('==');
    }
  }
  return buf.toString();
}
