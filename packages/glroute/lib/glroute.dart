import 'package:flutter/foundation.dart';
import 'package:glmap_core/glmap_core.dart';

import 'src/route.g.dart';

export 'package:glmap_core/glmap_core.dart';

void _validateCoordinate(double lat, double lon) =>
    GLMapGeoPoint(latitude: lat, longitude: lon).validate();
GeoMessage _geo(GLMapGeoPoint p) {
  p.validate();
  return GeoMessage(latitude: p.latitude, longitude: p.longitude);
}

GLMapGeoPoint _point(GeoMessage p) =>
    GLMapGeoPoint(latitude: p.latitude, longitude: p.longitude);

class GLRouteSDK {
  static final _api = RouteHostApi();
  static int _nextRequest = 0;

  /// Builds a custom route with the SDK's GLRouteBuilder. No road routing is performed.
  static Future<GLMapRoute> buildRoute(List<GLMapRouteStep> steps) async {
    if (steps.isEmpty) throw ArgumentError('A route needs at least one step');
    for (final step in steps) {
      if (step.points.length < 2 ||
          !step.duration.isFinite ||
          step.duration < 0) {
        throw ArgumentError(
          'Each step needs two points and a nonnegative duration',
        );
      }
      for (final p in step.points) {
        _validateCoordinate(p.latitude, p.longitude);
      }
    }
    return GLMapRoute._(
      await _api.buildRoute(
        steps
            .map(
              (s) => RouteStepMessage(
                lonLat: Float64List.fromList([
                  for (final p in s.points) ...[p.longitude, p.latitude],
                ]),
                instruction: s.instruction,
                turn: s.turn.index,
                duration: s.duration,
              ),
            )
            .toList(),
      ),
    );
  }

  static GLMapRequest<GLMapRoute> route({
    required GLMapGeoPoint start,
    required GLMapGeoPoint end,
    GLMapRouteMode mode = GLMapRouteMode.car,
    bool offline = false,
    String? offlineConfig,
  }) {
    if (offline && offlineConfig == null) {
      throw ArgumentError('Offline routing requires a Valhalla configuration');
    }
    final id = ++_nextRequest;
    return GLMapRequest(
      id,
      _api
          .route(id, _geo(start), _geo(end), mode.name, offline, offlineConfig)
          .then(GLMapRoute._),
      () => _api.cancelRequest(id),
    );
  }
}

enum GLMapTurn { straight, right, left }

@immutable
class GLMapRouteStep {
  const GLMapRouteStep({
    required this.points,
    required this.instruction,
    this.turn = GLMapTurn.straight,
    required this.duration,
  });
  final List<GLMapGeoPoint> points;
  final String instruction;
  final GLMapTurn turn;
  final double duration;
}

enum GLMapRouteMode { car, bicycle, pedestrian }

class GLMapRoute implements GLMapTrackSource {
  GLMapRoute._(RouteMessage value)
    : id = value.id,
      distance = value.distance,
      duration = value.duration,
      bounds = GLMapBounds(
        south: value.bounds.south,
        west: value.bounds.west,
        north: value.bounds.north,
        east: value.bounds.east,
      ),
      lonLat = value.lonLat.asUnmodifiableView();
  @override
  final int id;
  final double distance, duration;
  final GLMapBounds bounds;
  final Float64List lonLat;
  bool _closed = false;
  Future<GLMapNavigationState> updateLocation(
    GLMapGeoPoint point, {
    double bearing = double.nan,
  }) async {
    if (_closed) throw StateError('Route has been released');
    return GLMapNavigationState._(
      await GLRouteSDK._api.updateNavigation(id, _geo(point), bearing),
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await GLRouteSDK._api.releaseRoute(id);
  }
}

@immutable
class GLMapNavigationState {
  GLMapNavigationState._(NavigationMessage m)
    : instruction = m.instruction,
      distanceToManeuver = m.distanceToManeuver,
      remainingDistance = m.remainingDistance,
      remainingDuration = m.remainingDuration,
      progress = m.progress,
      onRoute = m.onRoute,
      point = _point(m.point);
  final String instruction;
  final double distanceToManeuver,
      remainingDistance,
      remainingDuration,
      progress;
  final bool onRoute;
  final GLMapGeoPoint point;
}
