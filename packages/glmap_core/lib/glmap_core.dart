import 'dart:async';

import 'package:flutter/foundation.dart';

import 'src/core.g.dart';

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
}

@immutable
class GLMapPlace {
  const GLMapPlace({
    required this.name,
    required this.detail,
    required this.point,
  });
  final String name, detail;
  final GLMapGeoPoint point;
}

enum GLMapDataSet { map, navigation, elevation }

class GLMapRequest<T> {
  GLMapRequest(this.id, this.result, this._cancel);
  final Future<void> Function() _cancel;
  final int id;
  final Future<T> result;
  Future<void> cancel() => _cancel();
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
  static final _api = CoreHostApi();
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
    return GLMapRequest(
      id,
      _api.downloadArea(id, bounds._message, _mask(dataSets)),
      () => _api.cancelRequest(id),
    );
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

@immutable
class GLMapGeoPoint {
  const GLMapGeoPoint({required this.latitude, required this.longitude});
  final double latitude, longitude;
  void validate() => _validateCoordinate(latitude, longitude);
}

/// Cross-package query identity; native snapshots are acquired/released by the owning map.
abstract interface class GLMapQueryTarget {
  int get viewId;
}

/// Geometry provider retained by the Route plugin; Map never imports the Route SDK.
abstract interface class GLMapTrackSource {
  int get id;
}
