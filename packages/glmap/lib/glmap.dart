import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'src/map.g.dart';
import 'src/features.g.dart';

import 'package:glmap_core/glmap_core.dart';
export 'package:glmap_core/glmap_core.dart';
part 'src/vector.dart';
part 'src/features.dart';

/// Values from one native GLMapViewState. This object does not follow the map.
@immutable
class GLMapViewState {
  GLMapViewState._(MapStateMessage value)
    : latitude = value.latitude,
      longitude = value.longitude,
      zoom = value.zoom,
      scale = value.scale,
      angle = value.angle,
      pitch = value.pitch,
      originX = value.originX,
      originY = value.originY;

  /// WGS84 coordinates of the captured, render-aligned center.
  final double latitude, longitude;
  final double zoom, scale;

  /// Rotation and pitch in degrees. Native rendering normalizes pitch below 0.1° to zero.
  final double angle, pitch;

  /// Relative map origin, using the native SDK's coordinate convention.
  final double originX, originY;
}

/// Owned by its GLMap widget. Removing the widget invalidates this controller.
class GLMapController implements GLMapQueryTarget {
  GLMapController._(this.viewId)
    : _api = MapHostApi(messageChannelSuffix: '$viewId'),
      _diagnostics = MethodChannel('glmap_lab/$viewId'),
      _features = MapFeaturesHostApi(messageChannelSuffix: '$viewId') {
    MapEventsApi.setUp(_MapEvents(_taps), messageChannelSuffix: '$viewId');
  }

  @override
  final int viewId;
  final MapHostApi _api;
  final MethodChannel _diagnostics;
  final MapFeaturesHostApi _features;
  final _taps = StreamController<GLMapTap>.broadcast();
  Stream<GLMapTap> get taps => _taps.stream;
  final _pending = <Completer<dynamic>>{};
  bool _disposed = false;
  int _nextDrawableId = 0;

  static PlatformException _disposedError() => PlatformException(
    code: 'map_disposed',
    message: 'The GLMap widget has been removed.',
  );

  Future<T> _invoke<T>(Future<T> Function() operation) {
    if (_disposed) return Future<T>.error(_disposedError());
    final reply = Completer<T>();
    _pending.add(reply);
    Future<T>.sync(operation).then(
      (value) {
        _pending.remove(reply);
        if (!reply.isCompleted) reply.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        _pending.remove(reply);
        if (!reply.isCompleted) reply.completeError(error, stack);
      },
    );
    return reply.future;
  }

  /// Captures current values together from the native GLMapViewState.
  ///
  /// May wait for native rendering. An unattached map reports `map_unavailable`.
  /// Removing the widget completes pending requests with `map_disposed`.
  /// Await a camera change before capturing when ordering matters.
  Future<GLMapViewState> captureState() =>
      _invoke(() async => GLMapViewState._(await _api.captureState()));

  /// Adds an empty vector layer owned by this map. Geometry is supplied separately.
  Future<GLMapVectorLayer> createVectorLayer({int drawOrder = 1}) {
    RangeError.checkValueInInterval(
      drawOrder,
      -2147483648,
      2147483647,
      'drawOrder',
    );
    return _invoke(
      () async =>
          GLMapVectorLayer._(this, await _api.createVectorLayer(drawOrder)),
    );
  }

  /// Immediately sets the camera. Completion acknowledges applying the command,
  /// not presentation of a frame. The SDK may clamp zoom to its viewport limits.
  Future<void> setCamera({
    required double latitude,
    required double longitude,
    required double zoom,
    double angle = 0,
    double pitch = 0,
  }) {
    for (final entry in {
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom,
      'angle': angle,
      'pitch': pitch,
    }.entries) {
      if (!entry.value.isFinite) {
        throw ArgumentError.value(entry.value, entry.key, 'Must be finite');
      }
    }
    if (latitude < -90 || latitude > 90) {
      throw RangeError.range(latitude, -90, 90, 'latitude');
    }
    if (longitude < -180 || longitude > 180) {
      throw RangeError.range(longitude, -180, 180, 'longitude');
    }
    // Both native SDKs accept angle as a 32-bit float.
    const maxNativeAngle = 3.4028234663852886e38;
    if (angle.abs() > maxNativeAngle) {
      throw RangeError('angle must fit in a finite native float');
    }
    if (pitch < 0 || pitch > 45) throw RangeError.range(pitch, 0, 45, 'pitch');
    return _invoke(
      () => _api.setCamera(
        MapCameraMessage(
          latitude: latitude,
          longitude: longitude,
          zoom: zoom,
          angle: angle,
          pitch: pitch,
        ),
      ),
    );
  }

  /// Lab diagnostics and benchmark counters; camera entries are configured targets.
  Future<Map<String, dynamic>> diagnostics() => _invoke(
    () async => Map<String, dynamic>.from(
      await _diagnostics.invokeMapMethod('diagnostics') ?? {},
    ),
  );

  void _dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final reply in _pending) {
      reply.completeError(_disposedError());
    }
    _pending.clear();
    MapEventsApi.setUp(null, messageChannelSuffix: '$viewId');
    unawaited(_taps.close());
    // Platform-view teardown may have removed these channels already.
    unawaited(_api.dispose().catchError((Object _) {}));
  }
}

class GLMap extends StatefulWidget {
  const GLMap({
    super.key,
    this.fixture,
    this.initialCenter = const GLMapGeoPoint(
      latitude: 42.4341,
      longitude: 19.26,
    ),
    this.initialZoom = 12,
    required this.onCreated,
  });

  /// Only used by the historical lab tests. Ordinary examples use initialCenter.
  final Map<String, dynamic>? fixture;
  final GLMapGeoPoint initialCenter;
  final double initialZoom;
  final ValueChanged<GLMapController> onCreated;

  @override
  State<GLMap> createState() => _GLMapState();
}

class _GLMapState extends State<GLMap> {
  GLMapController? _controller;

  void _created(int id) {
    final controller = GLMapController._(id);
    if (!mounted) {
      controller._dispose();
      return;
    }
    _controller?._dispose();
    _controller = controller;
    widget.onCreated(controller);
  }

  @override
  void dispose() {
    _controller?._dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params =
        widget.fixture ??
        <String, dynamic>{
          'camera': {
            'latitude': widget.initialCenter.latitude,
            'longitude': widget.initialCenter.longitude,
            'zoom': widget.initialZoom,
          },
        };
    final gestures = <Factory<OneSequenceGestureRecognizer>>{
      Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
    };
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidView(
        viewType: 'glmap_lab',
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _created,
        gestureRecognizers: gestures,
      ),
      TargetPlatform.iOS => UiKitView(
        viewType: 'glmap_lab',
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _created,
        gestureRecognizers: gestures,
      ),
      _ => const Center(child: Text('GLMap lab supports iOS and Android.')),
    };
  }
}
