import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/route.g.dart',
    dartPackageName: 'glroute',
    kotlinOut:
        'android/src/main/kotlin/software/globus/flutter/glroute/Route.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'software.globus.flutter.glroute',
      errorClassName: 'FeatureError',
    ),
    swiftOut: 'ios/glroute/Sources/GlobusRouteFlutter/Route.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'FeatureError'),
  ),
)
class GeoMessage {
  GeoMessage({required this.latitude, required this.longitude});
  double latitude;
  double longitude;
}

class BoundsMessage {
  BoundsMessage({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
  double south;
  double west;
  double north;
  double east;
}

class RouteMessage {
  RouteMessage({
    required this.id,
    required this.distance,
    required this.duration,
    required this.bounds,
    required this.lonLat,
  });
  int id;
  double distance;
  double duration;
  BoundsMessage bounds;
  Float64List lonLat;
}

class NavigationMessage {
  NavigationMessage({
    required this.instruction,
    required this.distanceToManeuver,
    required this.remainingDistance,
    required this.remainingDuration,
    required this.progress,
    required this.onRoute,
    required this.point,
  });
  String instruction;
  double distanceToManeuver;
  double remainingDistance;
  double remainingDuration;
  double progress;
  bool onRoute;
  GeoMessage point;
}

class RouteStepMessage {
  RouteStepMessage({
    required this.lonLat,
    required this.instruction,
    required this.turn,
    required this.duration,
  });
  Float64List lonLat;
  String instruction;
  int turn;
  double duration;
}

@HostApi()
abstract class RouteHostApi {
  @asyncCallback
  RouteMessage route(
    int requestId,
    GeoMessage start,
    GeoMessage end,
    String mode,
    bool offline,
    String? offlineConfig,
  );
  void cancelRequest(int requestId);
  NavigationMessage updateNavigation(
    int routeId,
    GeoMessage point,
    double bearing,
  );
  void releaseRoute(int routeId);
  RouteMessage buildRoute(List<RouteStepMessage> steps);
}
