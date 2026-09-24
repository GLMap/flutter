import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/features.g.dart',
    kotlinOut:
        'android/src/main/kotlin/software/globus/lab/glmap_lab/Features.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'software.globus.lab.glmap_lab',
      errorClassName: 'FeatureError',
    ),
    swiftOut: 'ios/glmap_flutter/Sources/glmap_flutter/Features.g.swift',
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

class PlaceMessage {
  PlaceMessage({required this.name, required this.detail, required this.point});
  String name;
  String detail;
  GeoMessage point;
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

class RegionMessage {
  RegionMessage({
    required this.id,
    required this.name,
    required this.collection,
    required this.downloadedMask,
    required this.downloadingMask,
    required this.size,
    required this.localSize,
  });
  int id;
  String name;
  bool collection;
  int downloadedMask;
  int downloadingMask;
  int size;
  int localSize;
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
abstract class SdkHostApi {
  void initialize(String apiKey);
  void addAssetDataSet(String asset, int dataSet);
  @asyncCallback
  List<RegionMessage> regions(int? parent, bool refresh);
  void downloadRegion(int id, int mask);
  void cancelRegionDownload(int id);
  void deleteRegion(int id, int mask);
  @asyncCallback
  void downloadArea(int requestId, BoundsMessage bounds, int mask);
  @asyncCallback
  List<PlaceMessage> search(
    int requestId,
    String text,
    bool offline,
    bool autocomplete,
    GeoMessage center,
    List<String> categories,
  );
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

@FlutterApi()
abstract class SdkEventsApi {
  void downloadProgress(
    int id,
    int dataSet,
    int downloaded,
    int total,
    String? error,
    bool finished,
    bool area,
  );
}

@HostApi()
abstract class MapFeaturesHostApi {
  void setStyleOptions(Map<String, String> options, String? assetDirectory);
  void setTerrain(
    double altitudeScale,
    bool hillshades,
    bool contours,
    bool slopes,
  );
  void setOnlineTiles(bool enabled);
  void setRasterSource(String? urlTemplate, String attribution);
  void animateCamera(GeoMessage center, double zoom, double duration, bool fly);
  void fitBounds(BoundsMessage bounds);
  void setImage(int id, GeoMessage point, Uint8List png);
  void setImageGroup(int id, List<GeoMessage> points, Uint8List png);
  void setMarkers(
    int id,
    String geoJson,
    Uint8List png,
    double clusteringRadius,
  );
  void setBalloon(int id, GeoMessage point, String text);
  void setTrack(int id, Float64List lonLat, double progress, bool arrows);
  void setRouteTrack(int id, int routeId, double progress);
  void removeObject(int id);
  @asyncCallback
  PlaceMessage? pickObject(double x, double y);
  @asyncCallback
  Float64List project(List<GeoMessage> points);
}

@FlutterApi()
abstract class MapEventsApi {
  void tap(GeoMessage point, double x, double y, bool longPress);
}
