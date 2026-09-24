import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/search.g.dart',
    dartPackageName: 'glsearch',
    kotlinOut:
        'android/src/main/kotlin/software/globus/flutter/glsearch/Search.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'software.globus.flutter.glsearch',
      errorClassName: 'FeatureError',
    ),
    swiftOut: 'ios/glsearch/Sources/GlobusSearchFlutter/Search.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'FeatureError'),
  ),
)
class GeoMessage {
  GeoMessage({required this.latitude, required this.longitude});
  double latitude;
  double longitude;
}

class PlaceMessage {
  PlaceMessage({required this.name, required this.detail, required this.point});
  String name;
  String detail;
  GeoMessage point;
}

@HostApi()
abstract class SearchHostApi {
  @asyncCallback
  List<PlaceMessage> search(
    int requestId,
    String text,
    bool offline,
    bool autocomplete,
    GeoMessage center,
    List<String> categories,
  );
  void cancelRequest(int requestId);
  @asyncCallback
  PlaceMessage? pickObject(int viewId, double x, double y);
}
