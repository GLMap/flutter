import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:glmap_example/lifecycle_main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native map, camera, overlay, navigation and repeated disposal', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final screen = tester.state<app.LifecycleScreenState>(
      find.byType(app.LifecycleScreen),
    );
    Future<Map<String, dynamic>> nativeState() async {
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (screen.controller != null) {
          final state = await screen.controller!.diagnostics();
          if (state['surfaceAvailable'] == true &&
              (state['width'] as num) > 0) {
            return state;
          }
        }
      }
      throw TestFailure('Native map did not attach within five seconds');
    }

    final initial = await nativeState();
    expect(initial['latitude'], closeTo(49, 0.001));
    expect(initial['longitude'], closeTo(16, 0.001));
    expect(initial['zoom'], closeTo(5, 0.001));
    await screen.controller!.setCamera(
      latitude: 48.2082,
      longitude: 16.3738,
      zoom: 6,
    );
    final moved = await screen.controller!.diagnostics();
    expect(moved['latitude'], closeTo(48.2082, 0.001));
    expect(moved['zoom'], closeTo(6, 0.001));

    await tester.enterText(
      find.byKey(const Key('search-field')),
      'Overlay stays interactive',
    );
    expect(find.text('Overlay stays interactive'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('navigate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('back-to-map')));
    await tester.pumpAndSettle();
    expect((await nativeState())['zoom'], closeTo(6, 0.001));

    for (var cycle = 0; cycle < 10; cycle++) {
      final previous = screen.controller!;
      await tester.tap(find.byKey(const Key('toggle-map')));
      await tester.pumpAndSettle();
      expect(screen.controller, isNull);
      final disposed = isA<PlatformException>().having(
        (error) => error.code,
        'code',
        'map_disposed',
      );
      await expectLater(previous.diagnostics(), throwsA(disposed));
      await expectLater(previous.captureState(), throwsA(disposed));
      await tester.tap(find.byKey(const Key('toggle-map')));
      await tester.pumpAndSettle();
      expect((await nativeState())['zoom'], closeTo(5, 0.001));
    }
    expect(tester.takeException(), isNull);
  });
}
