// @anchor-test: auto-generated compile-anchor test by tools/scaffold_tests.py.
// Pins module import + primary-symbol existence. Replace with real behavior
// tests when the target gains non-trivial logic. The @anchor-test marker
// lets a future sweep list all scaffolded tests for upgrade.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_web/pages/public/porque_cinema.dart';

void main() {
  test('PorQueCinemaPage symbol exists', () {
    // Compile-time anchor. If PorQueCinemaPage is renamed/removed this fails to compile.
    expect(PorQueCinemaPage, isNotNull);
  });
}
