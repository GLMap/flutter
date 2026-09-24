part of '../glmap_flutter.dart';

void _validateCoordinate(double latitude, double longitude) {
  if (!latitude.isFinite ||
      latitude < -90 ||
      latitude > 90 ||
      !longitude.isFinite ||
      longitude < -180 ||
      longitude > 180) {
    throw ArgumentError('Expected finite WGS84 latitude/longitude');
  }
}

GeoMessage _geo(GLMapGeoPoint p) {
  _validateCoordinate(p.latitude, p.longitude);
  return GeoMessage(latitude: p.latitude, longitude: p.longitude);
}

GLMapGeoPoint _point(GeoMessage p) =>
    GLMapGeoPoint(latitude: p.latitude, longitude: p.longitude);

@immutable
class GLMapBounds {
  const GLMapBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });
  final double south, west, north, east;
  BoundsMessage get _message {
    _validateCoordinate(south, west);
    _validateCoordinate(north, east);
    if (south >= north || west >= east) {
      throw ArgumentError(
        'Bounds must have a positive extent without crossing the antimeridian',
      );
    }
    return BoundsMessage(south: south, west: west, north: north, east: east);
  }

  static GLMapBounds _from(BoundsMessage b) =>
      GLMapBounds(south: b.south, west: b.west, north: b.north, east: b.east);
}

@immutable
class GLMapPlace {
  GLMapPlace._(PlaceMessage value)
    : name = value.name,
      detail = value.detail,
      point = _point(value.point);
  final String name, detail;
  final GLMapGeoPoint point;
}

enum GLMapDataSet { map, navigation, elevation }

class GLMapRequest<T> {
  GLMapRequest._(this.id, this.result);
  final int id;
  final Future<T> result;
  Future<void> cancel() => GLMapSDK._api.cancelRequest(id);
}

@immutable
class GLMapRegion {
  GLMapRegion._(RegionMessage m)
    : id = m.id,
      name = m.name,
      isCollection = m.collection,
      downloadedMask = m.downloadedMask,
      downloadingMask = m.downloadingMask,
      downloadBytes = m.size,
      localBytes = m.localSize;
  final int id, downloadedMask, downloadingMask, downloadBytes, localBytes;
  final String name;
  final bool isCollection;
  Future<void> download({
    Set<GLMapDataSet> dataSets = const {
      GLMapDataSet.map,
      GLMapDataSet.navigation,
      GLMapDataSet.elevation,
    },
  }) => GLMapSDK._api.downloadRegion(id, GLMapSDK._mask(dataSets));
  Future<void> cancelDownload() => GLMapSDK._api.cancelRegionDownload(id);
  Future<void> delete({
    Set<GLMapDataSet> dataSets = const {
      GLMapDataSet.map,
      GLMapDataSet.navigation,
      GLMapDataSet.elevation,
    },
  }) => GLMapSDK._api.deleteRegion(id, GLMapSDK._mask(dataSets));
}

@immutable
class GLMapDownloadProgress {
  const GLMapDownloadProgress(
    this.id,
    this.dataSet,
    this.downloaded,
    this.total,
    this.error,
    this.finished,
    this.area,
  );
  final int id, dataSet, downloaded, total;
  final String? error;
  final bool finished;

  /// True for a downloadArea request; otherwise id is a region ID.
  final bool area;
}

/// Process-wide SDK services. Search and downloads do not require a map widget.
class GLMapSDK {
  static final _api = SdkHostApi();
  static int _nextRequest = 0;
  static final _downloads = StreamController<GLMapDownloadProgress>.broadcast();
  static Stream<GLMapDownloadProgress> get downloads => _downloads.stream;
  static Future<void> initialize({required String apiKey}) async {
    SdkEventsApi.setUp(_SdkEvents());
    await _api.initialize(apiKey);
  }

  static Future<void> addAssetDataSet(String asset, GLMapDataSet type) =>
      _api.addAssetDataSet(asset, type.index);
  static int _mask(Set<GLMapDataSet> values) =>
      values.fold(0, (mask, item) => mask | (1 << item.index));
  static Future<List<GLMapRegion>> regions({
    int? parent,
    bool refresh = false,
  }) async => (await _api.regions(
    parent,
    refresh,
  )).map(GLMapRegion._).toList(growable: false);
  static GLMapRequest<void> downloadArea(
    GLMapBounds bounds, {
    Set<GLMapDataSet> dataSets = const {
      GLMapDataSet.map,
      GLMapDataSet.navigation,
      GLMapDataSet.elevation,
    },
  }) {
    final id = ++_nextRequest;
    return GLMapRequest._(
      id,
      _api.downloadArea(id, bounds._message, _mask(dataSets)),
    );
  }

  static GLMapRequest<List<GLMapPlace>> search(
    String text, {
    required GLMapGeoPoint center,
    bool offline = true,
    bool autocomplete = false,
    List<String> categories = const [],
  }) {
    final id = ++_nextRequest;
    return GLMapRequest._(
      id,
      _api
          .search(id, text, offline, autocomplete, _geo(center), categories)
          .then((items) => items.map(GLMapPlace._).toList(growable: false)),
    );
  }

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
    return GLMapRequest._(
      id,
      _api
          .route(id, _geo(start), _geo(end), mode.name, offline, offlineConfig)
          .then(GLMapRoute._),
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

class GLMapRoute {
  GLMapRoute._(RouteMessage value)
    : id = value.id,
      distance = value.distance,
      duration = value.duration,
      bounds = GLMapBounds._from(value.bounds),
      lonLat = value.lonLat.asUnmodifiableView();
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
      await GLMapSDK._api.updateNavigation(id, _geo(point), bearing),
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await GLMapSDK._api.releaseRoute(id);
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

@immutable
class GLMapTap {
  const GLMapTap(this.point, this.screenPoint, this.longPress);
  final GLMapGeoPoint point;
  final Offset screenPoint;
  final bool longPress;
}

class _MapEvents extends MapEventsApi {
  _MapEvents(this.events);
  final StreamController<GLMapTap> events;
  @override
  void tap(GeoMessage point, double x, double y, bool longPress) {
    if (!events.isClosed) {
      events.add(GLMapTap(_point(point), Offset(x, y), longPress));
    }
  }
}

class _SdkEvents extends SdkEventsApi {
  @override
  void downloadProgress(
    int id,
    int dataSet,
    int downloaded,
    int total,
    String? error,
    bool finished,
    bool area,
  ) => GLMapSDK._downloads.add(
    GLMapDownloadProgress(
      id,
      dataSet,
      downloaded,
      total,
      error,
      finished,
      area,
    ),
  );
}

/// Each drawing ID is scoped to this map. Reusing an ID replaces that object.
extension GLMapFeatures on GLMapController {
  Future<void> setStyleOptions(
    Map<String, String> options, {
    String? assetDirectory,
  }) => _invoke(() => _features.setStyleOptions(options, assetDirectory));
  Future<void> setTerrain({
    double altitudeScale = 1,
    bool hillshades = true,
    bool contours = true,
    bool slopes = false,
  }) => _invoke(
    () => _features.setTerrain(altitudeScale, hillshades, contours, slopes),
  );
  Future<void> setOnlineTiles(bool enabled) =>
      _invoke(() => _features.setOnlineTiles(enabled));

  /// Set an XYZ raster source, or pass null to restore GLMap vector tiles.
  Future<void> setRasterSource(
    String? urlTemplate, {
    String attribution = '',
  }) => _invoke(() => _features.setRasterSource(urlTemplate, attribution));
  Future<void> animateCamera({
    required GLMapGeoPoint center,
    required double zoom,
    double duration = 1.5,
    bool fly = true,
  }) =>
      _invoke(() => _features.animateCamera(_geo(center), zoom, duration, fly));
  Future<void> fitBounds(GLMapBounds bounds) =>
      _invoke(() => _features.fitBounds(bounds._message));

  /// Creates a map-owned handle. The first set() supplies its content.
  GLMapImage createImage() => GLMapImage._(this, ++_nextDrawableId);
  GLMapImageGroup createImageGroup() =>
      GLMapImageGroup._(this, ++_nextDrawableId);
  GLMapMarkers createMarkers() => GLMapMarkers._(this, ++_nextDrawableId);
  GLMapBalloon createBalloon() => GLMapBalloon._(this, ++_nextDrawableId);
  GLMapTrack createTrack() => GLMapTrack._(this, ++_nextDrawableId);

  Future<GLMapPlace?> pickObject(Offset point) => _invoke(() async {
    final hit = await _features.pickObject(point.dx, point.dy);
    return hit == null ? null : GLMapPlace._(hit);
  });
  Future<List<Offset>> project(List<GLMapGeoPoint> points) => _invoke(() async {
    final values = await _features.project(points.map(_geo).toList());
    return [
      for (var i = 0; i < values.length; i += 2)
        Offset(values[i], values[i + 1]),
    ];
  });
}

/// Owned by one map. Removing the handle prevents further updates; map disposal invalidates it too.
abstract class GLMapDrawable {
  GLMapDrawable._(this._map, this._id) {
    if (_map._disposed) throw GLMapController._disposedError();
  }
  final GLMapController _map;
  final int _id;
  Future<void>? _removal;

  Future<void> _update(Future<void> Function() operation) {
    if (_removal != null) {
      return Future.error(
        PlatformException(
          code: 'object_removed',
          message: 'The drawable has been removed.',
        ),
      );
    }
    return _map._invoke(operation);
  }

  Future<void> remove() =>
      _removal ??= _map._invoke(() => _map._features.removeObject(_id));
}

class GLMapImage extends GLMapDrawable {
  GLMapImage._(super.map, super.id) : super._();
  Future<void> set(GLMapGeoPoint point, Uint8List png) =>
      _update(() => _map._features.setImage(_id, _geo(point), png));
}

class GLMapImageGroup extends GLMapDrawable {
  GLMapImageGroup._(super.map, super.id) : super._();
  Future<void> set(List<GLMapGeoPoint> points, Uint8List png) => _update(
    () => _map._features.setImageGroup(_id, points.map(_geo).toList(), png),
  );
}

class GLMapMarkers extends GLMapDrawable {
  GLMapMarkers._(super.map, super.id) : super._();
  Future<void> set(
    String geoJson,
    Uint8List png, {
    double clusteringRadius = 0,
  }) => _update(
    () => _map._features.setMarkers(_id, geoJson, png, clusteringRadius),
  );
}

class GLMapBalloon extends GLMapDrawable {
  GLMapBalloon._(super.map, super.id) : super._();
  Future<void> set(GLMapGeoPoint point, String text) =>
      _update(() => _map._features.setBalloon(_id, _geo(point), text));
}

class GLMapTrack extends GLMapDrawable {
  GLMapTrack._(super.map, super.id) : super._();
  Future<void> setGeometry(
    Float64List lonLat, {
    double progress = 0,
    bool arrows = false,
  }) {
    if (lonLat.length < 4 ||
        lonLat.length.isOdd ||
        !progress.isFinite ||
        progress < 0) {
      throw ArgumentError('Invalid track coordinates or progress');
    }
    for (var i = 0; i < lonLat.length; i += 2) {
      _validateCoordinate(lonLat[i + 1], lonLat[i]);
    }
    return _update(
      () => _map._features.setTrack(_id, lonLat, progress, arrows),
    );
  }

  Future<void> setRoute(GLMapRoute route, {double progress = 0}) =>
      _update(() => _map._features.setRouteTrack(_id, route.id, progress));
}
