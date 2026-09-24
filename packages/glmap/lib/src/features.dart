part of '../glmap.dart';

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
      _invoke(() => _features.fitBounds(_bounds(bounds)));

  /// Creates a map-owned handle. The first set() supplies its content.
  GLMapImage createImage() => GLMapImage._(this, ++_nextDrawableId);
  GLMapImageGroup createImageGroup() =>
      GLMapImageGroup._(this, ++_nextDrawableId);
  GLMapMarkers createMarkers() => GLMapMarkers._(this, ++_nextDrawableId);
  GLMapBalloon createBalloon() => GLMapBalloon._(this, ++_nextDrawableId);
  GLMapTrack createTrack() => GLMapTrack._(this, ++_nextDrawableId);

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

  Future<void> setRoute(GLMapTrackSource route, {double progress = 0}) =>
      _update(() => _map._features.setRouteTrack(_id, route.id, progress));
}

void _validateCoordinate(double lat, double lon) =>
    GLMapGeoPoint(latitude: lat, longitude: lon).validate();
GeoMessage _geo(GLMapGeoPoint p) {
  p.validate();
  return GeoMessage(latitude: p.latitude, longitude: p.longitude);
}

GLMapGeoPoint _point(GeoMessage p) =>
    GLMapGeoPoint(latitude: p.latitude, longitude: p.longitude);
BoundsMessage _bounds(GLMapBounds b) {
  _validateCoordinate(b.south, b.west);
  _validateCoordinate(b.north, b.east);
  if (b.south >= b.north || b.west >= b.east) {
    throw ArgumentError('Bounds require positive extent');
  }
  return BoundsMessage(
    south: b.south,
    west: b.west,
    north: b.north,
    east: b.east,
  );
}
