import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/map.g.dart',
    kotlinOut: 'android/src/main/kotlin/software/globus/lab/glmap_lab/Map.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'software.globus.lab.glmap_lab',
      errorClassName: 'MapApiError',
    ),
    swiftOut: 'ios/glmap_flutter/Sources/glmap_flutter/Map.g.swift',
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
