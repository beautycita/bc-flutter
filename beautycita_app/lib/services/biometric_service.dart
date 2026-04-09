import 'package:local_auth/local_auth.dart';

/// Service for handling biometric authentication
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if the device has biometric hardware available
  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Get list of available biometric types on this device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
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
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      return authenticated;
    } on LocalAuthException {
      return false;
    } catch (e) {
      return false;
    }
  }
}
