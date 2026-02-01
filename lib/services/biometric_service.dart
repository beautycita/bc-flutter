import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';

/// Service for handling biometric authentication
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if the device has biometric hardware available
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Get list of available biometric types on this device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  /// Authenticate the user using biometrics
  /// Returns true if authentication succeeded, false otherwise
  Future<bool> authenticate() async {
    try {
      final bool canAuthenticate = await isBiometricAvailable();

      if (!canAuthenticate) {
        return false;
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: '¡Usa tu huella o rostro para entrar!',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      // Handle specific error cases
      if (e.code == auth_error.notAvailable) {
        // Biometrics not available
        return false;
      } else if (e.code == auth_error.notEnrolled) {
        // User hasn't enrolled biometrics
        return false;
      } else if (e.code == auth_error.lockedOut ||
                 e.code == auth_error.permanentlyLockedOut) {
        // Too many failed attempts
        return false;
      } else {
        // Other errors (user canceled, etc.)
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
