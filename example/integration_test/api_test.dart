import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glmap_flutter/glmap_flutter.dart';
import 'package:integration_test/integration_test.dart';

Future<Map<String, dynamic>> fixture() async {
  final data = jsonDecode(
    await rootBundle.loadString('assets/stage-a.json'),
  ) as Map<String, dynamic>;
  data['trackJson'] = jsonEncode(data['track']);
  return data;
}

Future<GLMapController> ready(
  WidgetTester tester,
  GLMapController? Function() controller,
) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final map = controller();
    if (map == null) continue;
    try {
      await map.captureState().timeout(const Duration(seconds: 5));
      return map;
    } on PlatformException catch (error) {
      if (error.code != 'map_unavailable') rethrow;
    }
  }
  throw TestFailure('Native map did not become available');
}

Matcher get disposed =>
    isA<PlatformException>().having((e) => e.code, 'code', 'map_disposed');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'typed state, camera fields, input validation and retained snapshot',
    (tester) async {
      final data = await fixture();
      GLMapController? created;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GLMap(fixture: data, onCreated: (value) => created = value),
          ),
        ),
      );
      final map = await ready(tester, () => created);
      final initial = await map.captureState();
      await map.setCamera(
        latitude: -12.3456,
        longitude: 73.4567,
        zoom: 12,
        angle: 37,
        pitch: 22,
      );
      final state = await map.captureState();
      expect(state.latitude, closeTo(-12.3456, .001));
      expect(state.longitude, closeTo(73.4567, .001));
      expect(state.zoom, closeTo(12, .00001));
      expect(state.scale, closeTo(math.pow(2, state.zoom), .00001));
      expect(state.angle, closeTo(37, .00001));
      expect(state.pitch, closeTo(22, .00001));
      expect(state.originX, inInclusiveRange(0, 1));
      expect(state.originY, inInclusiveRange(0, 1));
      expect(initial.zoom, closeTo(5, .00001));
      expect(initial.longitude, closeTo(16, .05));
      expect(
        () => map.setCamera(latitude: double.nan, longitude: 0, zoom: 12),
        throwsArgumentError,
      );
      expect(
        () => map.setCamera(latitude: 91, longitude: 0, zoom: 12),
        throwsRangeError,
      );
      expect(
        () => map.setCamera(latitude: 0, longitude: 0, zoom: 12, pitch: 46),
        throwsRangeError,
      );
      expect(
        () => map.setCamera(latitude: 0, longitude: 0, zoom: 12, angle: 1e300),
        throwsRangeError,
      );
      expect((await map.captureState()).zoom, state.zoom);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await expectLater(map.captureState(), throwsA(disposed));
      expect(
        state.zoom,
        12,
      ); // A delivered snapshot is independent of widget lifetime.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('two maps, concurrent captures and disposal isolation', (
    tester,
  ) async {
    final data = await fixture();
    final visible = ValueNotifier(true);
    GLMapController? first;
    GLMapController? second;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: visible,
            builder: (_, showFirst, _) => Row(
              children: [
                Expanded(
                  child: showFirst
                      ? GLMap(
                          key: const ValueKey('first'),
                          fixture: data,
                          onCreated: (value) => first = value,
                        )
                      : const SizedBox(),
                ),
                Expanded(
                  child: GLMap(
                    key: const ValueKey('second'),
                    fixture: data,
                    onCreated: (value) => second = value,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final a = await ready(tester, () => first);
    final b = await ready(tester, () => second);
    expect(a.viewId, isNot(b.viewId));
    await a.setCamera(
      latitude: 48.2082,
      longitude: 16.3738,
      zoom: 12,
      angle: 20,
      pitch: 15,
    );
    await b.setCamera(
      latitude: -33.8688,
      longitude: 151.2093,
      zoom: 13,
      angle: 70,
      pitch: 30,
    );
    final results = await Future.wait(
      List.generate(24, (i) => (i.isEven ? a : b).captureState()),
    );
    for (var i = 0; i < results.length; i++) {
      final state = results[i];
      expect(state.latitude, closeTo(i.isEven ? 48.2082 : -33.8688, .001));
      expect(state.longitude, closeTo(i.isEven ? 16.3738 : 151.2093, .001));
      expect(state.zoom, i.isEven ? 12 : 13);
      expect(state.angle, i.isEven ? 20 : 70);
      expect(state.pitch, i.isEven ? 15 : 30);
    }
    // Attach error handlers before removal; each already-running call must settle.
    final pending = List.generate(
      16,
      (_) => a.captureState().then<Object>(
        (value) => value,
        onError: (Object error) => error,
      ),
    );
    visible.value = false;
    await tester.pumpAndSettle();
    final outcomes = await Future.wait(pending)
        .timeout(const Duration(seconds: 5));
    for (final outcome in outcomes) {
      expect(outcome, anyOf(isA<GLMapViewState>(), disposed));
    }
    await expectLater(a.captureState(), throwsA(disposed));
    await expectLater(
      a.setCamera(latitude: 0, longitude: 0, zoom: 12),
      throwsA(disposed),
    );
    expect((await b.captureState()).zoom, 13);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    visible.dispose();
    expect(tester.takeException(), isNull);
  });
}
