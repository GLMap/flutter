import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:glmap/glmap.dart';
import 'package:glroute/glroute.dart';

import 'common.dart';

class RouteBuildingDemo extends StatefulWidget {
  const RouteBuildingDemo({super.key});
  @override
  State<RouteBuildingDemo> createState() => _RouteBuildingDemoState();
}

class _RouteBuildingDemoState extends MapDemoState<RouteBuildingDemo> {
  GLMapImageGroup? imageGroup;
  GLMapTrack? track;

  GLMapGeoPoint start = sampleLine.first, end = sampleLine.last;
  GLMapRouteMode mode = GLMapRouteMode.car;
  bool offline = false;
  GLMapRequest<GLMapRoute>? request;
  GLMapRoute? route;
  int generation = 0;
  @override
  String get title => 'Route Building';
  @override
  String get api => 'GLRouteRequest · online/offline · travel mode';
  @override
  Future<void> ready(GLMapController controller) async {
    await (imageGroup ??= controller.createImageGroup()).set([
      start,
      end,
    ], await pinImage());
    message('Tap for destination · long press for start');
  }

  @override
  Future<void> tapped(GLMapTap tap) async {
    if (tap.longPress) {
      start = tap.point;
    } else {
      end = tap.point;
    }
    await (imageGroup ??= map!.createImageGroup()).set([
      start,
      end,
    ], await pinImage());
  }

  Future<void> calculate() async {
    final token = ++generation;
    await request?.cancel();
    final pending = GLRouteSDK.route(
      start: start,
      end: end,
      mode: mode,
      offline: offline,
      offlineConfig: offline
          ? await rootBundle.loadString('assets/valhalla.json')
          : null,
    );
    request = pending;
    final next = await pending.result;
    if (!mounted || token != generation) {
      await next.close();
      return;
    }
    final old = route;
    route = next;
    await (track ??= map!.createTrack()).setRoute(next);
    await map!.fitBounds(next.bounds);
    await old?.close();
    message(
      '${(next.distance / 1000).toStringAsFixed(2)} km · ${(next.duration / 60).toStringAsFixed(0)} min',
    );
  }

  @override
  Widget controls() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: DropdownButton<GLMapRouteMode>(
              value: mode,
              isExpanded: true,
              items: [
                for (final m in GLMapRouteMode.values)
                  DropdownMenuItem(value: m, child: Text(m.name)),
              ],
              onChanged: (v) => setState(() => mode = v!),
            ),
          ),
          const Text('Offline'),
          Switch(value: offline, onChanged: (v) => setState(() => offline = v)),
        ],
      ),
      Wrap(
        spacing: 8,
        children: [
          button('Build route', calculate),
          OutlinedButton(
            onPressed: request == null ? null : () => request!.cancel(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      if (offline)
        const Text(
          'Download navigation data for this region first.',
          style: TextStyle(fontSize: 12),
        ),
    ],
  );
  @override
  void dispose() {
    generation++;
    request?.cancel();
    route?.close();
    super.dispose();
  }
}

class TurnByTurnDemo extends StatefulWidget {
  const TurnByTurnDemo({super.key});
  @override
  State<TurnByTurnDemo> createState() => _TurnByTurnDemoState();
}

class _TurnByTurnDemoState extends MapDemoState<TurnByTurnDemo> {
  GLMapTrack? track;
  GLMapImage? positionImage;

  GLMapRoute? route;
  GLMapRequest<GLMapRoute>? request;
  StreamSubscription<Position>? gps;
  Uint8List? pin;
  GLMapGeoPoint current = sampleLine.first;
  int replayIndex = 0, generation = 0;
  bool updating = false;
  GLMapNavigationState? navigation;
  @override
  String get title => 'Turn-by-Turn Navigation';
  @override
  String get api => 'GLRouteTracker · maneuvers · route progress';
  @override
  Future<void> ready(GLMapController controller) async {
    pin = await pinImage(Colors.teal);
    await sampleRoute();
  }

  Future<void> install(GLMapRoute next) async {
    if (!mounted) {
      await next.close();
      return;
    }
    final old = route;
    route = next;
    replayIndex = 0;
    navigation = null;
    await (track ??= map!.createTrack()).setRoute(next);
    await map!.fitBounds(next.bounds);
    await old?.close();
  }

  Future<void> sampleRoute() async {
    generation++;
    await request?.cancel();
    // A custom route makes the tracker reproducible without a network request.
    final next = await GLRouteSDK.buildRoute([
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
    await install(next);
    message('Sample route · Next position replays its geometry');
  }

  @override
  Future<void> tapped(GLMapTap tap) async {
    final token = ++generation;
    await request?.cancel();
    request = GLRouteSDK.route(start: current, end: tap.point);
    final next = await request!.result;
    if (!mounted || token != generation) {
      await next.close();
      return;
    }
    await install(next);
    message('Route ready · use GPS or replay positions');
  }

  Future<void> update(
    GLMapGeoPoint point, {
    double bearing = double.nan,
  }) async {
    final target = route;
    if (target == null || updating) return;
    updating = true;
    try {
      current = point;
      final state = await target.updateLocation(point, bearing: bearing);
      if (!mounted || target != route) return;
      setState(() => navigation = state);
      await (positionImage ??= map!.createImage()).set(
        state.onRoute ? state.point : point,
        pin!,
      );
      await (track ??= map!.createTrack()).setRoute(
        target,
        progress: state.progress,
      );
      await map!.animateCamera(
        center: state.onRoute ? state.point : point,
        zoom: 15,
        duration: 0.5,
        fly: false,
      );
      message(state.onRoute ? 'On route' : 'Off route');
    } finally {
      updating = false;
    }
  }

  Future<void> nextPosition() async {
    final coords = route!.lonLat;
    if (replayIndex >= coords.length) replayIndex = 0;
    final p = GLMapGeoPoint(
      latitude: coords[replayIndex + 1],
      longitude: coords[replayIndex],
    );
    replayIndex += 2;
    await update(p);
  }

  Future<void> useGps() async {
    await gps?.cancel();
    final positions = await foregroundPositions();
    if (!mounted) return;
    gps = positions.listen(
      (p) => run(
        () => update(
          GLMapGeoPoint(latitude: p.latitude, longitude: p.longitude),
          bearing: p.heading,
        ),
      ),
      onError: (Object error) => message(describeError(error)),
    );
    message('GPS active · tap map to choose destination');
  }

  @override
  Widget controls() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (navigation case final n?) ...[
        Text(n.instruction, style: Theme.of(context).textTheme.titleMedium),
        Text(
          '${n.distanceToManeuver.toStringAsFixed(0)} m to maneuver · ${n.remainingDistance.toStringAsFixed(0)} m remaining',
        ),
      ],
      Wrap(
        spacing: 8,
        children: [
          button('Next position', nextPosition),
          button('Use GPS', useGps),
          button('Sample route', sampleRoute),
          button('Stop GPS', () async {
            await gps?.cancel();
            gps = null;
            message('GPS stopped');
          }),
        ],
      ),
    ],
  );
  @override
  void dispose() {
    generation++;
    gps?.cancel();
    request?.cancel();
    route?.close();
    super.dispose();
  }
}
