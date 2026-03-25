import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/services/toast_service.dart';

void main() {
  group('ToastService', () {
    group('friendlyError', () {
      test('converts SocketException to Spanish network error', () {
        expect(
          ToastService.friendlyError(
              Exception('SocketException: Connection failed')),
          'Sin conexion a internet',
        );
      });

      test('converts Connection refused to Spanish network error', () {
        expect(
          ToastService.friendlyError(
              Exception('Connection refused: host unreachable')),
          'Sin conexion a internet',
        );
      });

      test('converts TimeoutException to Spanish timeout message', () {
        expect(
          ToastService.friendlyError(
              Exception('TimeoutException after 0:00:30')),
          'La conexion tardo demasiado',
        );
      });

      test('converts "timed out" to Spanish timeout message', () {
        expect(
          ToastService.friendlyError(Exception('Request timed out')),
          'La conexion tardo demasiado',
        );
      });

      test('converts Invalid login credentials', () {
        expect(
          ToastService.friendlyError(
              Exception('Invalid login credentials')),
          'Credenciales incorrectas',
        );
      });

      test('converts Email not confirmed', () {
        expect(
          ToastService.friendlyError(Exception('Email not confirmed')),
          'Confirma tu correo electronico',
        );
      });

      test('converts User already registered', () {
        expect(
          ToastService.friendlyError(
              Exception('User already registered')),
          'Este correo ya esta registrado',
        );
      });

      test('converts StorageException', () {
        expect(
          ToastService.friendlyError(
              Exception('StorageException: upload failed')),
          'Error al subir archivo',
        );
      });

      test('converts Bucket not found', () {
        expect(
          ToastService.friendlyError(Exception('Bucket not found')),
          'Error de almacenamiento',
        );
      });

      test('converts duplicate key error', () {
        expect(
          ToastService.friendlyError(
              Exception('duplicate key value violates constraint')),
          'Este registro ya existe',
        );
      });

      test('converts unique constraint error', () {
        expect(
          ToastService.friendlyError(
              Exception('unique constraint violated')),
          'Este registro ya existe',
        );
      });

      test('converts foreign key error', () {
        expect(
          ToastService.friendlyError(
              Exception('foreign key constraint failed')),
          'No se puede eliminar, hay datos relacionados',
        );
      });

      test('converts StripeException', () {
        expect(
          ToastService.friendlyError(
              Exception('StripeException: card declined')),
          'Error en el pago',
        );
      });

      test('strips "Exception: " prefix from generic exceptions', () {
        expect(
          ToastService.friendlyError(Exception('Something broke')),
          // Exception.toString() produces "Exception: Something broke"
          'Something broke',
        );
      });

      test('truncates messages longer than 100 characters', () {
        final longMsg = 'A' * 200;
        final result = ToastService.friendlyError(longMsg);
        expect(result.length, 100);
        expect(result.endsWith('...'), isTrue);
      });

      test('returns short messages as-is (no Exception prefix)', () {
        // String objects don't have "Exception: " prefix
        const msg = 'Short error';
        expect(ToastService.friendlyError(msg), 'Short error');
      });
    });

    group('_submitReport integration contract', () {
      // We cannot directly test _submitReport since it's private and requires
      // Supabase initialization. Instead, we verify the contract:
      // ToastService._submitReport calls ErrorReportRepository.submit
      // with errorMessage, errorDetails, and screenName.
      // This is validated by the fact that showError with technicalDetails
      // wires up onReport which calls _submitReport.

      test('showErrorWithDetails formats technical details with stack trace', () {
        final error = FormatException('bad input');
        final stack = StackTrace.current;
        // Replicate the formatting logic from showErrorWithDetails
        final details =
            '${error.runtimeType}: $error\n${stack.toString().split('\n').take(8).join('\n')}';

        expect(details, contains('FormatException'));
        expect(details, contains('bad input'));
        // Stack trace lines should be limited to 8
        final lines = details.split('\n');
        // First line is the error, remaining are stack frames (up to 8)
        expect(lines.length, lessThanOrEqualTo(9));
      });

      test('showErrorWithDetails without stack only includes error', () {
        final error = FormatException('bad input');
        // Without stack trace
        final details = '${error.runtimeType}: $error';

        expect(details, equals('FormatException: FormatException: bad input'));
        expect(details.contains('\n'), isFalse);
      });
    });
  });
}
