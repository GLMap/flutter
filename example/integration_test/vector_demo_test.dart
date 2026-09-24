import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:glmap_lab_example/vector_main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Dart layer demo draws on creation, restyles, removes and redraws',
    (tester) async {
      await app.main();
      Future<void> waitFor(String text) async {
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.text(text).evaluate().isNotEmpty) return;
        }
        throw TestFailure('Missing demo status: $text');
      }

      await waitFor('Draw: GLMapVectorUpdateResult.ready');
      await tester.tap(find.text('Restyle'));
      await waitFor('Restyle: GLMapVectorUpdateResult.ready');
      await tester.tap(find.text('Remove'));
      await waitFor('Remove: done');
      final restyle = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Restyle'),
      );
      expect(restyle.onPressed, isNull);
      await tester.tap(find.text('Draw'));
      await waitFor('Draw: GLMapVectorUpdateResult.ready');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
