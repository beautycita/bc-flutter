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

import '../utils/base64url.dart';

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
    final challengeBytes = base64urlDecode(challenge);
    final userIdBytes = base64urlDecode(userId);

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
        'attestation': 'direct',
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
    final credentialId = base64urlEncode(rawId.toDart.asUint8List());

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
      attestationObject: base64urlEncode(attestBytes),
      clientDataJSON: base64urlEncode(clientDataBytes),
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
    final challengeBytes = base64urlDecode(challenge);

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
    final credentialId = base64urlEncode(rawId.toDart.asUint8List());

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
      authenticatorData: base64urlEncode(authDataBytes),
      clientDataJSON: base64urlEncode(clientDataBytes),
      signature: base64urlEncode(sigBytes),
    );
  }

  // base64url helpers moved to lib/utils/base64url.dart for testability.
}
