import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/map.g.dart',
    dartPackageName: 'glmap',
    kotlinOut: 'android/src/main/kotlin/software/globus/flutter/glmap/Map.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'software.globus.flutter.glmap',
      errorClassName: 'MapApiError',
    ),
    swiftOut: 'ios/glmap/Sources/GlobusMapFlutter/Map.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'MapApiError'),
  ),
)
class MapStateMessage {
  MapStateMessage({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.scale,
    required this.angle,
    required this.pitch,
    required this.originX,
    required this.originY,
  });
  double latitude;
  double longitude;
  double zoom;
  double scale;
  double angle;
  double pitch;
  double originX;
  double originY;
}

class MapCameraMessage {
  MapCameraMessage({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.angle,
    required this.pitch,
  });
  double latitude;
  double longitude;
  double zoom;
  double angle;
  double pitch;
}

enum VectorMutation { replace, style, remove }

enum VectorReply { ready, superseded, cancelled, failed, removed }

class VectorMutationMessage {
  VectorMutationMessage({
    required this.layerId,
    required this.operation,
    this.lonLat,
    this.geoJson,
    this.style,
  });
  int layerId;
  VectorMutation operation;
  Float64List? lonLat;
  String? geoJson;
  String? style;
}

@HostApi()
abstract class MapHostApi {
  // Non-render-aligned diagnostics; captureState is the camera snapshot API.
  Map<String, Object?> diagnostics();
  @async
  MapStateMessage captureState();
  void setCamera(MapCameraMessage camera);
  @asyncCallback
  int createVectorLayer(int drawOrder);
  // Callback mode enters the handler directly on main, preserving acceptance
  // order on this one channel without waiting for earlier preparations.
  @asyncCallback
  VectorReply mutateVectorLayer(VectorMutationMessage mutation);
  @asyncCallback
  String? pickVectorFeature(int layerId, double x, double y, double tolerance);
  void dispose();
}
