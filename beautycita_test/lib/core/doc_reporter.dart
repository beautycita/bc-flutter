import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/test_config.dart';

/// Reports test failures to the Doc Holiday daemon as findings.
/// Circuit breaker: max 1 auto-repair attempt per test per run.
class DocReporter {
  final Set<String> _reportedThisRun = {};

  /// Report a test failure to Doc as a finding.
  Future<void> reportFailure({
    required String testGroup,
    required String testName,
    required String error,
    String? detail,
  }) async {
    final key = '$testGroup::$testName';
    if (_reportedThisRun.contains(key)) return; // Circuit breaker
    _reportedThisRun.add(key);

    if (TestConfig.docUrl.isEmpty) return;

    try {
      await http.post(
        Uri.parse('${TestConfig.docUrl}/finding'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source': 'test-apk',
          'group': testGroup,
          'test': testName,
          'error': error,
          'detail': detail,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Doc is best-effort — don't let reporting failures break tests
    }
  }

  /// Report that a previously-failing test now passes.
  Future<void> reportResolution({
    required String testGroup,
    required String testName,
  }) async {
    if (TestConfig.docUrl.isEmpty) return;

    try {
      await http.post(
        Uri.parse('${TestConfig.docUrl}/resolution'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'source': 'test-apk',
          'group': testGroup,
          'test': testName,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Reset circuit breaker for a new run.
  void resetForNewRun() => _reportedThisRun.clear();
}
