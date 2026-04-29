/// Mutable, session-scoped state for the demo portal at `/demo/*`.
///
/// Reads from [DemoData] as the read-only baseline, then layers session
/// mutations (reschedule, etc.) on top. State is keyed by the `demo_token`
/// minted by `demo-wa-funnel` and persisted in `sessionStorage`, so a tab
/// refresh keeps state but a new verify (fresh token) resets it.
///
/// Never persisted to backend — that violates the demo "resets on new
/// session" rule.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../data/demo_data.dart';

/// LocalStorage key for the `demo_token` minted by `demo-wa-funnel`.
const String demoTokenKey = 'bc-demo-token';

/// SessionStorage key prefix; full key is `bc-demo-state:{token}`.
const String _sessionStateKeyPrefix = 'bc-demo-state:';

/// Returns the active demo token from localStorage, or mints a fresh anon
/// key if none exists. Anon keys keep state for users who land at /demo
/// directly (the route is public — no token required to view).
String _activeToken() {
  try {
    final existing = web.window.localStorage.getItem(demoTokenKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final anon = 'demo-anon-$hex';
    web.window.localStorage.setItem(demoTokenKey, anon);
    return anon;
  } catch (_) {
    return 'demo-anon-fallback';
  }
}

String _stateKey(String token) => '$_sessionStateKeyPrefix$token';

/// Snapshot of session-mutable state. Immutable so Riverpod can diff it.
@immutable
class DemoSessionState {
  const DemoSessionState({required this.token, required this.appointments});

  final String token;
  final List<Map<String, dynamic>> appointments;

  DemoSessionState copyWith({List<Map<String, dynamic>>? appointments}) =>
      DemoSessionState(
        token: token,
        appointments: appointments ?? this.appointments,
      );
}

class DemoSessionNotifier extends StateNotifier<DemoSessionState> {
  DemoSessionNotifier() : super(_load(_activeToken()));

  static DemoSessionState _load(String token) {
    final hydrated = _readSessionStorage(token);
    if (hydrated != null) {
      return DemoSessionState(token: token, appointments: hydrated);
    }
    return DemoSessionState(
      token: token,
      appointments: _cloneAppointments(DemoData.appointments),
    );
  }

  /// Reset to baseline. Called when a new `demo_token` is detected (e.g.
  /// user re-verified their phone and got a fresh token).
  void resetForToken(String newToken) {
    if (newToken == state.token) return;
    try {
      web.window.sessionStorage.removeItem(_stateKey(state.token));
    } catch (_) {/* swallow */}
    state = DemoSessionState(
      token: newToken,
      appointments: _cloneAppointments(DemoData.appointments),
    );
    _persist();
  }

  /// Move an appointment to a new time and/or staff member.
  /// `staff_name` (nested) is updated when staff changes.
  void reschedule({
    required String appointmentId,
    required DateTime newStart,
    required DateTime newEnd,
    required String newStaffId,
    required String newStaffFirstName,
    required String newStaffLastName,
  }) {
    final updated = state.appointments.map((a) {
      if (a['id'] != appointmentId) return a;
      return {
        ...a,
        'starts_at': newStart.toIso8601String(),
        'ends_at': newEnd.toIso8601String(),
        'staff_id': newStaffId,
        'staff': {
          'first_name': newStaffFirstName,
          'last_name': newStaffLastName,
        },
      };
    }).toList();
    state = state.copyWith(appointments: updated);
    _persist();
  }

  /// Flip an appointment's status to cancelled and flip paid→refunded so
  /// the "Pagos" tab and dashboard counts update alongside the calendar.
  /// `reason` is the short enum (customer / business / admin).
  void cancel({
    required String appointmentId,
    String reason = 'business',
  }) {
    final status = switch (reason) {
      'customer' => 'cancelled_customer',
      'admin' => 'cancelled_admin',
      _ => 'cancelled_business',
    };
    final updated = state.appointments.map((a) {
      if (a['id'] != appointmentId) return a;
      final wasPaid = a['payment_status'] == 'paid';
      return {
        ...a,
        'status': status,
        if (wasPaid) 'payment_status': 'refunded',
      };
    }).toList();
    state = state.copyWith(appointments: updated);
    _persist();
  }

  void _persist() {
    try {
      web.window.sessionStorage.setItem(
        _stateKey(state.token),
        jsonEncode({'appointments': state.appointments}),
      );
    } catch (e) {
      // sessionStorage quota / unavailable — in-memory state still works,
      // but refresh will lose mutations. Log so DevTools shows the cause.
      debugPrint('[DemoSessionStore] persist failed (refresh will reset): $e');
    }
  }

  static List<Map<String, dynamic>>? _readSessionStorage(String token) {
    try {
      final raw = web.window.sessionStorage.getItem(_stateKey(token));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final appts = decoded['appointments'] as List?;
      if (appts == null) return null;
      return appts
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _cloneAppointments(
      List<Map<String, dynamic>> src) {
    return src.map((m) {
      final cloned = Map<String, dynamic>.from(m);
      if (cloned['staff'] is Map) {
        cloned['staff'] = Map<String, dynamic>.from(cloned['staff'] as Map);
      }
      return cloned;
    }).toList();
  }
}

/// Top-level provider for the demo session store.
/// Lives inside [DemoShell]'s [ProviderScope] only — outside the demo,
/// nothing reads it.
final demoSessionStoreProvider =
    StateNotifierProvider<DemoSessionNotifier, DemoSessionState>(
        (ref) => DemoSessionNotifier());
