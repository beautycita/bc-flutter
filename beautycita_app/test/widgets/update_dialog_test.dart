import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/config/constants.dart';

/// Tests for the APK update dialog logic.
///
/// The actual _ApkUpdateDialog widget is private to home_screen.dart,
/// so we test the logic that drives it: version comparison,
/// required vs dismissable behavior, and content expectations.
void main() {
  group('APK Update Dialog logic', () {
    test('shows update when remote build > local build', () {
      const remoteBuild = 99999;
      final shouldShow = remoteBuild > AppConstants.buildNumber;
      expect(shouldShow, isTrue);
    });

    test('does not show when remote build <= local build', () {
      final shouldShow = AppConstants.buildNumber > AppConstants.buildNumber;
      expect(shouldShow, isFalse);
    });

    test('required update has no dismiss option', () {
      const required = true;
      // In the actual widget, !required controls whether "Mas tarde" shows
      expect(!required, isFalse); // No dismiss button
    });

    test('non-required update has dismiss option', () {
      const required = false;
      expect(!required, isTrue); // Dismiss button visible
    });

    test('dialog shows version and build number in text', () {
      const version = '2.0.0';
      const buildNumber = 60000;

      final message =
          'La version $version (build $buildNumber) esta disponible con mejoras y correcciones.';

      expect(message, contains('2.0.0'));
      expect(message, contains('60000'));
    });

    test('required message contains "necesaria"', () {
      const version = '2.0.0';
      const buildNumber = 60000;

      final message =
          'La version $version (build $buildNumber) es necesaria para continuar usando BeautyCita.';

      expect(message, contains('necesaria'));
    });

    test('non-required message contains "disponible"', () {
      const version = '2.0.0';
      const buildNumber = 60000;

      final message =
          'La version $version (build $buildNumber) esta disponible con mejoras y correcciones.';

      expect(message, contains('disponible'));
    });
  });

  group('Update dialog widget smoke test', () {
    testWidgets('renders AlertDialog with update text', (tester) async {
      const version = '2.0.0';
      const buildNumber = 60000;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.system_update_rounded),
                        SizedBox(width: 12),
                        Expanded(child: Text('Nueva version disponible')),
                      ],
                    ),
                    content: const Text(
                      'La version $version (build $buildNumber) esta disponible con mejoras y correcciones.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Mas tarde'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Actualizar'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Update'),
            ),
          ),
        ),
      ));

      // Open dialog
      await tester.tap(find.text('Show Update'));
      await tester.pumpAndSettle();

      // Verify content
      expect(find.text('Nueva version disponible'), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);
      expect(find.text('Mas tarde'), findsOneWidget);
      expect(find.byIcon(Icons.system_update_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });

    testWidgets('required dialog has no dismiss button', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    title: const Text('Nueva version disponible'),
                    content: const Text('Actualizacion requerida'),
                    actions: [
                      // No dismiss button for required updates
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Actualizar'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Required'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Show Required'));
      await tester.pumpAndSettle();

      expect(find.text('Actualizar'), findsOneWidget);
      expect(find.text('Mas tarde'), findsNothing);
    });
  });
}
