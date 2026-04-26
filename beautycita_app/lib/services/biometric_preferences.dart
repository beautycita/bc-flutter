import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-device biometric login preferences. Stored in SharedPreferences so
/// each device manages its own setting independently.
class BiometricPreferences {
  static const _keyEnabled = 'biometric_login_enabled';

  /// True (default) when biometric login is offered on this device.
  /// When false, the auth screen falls back to email/password login.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }
}

final biometricPreferencesProvider = Provider<BiometricPreferences>(
  (_) => BiometricPreferences(),
);

/// Reactive read of the toggle. Watches a counter so the UI rebuilds when
/// setEnabled() is called via biometricPreferencesUpdater.
final biometricEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(_biometricPrefsTick);
  return ref.read(biometricPreferencesProvider).isEnabled();
});

final _biometricPrefsTick = StateProvider<int>((_) => 0);

extension BiometricPreferencesRefresh on Ref {
  Future<void> setBiometricEnabled(bool enabled) async {
    await read(biometricPreferencesProvider).setEnabled(enabled);
    read(_biometricPrefsTick.notifier).state++;
  }
}

extension BiometricPreferencesWidgetRef on WidgetRef {
  Future<void> setBiometricEnabled(bool enabled) async {
    await read(biometricPreferencesProvider).setEnabled(enabled);
    read(_biometricPrefsTick.notifier).state++;
  }
}
