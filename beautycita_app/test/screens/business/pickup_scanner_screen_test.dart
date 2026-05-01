// @anchor-test: auto-generated compile-anchor test by tools/scaffold_tests.py.
// Pins module import + primary-symbol existence. Replace with real behavior
// tests when the target gains non-trivial logic. The @anchor-test marker
// lets a future sweep list all scaffolded tests for upgrade.

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/screens/business/pickup_scanner_screen.dart';

void main() {
  test('PickupScannerScreen symbol exists', () {
    // Compile-time anchor. If PickupScannerScreen is renamed/removed this fails to compile.
    expect(PickupScannerScreen, isNotNull);
  });
}
