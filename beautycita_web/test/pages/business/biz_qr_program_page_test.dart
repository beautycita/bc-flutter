// @anchor-test: auto-generated compile-anchor test by tools/scaffold_tests.py.
// Pins module import + primary-symbol existence. Replace with real behavior
// tests when the target gains non-trivial logic. The @anchor-test marker
// lets a future sweep list all scaffolded tests for upgrade.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_web/pages/business/biz_qr_program_page.dart';

void main() {
  test('BizQrProgramPage symbol exists', () {
    // Compile-time anchor. If BizQrProgramPage is renamed/removed this fails to compile.
    expect(BizQrProgramPage, isNotNull);
  });
}
