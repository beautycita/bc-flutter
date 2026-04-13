/// Represents the outcome of a single test case.
enum TestStatus { pending, running, passed, failed, warning, skipped }

class TestResult {
  final String name;
  final TestStatus status;
  final Duration duration;
  final String? detail;
  final String? error;
  final Map<String, dynamic>? metrics;

  const TestResult({
    required this.name,
    this.status = TestStatus.pending,
    this.duration = Duration.zero,
    this.detail,
    this.error,
    this.metrics,
  });

  TestResult copyWith({
    TestStatus? status,
    Duration? duration,
    String? detail,
    String? error,
    Map<String, dynamic>? metrics,
  }) =>
      TestResult(
        name: name,
        status: status ?? this.status,
        duration: duration ?? this.duration,
        detail: detail ?? this.detail,
        error: error ?? this.error,
        metrics: metrics ?? this.metrics,
      );

  bool get isPassed => status == TestStatus.passed;
  bool get isFailed => status == TestStatus.failed;
  bool get isWarning => status == TestStatus.warning;
}

/// A group of related tests (e.g., "SAT Compliance API").
class TestGroup {
  final int order;
  final String name;
  final String description;
  final List<TestResult> results;
  final TestStatus groupStatus;
  final Duration totalDuration;

  const TestGroup({
    required this.order,
    required this.name,
    required this.description,
    this.results = const [],
    this.groupStatus = TestStatus.pending,
    this.totalDuration = Duration.zero,
  });

  TestGroup copyWith({
    List<TestResult>? results,
    TestStatus? groupStatus,
    Duration? totalDuration,
  }) =>
      TestGroup(
        order: order,
        name: name,
        description: description,
        results: results ?? this.results,
        groupStatus: groupStatus ?? this.groupStatus,
        totalDuration: totalDuration ?? this.totalDuration,
      );

  int get passedCount => results.where((r) => r.isPassed).length;
  int get failedCount => results.where((r) => r.isFailed).length;
  int get warningCount => results.where((r) => r.isWarning).length;
  int get totalCount => results.length;
}
