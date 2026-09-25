import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glmap/glmap.dart';
import 'package:glsearch/glsearch.dart';
import 'package:glroute/glroute.dart';
import 'package:integration_test/integration_test.dart';

import 'package:glmap_example/main.dart' as demo;
import 'package:glmap_example/demo/common.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty && i > 5) {
      return;
    }
  }
  throw TestFailure('Example is still busy after 10 seconds');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled data, offline search, route builder and tracker', (
    tester,
  ) async {
    await GLMapSDK.initialize(
      apiKey: const String.fromEnvironment('GLMAP_API_KEY'),
    );
    await GLMapSDK.addAssetDataSet('assets/Montenegro.vm', GLMapDataSet.map);
    final found = await GLSearch.search(
      'Podgorica',
      center: podgorica,
    ).result.timeout(const Duration(seconds: 20));
    expect(found, isNotEmpty);
    expect(
      found.any((p) => p.name.toLowerCase().contains('podgorica')),
      isTrue,
    );
    // Cancellation may race successful completion, but must always settle.
    final obsolete = GLSearch.search(
      'restaurant',
      center: podgorica,
      autocomplete: true,
    );
    final outcome = obsolete.result.then<Object>(
      (value) => value,
      onError: (Object e) => e,
    );
    await obsolete.cancel();
    expect(
      await outcome.timeout(const Duration(seconds: 10)),
      anyOf(isA<List<GLMapPlace>>(), isA<PlatformException>()),
    );
    final failedRoute = GLRouteSDK.route(
      start: sampleLine.first,
      end: sampleLine.last,
      offline: true,
      offlineConfig: await rootBundle.loadString('assets/valhalla.json'),
    );
    final routeOutcome = failedRoute.result.then<Object>(
      (value) => value,
      onError: (Object e) => e,
    );
    await failedRoute.cancel();
    final cancelled = await routeOutcome.timeout(const Duration(seconds: 10));
    if (cancelled is GLMapRoute) await cancelled.close();
    expect(cancelled, anyOf(isA<GLMapRoute>(), isA<PlatformException>()));
    final route = await GLRouteSDK.buildRoute([
      GLMapRouteStep(
        points: sampleLine.sublist(0, 3),
        instruction: 'Continue to the crossing',
        duration: 120,
      ),
      GLMapRouteStep(
        points: sampleLine.sublist(2),
        instruction: 'Turn right toward the finish',
        turn: GLMapTurn.right,
        duration: 140,
      ),
    ]);
    expect(route.distance, greaterThan(1000));
    expect(route.duration, closeTo(260, 1));
    expect(route.lonLat.length, greaterThanOrEqualTo(10));
    final start = await route.updateLocation(sampleLine.first);
    final middle = await route.updateLocation(sampleLine[2]);
    final finish = await route.updateLocation(sampleLine.last);
    expect(start.onRoute, isTrue);
    expect(middle.progress, greaterThan(start.progress));
    expect(finish.remainingDistance, lessThan(start.remainingDistance));
    expect(finish.remainingDistance, lessThan(10));
    await route.close();
    await expectLater(route.updateLocation(sampleLine.first), throwsStateError);
    debugPrint(
      'DEMO_SERVICES_PASS places=${found.length}, distance=${route.distance}, progress=${start.progress}/${middle.progress}/${finish.progress}',
    );
  });

  testWidgets('native vector hit testing and removed-layer error', (
    tester,
  ) async {
    await GLMapSDK.initialize(apiKey: '');
    GLMapController? map;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GLMap(onCreated: (value) => map = value)),
      ),
    );
    for (var i = 0; i < 100 && map == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(map, isNotNull);
    await tester.pump(const Duration(seconds: 1));
    final layer = await map!.createVectorLayer();
    Map<String, Object> feature(String name) => {
      'type': 'Feature',
      'properties': {'name': name},
      'geometry': {
        'type': 'Polygon',
        'coordinates': [
          [
            [19.25, 42.43],
            [19.27, 42.43],
            [19.27, 42.44],
            [19.25, 42.44],
            [19.25, 42.43],
          ],
        ],
      },
    };
    final projected = await map!.project([podgorica]);
    // Both polygons contain the tap. Input order must choose the same hit on iOS and Android.
    for (final names in [
      ['First block', 'Second block'],
      ['Second block', 'First block'],
    ]) {
      await layer.replace(
        GLMapGeometry.geoJson(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': names.map(feature).toList(),
          }),
        ),
        style: 'area{fill-color:#2764E180;}',
      );
      final hit = await layer.pickFeature(projected.single);
      expect(hit, isNotNull);
      expect(jsonDecode(hit!)['properties']['name'], names.first);
    }
    await layer.remove();
    await expectLater(
      layer.pickFeature(projected.single),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'layer_removed'),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'drawable handles own updates and reject use after removal or unmount',
    (tester) async {
      await GLMapSDK.initialize(apiKey: '');
      GLMapController? map;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GLMap(onCreated: (value) => map = value)),
        ),
      );
      for (var i = 0; i < 100 && map == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(map, isNotNull);
      final png = await pinImage();
      final image = map!.createImage();
      final second = map!.createImage();
      final track = map!.createTrack();
      await image.set(podgorica, png);
      await second.set(sampleLine.first, png);
      await track.setGeometry(packed(sampleLine));
      await image.remove();
      await image.remove();
      await expectLater(
        image.set(podgorica, png),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'object_removed',
          ),
        ),
      );
      // Removing one image must leave another independent handle usable.
      await second.set(sampleLine.last, png);
      await track.remove();
      await expectLater(
        track.setGeometry(packed(sampleLine)),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'object_removed',
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await expectLater(
        second.set(podgorica, png),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'map_disposed',
          ),
        ),
      );
    },
  );

  testWidgets('all 20 examples open, perform their offline actions and close', (
    tester,
  ) async {
    await tester.pumpWidget(const demo.DemoApp());
    await tester.pumpAndSettle();
    const screenshots = bool.fromEnvironment('DEMO_SCREENSHOTS');
    if (screenshots) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      await binding.takeScreenshot('${defaultTargetPlatform.name}-catalog');
    }
    final actions = <String, List<String>>{
      'Online Map': ['OSM Raster', 'GLMap Vector'],
      'Dark Theme': ['Use light theme', 'Use dark theme'],
      'Fly To': ['Fly to Kotor', 'Fly to Podgorica'],
      'Zoom to BBox': ['Fit Podgorica', 'Fit Montenegro', 'Read camera'],
      'Image': ['Reset pin'],
      'Image Group': ['Reset group'],
      'Balloon': ['Show first landmark'],
      'Lines & Polygons': ['Change style'],
      'GeoJSON': ['Remove layer', 'Load GeoJSON'],
      'User Location': ['Next sample', 'Stop'],
      'GPS Track': ['Next sample', 'Next sample', 'Next sample', 'Stop'],
      'Turn-by-Turn Navigation': [
        'Next position',
        'Next position',
        'Next position',
        'Sample route',
      ],
    };
    for (final entry in demo.demos) {
      await tester.tap(find.byType(TextField).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField).first, entry.title);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(entry.title)));
      await settle(tester);
      expect(find.text(entry.title), findsWidgets);
      for (final action in actions[entry.title] ?? <String>[]) {
        final button = find.text(action);
        expect(button, findsOneWidget, reason: '${entry.title}: $action');
        await tester.tap(button);
        await settle(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.title}: $action',
        );
      }
      if (entry.title == 'Search') {
        expect(find.textContaining('results · offline'), findsOneWidget);
      }
      if (entry.title == 'Turn-by-Turn Navigation') {
        expect(find.textContaining('Sample route ·'), findsOneWidget);
      }
      if (screenshots &&
          [
            'Dark Theme',
            'Markers & Clustering',
            'Balloon',
            'Track Arrows',
            'Lines & Polygons',
            'GeoJSON',
            'Search',
            'Turn-by-Turn Navigation',
          ].contains(entry.title)) {
        await tester.pump(const Duration(seconds: 1));
        await binding.takeScreenshot(
          '${defaultTargetPlatform.name}-${entry.title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-')}',
        );
      }
      debugPrint('DEMO_SCREEN_PASS ${entry.title}');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.title);
    }
  });
}
