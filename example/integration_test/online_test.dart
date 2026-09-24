import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glmap_flutter/glmap_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:glmap_lab_example/demo/common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const key = String.fromEnvironment('GLMAP_API_KEY');
    if (key.isEmpty) {
      throw TestFailure(
        'Provide the ignored config/local.json with --dart-define-from-file',
      );
    }
    await GLMapSDK.initialize(apiKey: key);
  });

  testWidgets('authenticated online search and road routes', (tester) async {
    final request = GLMapSDK.search(
      'Podgorica',
      center: podgorica,
      offline: false,
    );
    try {
      final places = await request.result.timeout(const Duration(seconds: 60));
      expect(
        places.any((p) => p.name.toLowerCase().contains('podgorica')),
        isTrue,
      );
      debugPrint('ONLINE_SEARCH_PASS results=${places.length}');
    } finally {
      await request.cancel();
    }
    for (final mode in GLMapRouteMode.values) {
      final request = GLMapSDK.route(
        start: sampleLine.first,
        end: sampleLine.last,
        mode: mode,
      );
      GLMapRoute? route;
      try {
        route = await request.result.timeout(const Duration(seconds: 60));
        expect(route.distance, inExclusiveRange(1000, 20000));
        expect(route.duration, greaterThan(0));
        expect(route.lonLat.length, greaterThan(10));
        final start = GLMapGeoPoint(
          latitude: route.lonLat[1],
          longitude: route.lonLat[0],
        );
        final state = await route.updateLocation(start);
        expect(state.onRoute, isTrue);
        debugPrint(
          'ONLINE_ROUTE_PASS mode=${mode.name} distance=${route.distance} seconds=${route.duration} points=${route.lonLat.length ~/ 2}',
        );
      } finally {
        await request.cancel();
        await route?.close();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('authenticated region catalog', (tester) async {
    final roots = await GLMapSDK.regions(refresh: true)
        .timeout(const Duration(seconds: 60));
    expect(roots, isNotEmpty);
    debugPrint('ONLINE_CATALOG_PASS roots=${roots.length}');
    final collection = roots.firstWhere((r) => r.isCollection);
    expect(await GLMapSDK.regions(parent: collection.id), isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('area cancellation settles without accepting an empty file', (
    tester,
  ) async {
    // Distinct bounds force a fresh network task even after previous runs.
    final delta = DateTime.now().microsecondsSinceEpoch % 1000000 / 1e12;
    final events = <GLMapDownloadProgress>[];
    final subscription = GLMapSDK.downloads.listen(events.add);
    final request = GLMapSDK.downloadArea(
      GLMapBounds(south: 42.42, west: 19.24 + delta, north: 42.45, east: 19.28),
      dataSets: {GLMapDataSet.map},
    );
    final outcome = request.result.then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );
    try {
      await request.cancel();
      final value = await outcome.timeout(const Duration(seconds: 30));
      expect(value, anyOf(isNull, isA<PlatformException>()));
      await tester.pump(const Duration(milliseconds: 100));
      if (value == null) {
        expect(
          events.any(
            (e) =>
                e.area && e.id == request.id && e.finished && e.downloaded > 0,
          ),
          isTrue,
          reason:
              'Successful completion must not register an empty cancelled file',
        );
      }
      debugPrint(
        'AREA_CANCEL_SETTLED ${value == null ? 'completed-before-cancel' : 'cancelled'}',
      );
    } finally {
      await subscription.cancel();
    }
  });

  testWidgets('area download, offline search and road route', (tester) async {
    final events = <GLMapDownloadProgress>[];
    final subscription = GLMapSDK.downloads.listen(events.add);
    final request = GLMapSDK.downloadArea(townBounds);
    try {
      await request.result.timeout(const Duration(minutes: 3));
      await tester.pump(const Duration(milliseconds: 100));
      final own = events.where((e) => e.area && e.id == request.id).toList();
      expect(own.where((e) => e.downloaded > 0), isNotEmpty);
      for (final kind in GLMapDataSet.values) {
        expect(
          own.any(
            (e) => e.dataSet == kind.index && e.finished && e.error == null,
          ),
          isTrue,
          reason: kind.name,
        );
        final totals = own
            .where((e) => e.dataSet == kind.index)
            .map((e) => e.total);
        expect(totals.any((bytes) => bytes > 0), isTrue, reason: kind.name);
        // Reuse of an existing file emits only the finished event.
        final progressEvents = own
            .where((e) => e.dataSet == kind.index && !e.finished)
            .length;
        debugPrint(
          'AREA_DOWNLOAD_PASS dataset=${kind.name} bytes=${totals.fold<int>(0, (a, b) => a > b ? a : b)} progressEvents=$progressEvents',
        );
      }
    } finally {
      await request.cancel();
      await subscription.cancel();
    }
    // A second call must reuse all three completed files without EEXIST.
    await GLMapSDK.downloadArea(townBounds).result
        .timeout(const Duration(seconds: 10));
    final found = await GLMapSDK.search(
      'Podgorica',
      center: podgorica,
    ).result.timeout(const Duration(seconds: 30));
    expect(found, isNotEmpty);
    final pending = GLMapSDK.route(
      start: sampleLine.first,
      end: sampleLine.last,
      offline: true,
      offlineConfig: await rootBundle.loadString('assets/valhalla.json'),
    );
    GLMapRoute? route;
    try {
      route = await pending.result.timeout(const Duration(seconds: 60));
      expect(route.distance, inExclusiveRange(1000, 20000));
      debugPrint(
        'DOWNLOADED_OFFLINE_PASS places=${found.length} distance=${route.distance} points=${route.lonLat.length ~/ 2}',
      );
    } finally {
      await pending.cancel();
      await route?.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('regional map download, progress, state and deletion', (
    tester,
  ) async {
    final roots = await GLMapSDK.regions();
    final region = roots.firstWhere((r) => r.name == 'Monaco');
    // Never delete data already present before this test.
    if (region.downloadedMask & 1 != 0) {
      throw TestFailure(
        'Monaco already downloaded; choose a clean test region',
      );
    }
    final done = Completer<void>();
    var progress = 0;
    final subscription = GLMapSDK.downloads.listen((e) {
      if (e.area || e.id != region.id || e.dataSet != 0) return;
      if (e.downloaded > progress) progress = e.downloaded;
      if (e.finished && !done.isCompleted) {
        if (e.error != null) {
          done.completeError(StateError(e.error!));
        } else {
          done.complete();
        }
      }
    });
    try {
      await Future.wait([
        region.download(dataSets: {GLMapDataSet.map}),
        done.future.timeout(const Duration(minutes: 3)),
      ]);
      final downloaded = (await GLMapSDK.regions()).firstWhere(
        (r) => r.id == region.id,
      );
      expect(downloaded.downloadedMask & 1, 1);
      expect(downloaded.localBytes, greaterThan(0));
      expect(progress, greaterThan(0));
      debugPrint(
        'REGION_DOWNLOAD_PASS name=${region.name} bytes=${downloaded.localBytes} progress=$progress',
      );
    } finally {
      await region.cancelDownload();
      await subscription.cancel();
      await region.delete(dataSets: {GLMapDataSet.map});
    }
    final deleted = (await GLMapSDK.regions()).firstWhere(
      (r) => r.id == region.id,
    );
    expect(deleted.downloadedMask & 1, 0);
    debugPrint('REGION_DELETE_PASS name=${region.name}');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
