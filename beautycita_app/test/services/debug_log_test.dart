import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/services/debug_log.dart';

void main() {
  late DebugLog log;

  setUp(() {
    log = DebugLog.instance;
    log.clear();
  });

  tearDown(() {
    log.clear();
  });

  group('DebugLog', () {
    group('basic logging', () {
      test('adds debug entries', () {
        log.debug('test message');
        expect(log.length, 1);
        expect(log.entries.first.message, 'test message');
        expect(log.entries.first.level, LogLevel.debug);
      });

      test('adds info entries', () {
        log.info('info message');
        expect(log.entries.first.level, LogLevel.info);
      });

      test('adds warning entries', () {
        log.warning('warning message');
        expect(log.entries.first.level, LogLevel.warning);
      });

      test('adds error entries', () {
        log.error('error message');
        expect(log.entries.first.level, LogLevel.error);
      });

      test('adds network entries', () {
        log.network('HTTP 200');
        expect(log.entries.first.level, LogLevel.network);
      });

      test('stores tag when provided', () {
        log.info('tagged', tag: 'AUTH');
        expect(log.entries.first.tag, 'AUTH');
      });

      test('network defaults tag to NET', () {
        log.network('request');
        expect(log.entries.first.tag, 'NET');
      });
    });

    group('ring buffer', () {
      test('caps at 1000 entries', () {
        for (var i = 0; i < 1100; i++) {
          log.debug('entry $i');
        }
        expect(log.length, 1000);
      });

      test('oldest entries are evicted first', () {
        for (var i = 0; i < 1100; i++) {
          log.debug('entry $i');
        }
        // First entry should be entry 100 (entries 0-99 evicted)
        expect(log.entries.first.message, 'entry 100');
        expect(log.entries.last.message, 'entry 1099');
      });
    });

    group('clear', () {
      test('removes all entries', () {
        log.debug('one');
        log.debug('two');
        log.clear();

        expect(log.length, 0);
        expect(log.entries, isEmpty);
      });
    });

    group('listeners', () {
      test('notifies on new entry', () {
        var callCount = 0;
        void listener() => callCount++;

        log.addListener(listener);
        log.debug('test');

        expect(callCount, 1);

        log.removeListener(listener);
      });

      test('notifies on clear', () {
        var callCount = 0;
        void listener() => callCount++;

        log.addListener(listener);
        log.debug('test'); // +1
        log.clear(); // +1

        expect(callCount, 2);

        log.removeListener(listener);
      });

      test('removed listener is not called', () {
        var callCount = 0;
        void listener() => callCount++;

        log.addListener(listener);
        log.debug('one');
        log.removeListener(listener);
        log.debug('two');

        expect(callCount, 1);
      });
    });

    group('export', () {
      test('includes header and entries', () {
        log.info('test entry', tag: 'TEST');
        final exported = log.export();

        expect(exported, contains('BeautyCita Debug Log'));
        expect(exported, contains('Entries: 1'));
        expect(exported, contains('test entry'));
        expect(exported, contains('(TEST)'));
      });

      test('includes entry count', () {
        log.debug('a');
        log.debug('b');
        final exported = log.export();

        expect(exported, contains('Entries: 2'));
      });
    });

    group('LogEntry', () {
      test('timeStr formats HH:MM:SS.mmm', () {
        final entry = LogEntry(
          message: 'test',
          level: LogLevel.debug,
          timestamp: DateTime(2026, 3, 5, 9, 5, 3, 42),
        );

        expect(entry.timeStr, '09:05:03.042');
      });

      test('levelIcon returns correct letters', () {
        final levels = {
          LogLevel.debug: 'D',
          LogLevel.info: 'I',
          LogLevel.warning: 'W',
          LogLevel.error: 'E',
          LogLevel.network: 'N',
        };

        for (final entry in levels.entries) {
          final logEntry = LogEntry(
            message: '',
            level: entry.key,
            timestamp: DateTime.now(),
          );
          expect(logEntry.levelIcon, entry.value);
        }
      });
    });
  });
}
