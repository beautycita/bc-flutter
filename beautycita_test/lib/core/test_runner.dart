import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'test_case.dart';
import 'test_result.dart';
import 'doc_reporter.dart';

/// Orchestrates running test suites — individual or all at once.
class TestRunner extends ChangeNotifier {
  final SupabaseClient _client;
  final List<TestSuite> _suites;
  final DocReporter _doc;

  List<TestGroup> _groups = [];
  bool _isRunning = false;
  DateTime? _lastRun;

  TestRunner({
    required SupabaseClient client,
    required List<TestSuite> suites,
    required DocReporter doc,
  })  : _client = client,
        _suites = suites,
        _doc = doc {
    // Initialize groups in display order
    _suites.sort((a, b) => a.order.compareTo(b.order));
    _groups = _suites
        .map((s) => TestGroup(
              order: s.order,
              name: s.name,
              description: s.description,
            ))
        .toList();
  }

  List<TestGroup> get groups => _groups;
  bool get isRunning => _isRunning;
  DateTime? get lastRun => _lastRun;

  int get totalPassed => _groups.fold(0, (sum, g) => sum + g.passedCount);
  int get totalFailed => _groups.fold(0, (sum, g) => sum + g.failedCount);
  int get totalWarnings => _groups.fold(0, (sum, g) => sum + g.warningCount);
  int get totalTests => _groups.fold(0, (sum, g) => sum + g.totalCount);

  /// Run all test suites sequentially.
  Future<void> runAll() async {
    if (_isRunning) return;
    _isRunning = true;
    notifyListeners();

    for (int i = 0; i < _suites.length; i++) {
      await _runSuiteAt(i);
    }

    _isRunning = false;
    _lastRun = DateTime.now();
    notifyListeners();

    // Report failures to Doc
    await _reportToDoc();
  }

  /// Run a single test suite by index.
  Future<void> runSingle(int index) async {
    if (_isRunning) return;
    _isRunning = true;
    notifyListeners();

    await _runSuiteAt(index);

    _isRunning = false;
    _lastRun = DateTime.now();
    notifyListeners();

    await _reportToDoc();
  }

  Future<void> _runSuiteAt(int index) async {
    // Mark as running
    _groups[index] = _groups[index].copyWith(groupStatus: TestStatus.running);
    notifyListeners();

    try {
      final result = await _suites[index].run(_client);
      _groups[index] = result;
    } catch (e) {
      _groups[index] = _groups[index].copyWith(
        groupStatus: TestStatus.failed,
        results: [
          TestResult(
            name: 'Suite crashed',
            status: TestStatus.failed,
            error: e.toString(),
          ),
        ],
      );
    }
    notifyListeners();
  }

  Future<void> _reportToDoc() async {
    for (final group in _groups) {
      for (final result in group.results) {
        if (result.isFailed) {
          await _doc.reportFailure(
            testGroup: group.name,
            testName: result.name,
            error: result.error ?? 'Unknown error',
            detail: result.detail,
          );
        }
      }
    }
  }
}
