import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Log severity level.
enum LogLevel { debug, info, warning, error, network }

/// Single log entry.
class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;
  final String? tag;

  const LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
    this.tag,
  });

  String get timeStr =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}.'
      '${timestamp.millisecond.toString().padLeft(3, '0')}';

  String get levelIcon => switch (level) {
        LogLevel.debug => 'D',
        LogLevel.info => 'I',
        LogLevel.warning => 'W',
        LogLevel.error => 'E',
        LogLevel.network => 'N',
      };
}

/// In-app debug log singleton. Captures logs in a ring buffer for on-device viewing.
class DebugLog {
  DebugLog._();
  static final DebugLog instance = DebugLog._();

  static const int _maxEntries = 1000;
  final Queue<LogEntry> _entries = Queue<LogEntry>();
  final List<VoidCallback> _listeners = [];

  bool _installed = false;

  /// Installs the global debugPrint override to also capture logs here.
  void install() {
    if (_installed) return;
    _installed = true;

    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      // Still print to console
      originalDebugPrint(message, wrapWidth: wrapWidth);
      if (message != null && message.isNotEmpty) {
        _add(LogEntry(
          message: message,
          level: _inferLevel(message),
          timestamp: DateTime.now(),
          tag: _inferTag(message),
        ));
      }
    };

    // Capture uncaught Flutter errors
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      error('FLUTTER ERROR: ${details.exceptionAsString()}\n${details.stack}');
      originalOnError?.call(details);
    };

    info('DebugLog installed — ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  }

  // --- Public API ---

  void debug(String message, {String? tag}) => _add(LogEntry(
        message: message,
        level: LogLevel.debug,
        timestamp: DateTime.now(),
        tag: tag,
      ));

  void info(String message, {String? tag}) => _add(LogEntry(
        message: message,
        level: LogLevel.info,
        timestamp: DateTime.now(),
        tag: tag,
      ));

  void warning(String message, {String? tag}) => _add(LogEntry(
        message: message,
        level: LogLevel.warning,
        timestamp: DateTime.now(),
        tag: tag,
      ));

  void error(String message, {String? tag}) => _add(LogEntry(
        message: message,
        level: LogLevel.error,
        timestamp: DateTime.now(),
        tag: tag,
      ));

  void network(String message, {String? tag}) => _add(LogEntry(
        message: message,
        level: LogLevel.network,
        timestamp: DateTime.now(),
        tag: tag ?? 'NET',
      ));

  List<LogEntry> get entries => _entries.toList();
  int get length => _entries.length;

  void clear() {
    _entries.clear();
    _notifyListeners();
  }

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Export log as plain text for sharing.
  String export() {
    final buf = StringBuffer();
    buf.writeln('=== BeautyCita Debug Log ===');
    buf.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buf.writeln('Entries: ${_entries.length}');
    buf.writeln('');
    for (final e in _entries) {
      buf.writeln('[${e.timeStr}] ${e.levelIcon} ${e.tag != null ? "(${e.tag}) " : ""}${e.message}');
    }
    return buf.toString();
  }

  // --- Internal ---

  void _add(LogEntry entry) {
    _entries.addLast(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    _notifyListeners();
  }

  void _notifyListeners() {
    for (final l in _listeners) {
      l();
    }
  }

  LogLevel _inferLevel(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('error') || lower.contains('exception') || lower.contains('failed')) {
      return LogLevel.error;
    }
    if (lower.contains('warning') || lower.contains('warn')) {
      return LogLevel.warning;
    }
    if (lower.contains('http') || lower.contains('response') || lower.contains('edge call')) {
      return LogLevel.network;
    }
    return LogLevel.debug;
  }

  String? _inferTag(String msg) {
    // Extract [Tag] from messages like "[Stripe] configured..."
    final match = RegExp(r'^\[(\w+)\]').firstMatch(msg);
    return match?.group(1);
  }
}
