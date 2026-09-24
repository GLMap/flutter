import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glmap/glmap.dart';
import 'package:glsearch/glsearch.dart';
import 'package:glroute/glroute.dart';
import 'package:integration_test/integration_test.dart';

import 'package:glmap_lab_example/demo/common.dart';
import 'package:glmap_lab_example/demo/routing_examples.dart';

// Run online_test.dart with --no-uninstall first. This is a separate process:
// no bundled datasets, catalog refresh or download calls are allowed here.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('restores downloaded data and routes offline after relaunch', (
    tester,
  ) async {
    await GLMapSDK.initialize(
      apiKey: const String.fromEnvironment('GLMAP_API_KEY'),
    );
    final found = await GLSearch.search(
      'Podgorica',
      center: podgorica,
      offline: true,
    ).result.timeout(const Duration(seconds: 30));
    expect(found, isNotEmpty);
    final request = GLRouteSDK.route(
      start: sampleLine.first,
      end: sampleLine.last,
      offline: true,
      offlineConfig: await rootBundle.loadString('assets/valhalla.json'),
    );
    final route = await request.result.timeout(const Duration(seconds: 60));
    try {
      expect(route.distance, inExclusiveRange(1000, 20000));
      final start = await route.updateLocation(
        GLMapGeoPoint(latitude: route.lonLat[1], longitude: route.lonLat[0]),
      );
      final end = await route.updateLocation(
        GLMapGeoPoint(
          latitude: route.lonLat.last,
          longitude: route.lonLat[route.lonLat.length - 2],
        ),
      );
      expect(start.onRoute, isTrue);
      expect(end.progress, greaterThan(start.progress));
      expect(end.remainingDistance, lessThan(10));
      debugPrint(
        'OFFLINE_RELAUNCH_PASS places=${found.length} distance=${route.distance} progress=${start.progress}/${end.progress}',
      );
    } finally {
      await route.close();
    }

    Future<void> settle() async {
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (i > 10 && find.byType(LinearProgressIndicator).evaluate().isEmpty) {
          return;
        }
      }
      throw TestFailure('Demo operation did not finish');
    }

    // Exercise the actual route demo controls against the restored data.
    await tester.pumpWidget(const MaterialApp(home: RouteBuildingDemo()));
    await settle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Build route'));
    await settle();
    expect(find.text('3.56 km · 8 min'), findsOneWidget);

    const screenshots = bool.fromEnvironment('DEMO_SCREENSHOTS');
    if (screenshots) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
      }
      await binding.takeScreenshot(
        '${defaultTargetPlatform.name}-offline-road-route',
      );
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    GLMapController? map;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Downloaded terrain · offline')),
          body: GLMap(
            initialCenter: const GLMapGeoPoint(
              latitude: 42.446,
              longitude: 19.271,
            ),
            initialZoom: 15,
            onCreated: (controller) => map = controller,
          ),
        ),
      ),
    );
    for (var i = 0; i < 100 && map == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(map, isNotNull);
    await map!.setOnlineTiles(false);
    await map!.setCamera(
      latitude: 42.446,
      longitude: 19.271,
      zoom: 15,
      pitch: 45,
    );
    await map!.setTerrain(altitudeScale: 0, hillshades: false, contours: false);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await map!.captureState();
    if (screenshots) {
      await binding.takeScreenshot(
        '${defaultTargetPlatform.name}-offline-terrain-flat',
      );
    }
    await map!.setTerrain(altitudeScale: 3);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (screenshots) {
      await binding.takeScreenshot(
        '${defaultTargetPlatform.name}-offline-terrain',
      );
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    debugPrint('OFFLINE_DEMO_ROUTE_AND_TERRAIN_PASS');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
