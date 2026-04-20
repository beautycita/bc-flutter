// @anchor-test: auto-generated compile-anchor test by tools/scaffold_tests.py.
// Pins module import + primary-symbol existence. Replace with real behavior
// tests when the target gains non-trivial logic. The @anchor-test marker
// lets a future sweep list all scaffolded tests for upgrade.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_web/widgets/invite/salon_list_panel.dart';

void main() {
  test('SalonListPanel symbol exists', () {
    // Compile-time anchor. If SalonListPanel is renamed/removed this fails to compile.
    expect(SalonListPanel, isNotNull);
  });
}
