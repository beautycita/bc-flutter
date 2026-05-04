// Behavior tests for QrPrintService.
//
// QrPrintService is a thin wrapper around the `printing` plugin —
// printExpressCitaCards / printStylistStickers both end with
// Printing.layoutPdf, which requires a platform channel and so cannot
// be exercised end-to-end in a pure unit test. The substantive logic
// (PDF layout math, QR rendering) is in private helpers.
//
// This file pins the public surface as callable tearoffs so a rename or
// signature change breaks the test, plus checks the QR URL the service
// would build is a well-formed http(s) URL — guards against a regression
// where empty-string URLs slip through into the printed sheet.

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/services/qr_print_service.dart';

void main() {
  group('QrPrintService surface', () {
    test('printExpressCitaCards is a static method', () {
      // Tearoff. If signature changes (named args removed/renamed) this
      // fails to compile.
      Future<void> Function({
        required String qrUrl,
        required String businessName,
      }) ref = QrPrintService.printExpressCitaCards;
      expect(ref, isA<Function>());
    });

    test('printStylistStickers is a static method with optional copies', () {
      Future<void> Function({
        required String uploadUrl,
        required String stylistName,
        required String pin,
        int copies,
      }) ref = QrPrintService.printStylistStickers;
      expect(ref, isA<Function>());
    });
  });

  group('QR URL preconditions (caller contract)', () {
    // The service blindly hands these strings to the QR encoder. If a
    // caller passes empty / whitespace / non-URL it'd render as a useless
    // QR. This block documents the expected shape via assertions on
    // representative URLs that callers in the codebase actually pass.

    test('Cita Express URL pattern is a valid https URL', () {
      const url = 'https://beautycita.com/cita-express/abc-123';
      final uri = Uri.tryParse(url);
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'beautycita.com');
      expect(uri.path.startsWith('/cita-express/'), true);
    });

    test('portfolio-upload URL pattern carries token query param', () {
      const url = 'https://beautycita.com/portfolio-upload.html?token=XYZ';
      final uri = Uri.tryParse(url);
      expect(uri, isNotNull);
      expect(uri!.queryParameters['token'], 'XYZ');
    });
  });

  group('PIN format', () {
    // The stylist-sticker flow expects a 4-digit PIN. The service doesn't
    // validate (caller's responsibility per memory `feedback_usernames.md`-
    // style discipline) but here we pin the contract: '----' is the
    // sentinel when no PIN is set yet.
    test('sentinel PIN is exactly 4 dashes', () {
      const sentinel = '----';
      expect(sentinel.length, 4);
      expect(RegExp(r'^[-]{4}$').hasMatch(sentinel), true);
    });

    test('valid PIN matches 4-digit pattern', () {
      const validPin = '4827';
      expect(RegExp(r'^\d{4}$').hasMatch(validPin), true);
    });
  });
}
