// @anchor-test: auto-generated compile-anchor test by tools/scaffold_tests.py.
// Pins module import + primary-symbol existence. Replace with real behavior
// tests when the target gains non-trivial logic. The @anchor-test marker
// lets a future sweep list all scaffolded tests for upgrade.

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/screens/business/orders_screen.dart';

void main() {
  test('OrdersScreen symbol exists', () {
    // Compile-time anchor. If OrdersScreen is renamed/removed this fails to compile.
    expect(OrdersScreen, isNotNull);
  });
}
