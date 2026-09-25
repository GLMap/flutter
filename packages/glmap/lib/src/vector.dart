part of '../glmap.dart';

/// An immutable input value. Packed coordinates are copied at construction.
@immutable
class GLMapGeometry {
  const GLMapGeometry._(this._lonLat, this._geoJson);
  final Float64List? _lonLat;
  final String? _geoJson;

  factory GLMapGeometry.line(Iterable<GLMapGeoPoint> points) =>
      GLMapGeometry._line(
        Float64List.fromList([
          for (final point in points) ...[point.longitude, point.latitude],
        ]),
      );

  /// [longitude, latitude, ...], in degrees. An empty line clears the layer.
  factory GLMapGeometry.packedLineLonLat(Float64List coordinates) =>
      GLMapGeometry._line(Float64List.fromList(coordinates));

  factory GLMapGeometry._line(Float64List values) {
    if (values.length.isOdd || values.length == 2) {
      throw ArgumentError(
        'A line needs zero or at least two longitude/latitude pairs',
      );
    }
    for (var i = 0; i < values.length; i += 2) {
      if (!values[i].isFinite ||
          values[i] < -180 ||
          values[i] > 180 ||
          !values[i + 1].isFinite ||
          values[i + 1] < -90 ||
          values[i + 1] > 90) {
        throw ArgumentError('Invalid longitude/latitude pair at ${i ~/ 2}');
      }
    }
    return GLMapGeometry._(values.asUnmodifiableView(), null);
  }

  /// Parsed by the native SDK when submitted. Parse errors leave the layer intact.
  factory GLMapGeometry.geoJson(String source) => GLMapGeometry._(null, source);
}

/// Native preparation outcome for this request. Ready does not imply a displayed frame.
enum GLMapVectorUpdateResult {
  /// Prepared batches were installed, not necessarily presented in a frame.
  ready,

  /// A newer request replaced this request before preparation began.
  superseded,

  /// Removal, release or loss of the rendering surface cancelled preparation.
  cancelled,

  /// Preparation failed; previously installed batches are preserved.
  failed,
}

/// A vector layer belongs to its creating map; it cannot be transferred between maps.
class GLMapVectorLayer {
  GLMapVectorLayer._(this._map, this.id);
  final GLMapController _map;

  /// Native handle, scoped to the owning map. Intended for lab diagnostics.
  final int id;
  Future<void>? _removal;

  /// Replaces all geometry and its MapCSS style. Requests can supersede each other.
  Future<GLMapVectorUpdateResult> replace(
    GLMapGeometry geometry, {
    required String style,
  }) => _update(
    VectorMutationMessage(
      layerId: id,
      operation: VectorMutation.replace,
      lonLat: geometry._lonLat,
      geoJson: geometry._geoJson,
      style: style,
    ),
  );

  /// Reuses the last accepted native geometry. Native batches are rebuilt.
  /// Calling this before the first replace reports `missing_geometry`.
  Future<GLMapVectorUpdateResult> setStyle(String style) => _update(
    VectorMutationMessage(
      layerId: id,
      operation: VectorMutation.style,
      style: style,
    ),
  );

  Future<GLMapVectorUpdateResult> _update(VectorMutationMessage mutation) {
    if (_removal != null) {
      return Future.error(
        PlatformException(
          code: 'layer_removed',
          message: 'This layer has been removed.',
        ),
      );
    }
    return _map._invoke(() async {
      return switch (await _map._api.mutateVectorLayer(mutation)) {
        VectorReply.ready => GLMapVectorUpdateResult.ready,
        VectorReply.superseded => GLMapVectorUpdateResult.superseded,
        VectorReply.cancelled => GLMapVectorUpdateResult.cancelled,
        VectorReply.failed => GLMapVectorUpdateResult.failed,
        VectorReply.removed => throw StateError('Unexpected removal reply'),
      };
    });
  }

  /// GeoJSON of the first feature within [tolerance] logical pixels of [point].
  Future<String?> pickFeature(Offset point, {double tolerance = 12}) =>
      _map._invoke(
        () => _map._api.pickVectorFeature(id, point.dx, point.dy, tolerance),
      );

  /// Removes the layer and cancels outstanding native preparations. Idempotent.
  /// Already-running updates settle independently; await them if their result matters.
  Future<void> remove() => _removal ??= _map._invoke(() async {
    await _map._api.mutateVectorLayer(
      VectorMutationMessage(layerId: id, operation: VectorMutation.remove),
    );
  });
}
