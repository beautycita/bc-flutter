// @anchor-test: auto-generated compile-anchor test by tools/scaffold_tests.py.
// Pins module import + primary-symbol existence. Replace with real behavior
// tests when the target gains non-trivial logic. The @anchor-test marker
// lets a future sweep list all scaffolded tests for upgrade.

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/screens/admin/admin_salones_insights_screen.dart';

void main() {
  test('AdminSalonesInsightsScreen symbol exists', () {
    // Compile-time anchor. If AdminSalonesInsightsScreen is renamed/removed this fails to compile.
    expect(AdminSalonesInsightsScreen, isNotNull);
  });
}
