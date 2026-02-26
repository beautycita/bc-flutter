import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'supabase_client.dart';

/// Lightweight heartbeat that updates `profiles.last_seen` every 2 minutes
/// while the app is in the foreground. Pauses automatically when backgrounded.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final instance = PresenceService._();

  Timer? _timer;
  bool _started = false;
  static const _interval = Duration(minutes: 2);

  /// Call once after Supabase is initialized.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _ping(); // immediate first ping
    _timer = Timer.periodic(_interval, (_) => _ping());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ping();
      _timer ??= Timer.periodic(_interval, (_) => _ping());
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _ping() async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseClientService.client
          .from('profiles')
          .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId);
    } catch (e) {
      debugPrint('[Presence] ping failed: $e');
    }
  }
}
