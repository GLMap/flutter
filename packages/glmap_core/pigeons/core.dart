import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/core.g.dart',
    dartPackageName: 'glmap_core',
    kotlinOut: 'android/src/main/kotlin/software/globus/flutter/core/Core.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'software.globus.flutter.core',
      errorClassName: 'FeatureError',
    ),
    swiftOut: 'ios/glmap_core/Sources/glmap_core/Core.g.swift',
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

@HostApi()
abstract class CoreHostApi {
  void initialize(String apiKey);
  void addAssetDataSet(String asset, int dataSet);
  @asyncCallback
  List<RegionMessage> regions(int? parent, bool refresh);
  void downloadRegion(int id, int mask);
  void cancelRegionDownload(int id);
  void deleteRegion(int id, int mask);
  @asyncCallback
  void downloadArea(int requestId, BoundsMessage bounds, int mask);
  void cancelRequest(int requestId);
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
