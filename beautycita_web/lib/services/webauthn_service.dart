/// WebAuthn (passkey) service for Flutter web.
///
/// Wraps the browser's `navigator.credentials` API via `dart:js_interop`
/// to support registration and login with Windows Hello, Touch ID, etc.
///
/// This file only compiles on web targets.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Result from a WebAuthn registration ceremony.
class WebAuthnRegistrationResult {
  final String credentialId;
  final String attestationObject; // base64url
  final String clientDataJSON; // base64url

  const WebAuthnRegistrationResult({
    required this.credentialId,
    required this.attestationObject,
    required this.clientDataJSON,
  });
}

/// Result from a WebAuthn login ceremony.
class WebAuthnLoginResult {
  final String credentialId;
  final String authenticatorData; // base64url
  final String clientDataJSON; // base64url
  final String signature; // base64url

  const WebAuthnLoginResult({
    required this.credentialId,
    required this.authenticatorData,
    required this.clientDataJSON,
    required this.signature,
  });
}

/// Service for WebAuthn (passkey) operations in the browser.
class WebAuthnService {
  /// Check if the browser supports WebAuthn.
  static bool isSupported() {
    try {
      final pkc = globalContext
          .getProperty<JSAny?>('PublicKeyCredential'.toJS);
      return pkc != null;
    } catch (_) {
      return false;
    }
  }

  /// Register a new passkey credential.
  ///
  /// [challenge] is a base64url-encoded random challenge from the server.
  /// [rpId] is the relying party ID (e.g. "beautycita.com").
  /// [rpName] is the relying party display name.
  /// [userId] is a base64url-encoded user identifier.
  /// [userName] is the user's login name (email).
  /// [userDisplayName] is the user's display name.
  static Future<WebAuthnRegistrationResult> register({
    required String challenge,
    required String rpId,
    required String rpName,
    required String userId,
    required String userName,
    required String userDisplayName,
  }) async {
    final challengeBytes = _base64urlToUint8List(challenge);
    final userIdBytes = _base64urlToUint8List(userId);

    // Build the PublicKeyCredentialCreationOptions via JS object literals
    final options = <String, Object?>{
      'publicKey': <String, Object?>{
        'rp': <String, Object?>{
          'name': rpName,
          'id': rpId,
        },
        'user': <String, Object?>{
          'id': userIdBytes.toJS,
          'name': userName,
          'displayName': userDisplayName,
        },
        'challenge': challengeBytes.toJS,
        'pubKeyCredParams': [
          <String, Object?>{'type': 'public-key', 'alg': -7}, // ES256
        ],
        'timeout': 60000,
        'authenticatorSelection': <String, Object?>{
          'authenticatorAttachment': 'platform',
          'userVerification': 'required',
          'residentKey': 'preferred',
          'requireResidentKey': false,
        },
        'attestation': 'none',
      },
    }.jsify() as JSObject;

    final credential = await web.window.navigator.credentials
        .create(options as web.CredentialCreationOptions)
        .toDart;

    if (credential == null) {
      throw Exception('User cancelled or no credential returned');
    }

    final credObj = credential as JSObject;

    // Extract credential ID
    final rawId = credObj.getProperty<JSArrayBuffer>('rawId'.toJS);
    final credentialId = _uint8ListToBase64url(rawId.toDart.asUint8List());

    // Extract attestation response
    final response = credObj.getProperty<JSObject>('response'.toJS);
    final attestObjBuf =
        response.callMethod<JSArrayBuffer>('getAttestationObject'.toJS);

    // Some browsers use a property, some use a method — handle both
    // Actually, the response object for create() has .attestationObject
    // as a getter property (ArrayBuffer), not a method.
    final attestObjProp =
        response.getProperty<JSAny?>('attestationObject'.toJS);
    final Uint8List attestBytes;
    if (attestObjProp != null) {
      attestBytes = (attestObjProp as JSArrayBuffer).toDart.asUint8List();
    } else {
      attestBytes = attestObjBuf.toDart.asUint8List();
    }

    final clientDataBuf =
        response.getProperty<JSArrayBuffer>('clientDataJSON'.toJS);
    final clientDataBytes = clientDataBuf.toDart.asUint8List();

    return WebAuthnRegistrationResult(
      credentialId: credentialId,
      attestationObject: _uint8ListToBase64url(attestBytes),
      clientDataJSON: _uint8ListToBase64url(clientDataBytes),
    );
  }

  /// Authenticate with an existing passkey.
  ///
  /// [challenge] is a base64url-encoded random challenge from the server.
  /// [rpId] is the relying party ID (e.g. "beautycita.com").
  static Future<WebAuthnLoginResult> login({
    required String challenge,
    required String rpId,
  }) async {
    final challengeBytes = _base64urlToUint8List(challenge);

    final options = <String, Object?>{
      'publicKey': <String, Object?>{
        'challenge': challengeBytes.toJS,
        'rpId': rpId,
        'timeout': 60000,
        'userVerification': 'required',
      },
    }.jsify() as JSObject;

    final credential = await web.window.navigator.credentials
        .get(options as web.CredentialRequestOptions)
        .toDart;

    if (credential == null) {
      throw Exception('User cancelled or no credential returned');
    }

    final credObj = credential as JSObject;

    // Extract credential ID
    final rawId = credObj.getProperty<JSArrayBuffer>('rawId'.toJS);
    final credentialId = _uint8ListToBase64url(rawId.toDart.asUint8List());

    // Extract assertion response
    final response = credObj.getProperty<JSObject>('response'.toJS);

    final authDataBuf =
        response.getProperty<JSArrayBuffer>('authenticatorData'.toJS);
    final authDataBytes = authDataBuf.toDart.asUint8List();

    final clientDataBuf =
        response.getProperty<JSArrayBuffer>('clientDataJSON'.toJS);
    final clientDataBytes = clientDataBuf.toDart.asUint8List();

    final sigBuf = response.getProperty<JSArrayBuffer>('signature'.toJS);
    final sigBytes = sigBuf.toDart.asUint8List();

    return WebAuthnLoginResult(
      credentialId: credentialId,
      authenticatorData: _uint8ListToBase64url(authDataBytes),
      clientDataJSON: _uint8ListToBase64url(clientDataBytes),
      signature: _uint8ListToBase64url(sigBytes),
    );
  }

  // ── Base64url helpers ──────────────────────────────────────────────────────

  static Uint8List _base64urlToUint8List(String str) {
    // Restore standard base64
    String s = str.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    // Use dart:convert to decode
    final decoded = _base64Decode(s);
    return decoded;
  }

  static String _uint8ListToBase64url(Uint8List bytes) {
    final encoded = _base64Encode(bytes);
    return encoded
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
  }

  /// Manual base64 decode (avoiding import of dart:convert to keep clean).
  static Uint8List _base64Decode(String input) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final output = <int>[];
    final buf = <int>[];

    for (int i = 0; i < input.length; i++) {
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

  /// Manual base64 encode.
  static String _base64Encode(Uint8List bytes) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buf = StringBuffer();
    int i = 0;
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
}
