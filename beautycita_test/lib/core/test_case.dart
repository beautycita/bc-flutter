import 'package:supabase_flutter/supabase_flutter.dart';
import 'test_result.dart';

/// Base class for all test cases.
/// Each test group implements this and provides its test list.
abstract class TestSuite {
  /// Display order in the dashboard (1 = top).
  int get order;

  /// Human-readable group name.
  String get name;

  /// Short description of what this group tests.
  String get description;

  /// Run all tests in this group. Returns the completed TestGroup.
  Future<TestGroup> run(SupabaseClient client);

  /// Helper: run a single test case with timing and error handling.
  Future<TestResult> runCase(String name, Future<TestResult> Function() fn) async {
    final sw = Stopwatch()..start();
    try {
      final result = await fn();
      sw.stop();
      return result.copyWith(duration: sw.elapsed);
    } catch (e, st) {
      sw.stop();
      return TestResult(
        name: name,
        status: TestStatus.failed,
        duration: sw.elapsed,
        error: e.toString(),
        detail: st.toString().split('\n').take(5).join('\n'),
      );
    }
  }

  /// Helper: create a passing result with optional metrics.
  TestResult pass(String name, {String? detail, Map<String, dynamic>? metrics}) =>
      TestResult(name: name, status: TestStatus.passed, detail: detail, metrics: metrics);

  /// Helper: create a failing result.
  TestResult fail(String name, String error, {String? detail}) =>
      TestResult(name: name, status: TestStatus.failed, error: error, detail: detail);

  /// Helper: create a warning result (passed but with concerns).
  TestResult warn(String name, String detail, {Map<String, dynamic>? metrics}) =>
      TestResult(name: name, status: TestStatus.warning, detail: detail, metrics: metrics);
}
