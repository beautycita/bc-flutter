// @anchor-test: auto-generated compile-anchor test by tools/scaffold_tests.py.
// Pins module import + primary-symbol existence. Replace with real behavior
// tests when the target gains non-trivial logic. The @anchor-test marker
// lets a future sweep list all scaffolded tests for upgrade.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_web/widgets/invite/salon_card.dart';

void main() {
  test('SalonCard symbol exists', () {
    // Compile-time anchor. If SalonCard is renamed/removed this fails to compile.
    expect(SalonCard, isNotNull);
  });
}
