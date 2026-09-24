import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glmap_flutter/glmap_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'api_test.dart' as support;

const green = 'line{width:4pt;color:#00AA44;}';
const blue = 'line{width:7pt;color:#2650D6;}';
Matcher code(String value) =>
    isA<PlatformException>().having((e) => e.code, 'code', value);

Future<Map<dynamic, dynamic>> layerState(
  GLMapController map,
  GLMapVectorLayer layer,
) async => ((await map.diagnostics())['vectorLayers'] as List)
    .cast<Map>()
    .singleWhere((row) => row['id'] == layer.id);

GLMapGeometry line(double lon) => GLMapGeometry.line([
  GLMapGeoPoint(latitude: 48, longitude: lon),
  GLMapGeoPoint(latitude: 49, longitude: lon + 1),
]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'vector geometry, retained input, restyle, rejection, clear and remove',
    (tester) async {
      final data = await support.fixture();
      GLMapController? created;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GLMap(fixture: data, onCreated: (value) => created = value),
          ),
        ),
      );
      final map = await support.ready(tester, () => created);
      final layer = await map.createVectorLayer(drawOrder: 3);
      await expectLater(
        layer.setStyle(green),
        throwsA(code('missing_geometry')),
      );
      final json = jsonEncode({
        'type': 'LineString',
        'coordinates': [
          [70, -20],
          [74, -10],
        ],
      });
      expect(
        await layer.replace(GLMapGeometry.geoJson(json), style: green),
        GLMapVectorUpdateResult.ready,
      );
      final initial = await layerState(map, layer);
      expect(initial['objectCount'], 1);
      final bounds = (initial['bounds'] as List).cast<num>();
      // Native map coordinates use a 2^30 world width; catches swapped lat/lon.
      expect(bounds[0], closeTo((70 + 180) / 360 * (1 << 30), 2));
      final source = Float64List.fromList([70, -20, 74, -10]);
      final packed = GLMapGeometry.packedLineLonLat(source);
      source.fillRange(0, source.length, 0);
      expect(
        await layer.replace(packed, style: green),
        GLMapVectorUpdateResult.ready,
      );
      expect((await layerState(map, layer))['bounds'], bounds);
      expect(await layer.setStyle(blue), GLMapVectorUpdateResult.ready);
      expect((await layerState(map, layer))['bounds'], bounds);
      await expectLater(
        layer.replace(GLMapGeometry.geoJson('{not json'), style: green),
        throwsA(code('invalid_geometry')),
      );
      await expectLater(
        layer.replace(line(16), style: 'line { width: }'),
        throwsA(code('invalid_style')),
      );
      expect((await layerState(map, layer))['bounds'], bounds);
      expect(await layer.setStyle(green), GLMapVectorUpdateResult.ready);
      expect(
        () => GLMapGeometry.packedLineLonLat(Float64List.fromList([0, 1, 2])),
        throwsArgumentError,
      );
      expect(
        () => GLMapGeometry.line([
          const GLMapGeoPoint(latitude: 0, longitude: 0),
        ]),
        throwsArgumentError,
      );
      expect(
        () => GLMapGeometry.packedLineLonLat(
          Float64List.fromList([double.nan, 0, 1, 2]),
        ),
        throwsArgumentError,
      );
      expect(
        await layer.replace(line(16), style: blue),
        GLMapVectorUpdateResult.ready,
      );
      expect((await layerState(map, layer))['bounds'], isNot(bounds));
      final large = Float64List(20000);
      for (var i = 0; i < 10000; i++) {
        large[2 * i] = 16 + i * .0001;
        large[2 * i + 1] = 48 + (i % 2) * .001;
      }
      expect(
        await layer.replace(GLMapGeometry.packedLineLonLat(large), style: blue),
        GLMapVectorUpdateResult.ready,
      );
      expect(await layer.setStyle(green), GLMapVectorUpdateResult.ready);
      expect(
        await layer.replace(GLMapGeometry.line([]), style: green),
        GLMapVectorUpdateResult.ready,
      );
      expect((await layerState(map, layer))['objectCount'], 0);
      await layer.remove();
      await layer.remove();
      expect((await map.diagnostics())['vectorLayers'], isEmpty);
      await expectLater(layer.setStyle(green), throwsA(code('layer_removed')));
      await expectLater(
        layer.replace(line(16), style: green),
        throwsA(code('layer_removed')),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ordered overlapping vector updates and removal on two maps', (
    tester,
  ) async {
    final data = await support.fixture();
    final visible = ValueNotifier(true);
    GLMapController? first, second;
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
                          onCreated: (v) => first = v,
                        )
                      : const SizedBox(),
                ),
                Expanded(
                  child: GLMap(
                    key: const ValueKey('second'),
                    fixture: data,
                    onCreated: (v) => second = v,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final a = await support.ready(tester, () => first);
    final b = await support.ready(tester, () => second);
    final layerA = await a.createVectorLayer();
    final layerB = await b.createVectorLayer();
    // IDs can coincide; channel suffix and ownership must keep the maps separate.
    expect(layerA.id, layerB.id);
    expect(
      await layerB.replace(line(140), style: blue),
      GLMapVectorUpdateResult.ready,
    );
    final bBounds = (await layerState(b, layerB))['bounds'];
    final updates = <Future<GLMapVectorUpdateResult>>[];
    for (var i = 0; i < 30; i++) {
      updates.add(layerA.replace(line(i.toDouble()), style: green));
      updates.add(layerA.setStyle(blue));
    }
    final outcomes = await Future.wait(updates)
        .timeout(const Duration(seconds: 20));
    expect(outcomes.last, GLMapVectorUpdateResult.ready);
    for (final result in outcomes) {
      expect(
        result,
        anyOf(
          GLMapVectorUpdateResult.ready,
          GLMapVectorUpdateResult.superseded,
        ),
      );
    }
    debugPrint(
      'Vector burst: ready=${outcomes.where((r) => r == GLMapVectorUpdateResult.ready).length}, superseded=${outcomes.where((r) => r == GLMapVectorUpdateResult.superseded).length}',
    );
    final finalBounds = ((await layerState(a, layerA))['bounds'] as List)
        .cast<num>();
    expect(finalBounds[0], closeTo((29 + 180) / 360 * (1 << 30), 2));
    expect((await layerState(b, layerB))['bounds'], bBounds);

    final pending = List.generate(
      20,
      (i) => layerA.replace(line(i.toDouble()), style: green),
    );
    await layerA.remove();
    final removed = await Future.wait(pending)
        .timeout(const Duration(seconds: 10));
    for (final result in removed) {
      expect(
        result,
        anyOf(
          GLMapVectorUpdateResult.ready,
          GLMapVectorUpdateResult.superseded,
          GLMapVectorUpdateResult.cancelled,
        ),
      );
    }
    debugPrint(
      'Vector removal: cancelled=${removed.where((r) => r == GLMapVectorUpdateResult.cancelled).length}',
    );
    expect((await a.diagnostics())['vectorLayers'], isEmpty);
    expect(await layerB.setStyle(green), GLMapVectorUpdateResult.ready);

    final closing = await a.createVectorLayer();
    final inFlight = List.generate(
      16,
      (_) => closing
          .replace(line(30), style: blue)
          .then<Object>((value) => value, onError: (Object error) => error),
    );
    final creating = List.generate(
      16,
      (_) => a.createVectorLayer().then<Object>(
        (value) => value,
        onError: (Object error) => error,
      ),
    );
    visible.value = false;
    await tester.pumpAndSettle();
    for (final result in await Future.wait(
      inFlight,
    ).timeout(const Duration(seconds: 10))) {
      expect(
        result,
        anyOf(isA<GLMapVectorUpdateResult>(), code('map_disposed')),
      );
    }
    await expectLater(closing.setStyle(green), throwsA(code('map_disposed')));
    for (final result in await Future.wait(
      creating,
    ).timeout(const Duration(seconds: 10))) {
      expect(result, anyOf(isA<GLMapVectorLayer>(), code('map_disposed')));
      if (result is GLMapVectorLayer) {
        await expectLater(
          result.setStyle(green),
          throwsA(code('map_disposed')),
        );
      }
    }
    expect(await layerB.setStyle(blue), GLMapVectorUpdateResult.ready);
    expect((await layerState(b, layerB))['bounds'], bBounds);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    visible.dispose();
    expect(tester.takeException(), isNull);
  });
}
