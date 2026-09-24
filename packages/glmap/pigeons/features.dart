import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/features.g.dart',
    dartPackageName: 'glmap',
    kotlinOut:
        'android/src/main/kotlin/software/globus/flutter/glmap/Features.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'software.globus.flutter.glmap',
      errorClassName: 'FeatureError',
    ),
    swiftOut: 'ios/glmap/Sources/GlobusMapFlutter/Features.g.swift',
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
  Float64List project(List<GeoMessage> points);
}

@FlutterApi()
abstract class MapEventsApi {
  void tap(GeoMessage point, double x, double y, bool longPress);
}
