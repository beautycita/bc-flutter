// @anchor-test: auto-generated compile-anchor test by tools/scaffold_tests.py.
// Pins module import + primary-symbol existence. Replace with real behavior
// tests when the target gains non-trivial logic. The @anchor-test marker
// lets a future sweep list all scaffolded tests for upgrade.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_web/widgets/bulk_action_bar.dart';

void main() {
  test('BulkActionBar symbol exists', () {
    // Compile-time anchor. If BulkActionBar is renamed/removed this fails to compile.
    expect(BulkActionBar, isNotNull);
  });
}
