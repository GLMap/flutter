import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:glmap/glmap.dart';
import 'package:geolocator/geolocator.dart';

const podgorica = GLMapGeoPoint(latitude: 42.4341, longitude: 19.26);
const townBounds = GLMapBounds(
  south: 42.42,
  west: 19.24,
  north: 42.45,
  east: 19.28,
);
const sampleLine = [
  GLMapGeoPoint(latitude: 42.428, longitude: 19.246),
  GLMapGeoPoint(latitude: 42.432, longitude: 19.249),
  GLMapGeoPoint(latitude: 42.433, longitude: 19.254),
  GLMapGeoPoint(latitude: 42.438, longitude: 19.258),
  GLMapGeoPoint(latitude: 42.440, longitude: 19.269),
];

String describeError(Object error) => error is PlatformException
    ? (error.message ?? error.code).split('\n').first
    : error.toString().split('\n').first;

Future<ByteData?> _pinData(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(const Offset(18, 18), 17, Paint()..color = Colors.white);
  canvas.drawCircle(const Offset(18, 18), 13, Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(36, 36);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data;
}

Future<Uint8List> pinImage([Color color = const Color(0xFF2764E1)]) async =>
    (await _pinData(color))!.buffer.asUint8List();

String pointGeoJson(List<GLMapGeoPoint> points) => jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    for (var i = 0; i < points.length; i++)
      {
        'type': 'Feature',
        'properties': {'name': 'Place ${i + 1}'},
        'geometry': {
          'type': 'Point',
          'coordinates': [points[i].longitude, points[i].latitude],
        },
      },
  ],
});
Float64List packed(List<GLMapGeoPoint> points) => Float64List.fromList([
  for (final p in points) ...[p.longitude, p.latitude],
]);

/// Routine screen layout only. Each example owns its SDK calls and UI state.
abstract class MapDemoState<T extends StatefulWidget> extends State<T> {
  GLMapController? map;
  String status = '';
  bool busy = false;
  StreamSubscription<GLMapTap>? _taps;
  String get title;
  String get api;
  GLMapGeoPoint get center => podgorica;
  double get zoom => 13;
  Future<void> ready(GLMapController controller);
  Future<void> tapped(GLMapTap tap) async {}
  Widget controls();
  Future<void> run(Future<void> Function() operation) async {
    if (!mounted || busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => status = describeError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void message(String text) {
    if (mounted) setState(() => status = text);
  }

  Widget button(String label, Future<void> Function() action) =>
      FilledButton.tonal(
        onPressed: map == null || busy ? null : () => run(action),
        child: Text(label),
      );
  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(api, style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        Expanded(
          child: GLMap(
            initialCenter: center,
            initialZoom: zoom,
            onCreated: (controller) {
              map = controller;
              _taps = controller.taps.listen((tap) => run(() => tapped(tap)));
              run(() => ready(controller));
            },
          ),
        ),
        SizedBox(
          height: 2,
          child: busy ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      status,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                controls(),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Future<Stream<Position>> foregroundPositions() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('Enable location services to use GPS.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw StateError('Location permission was not granted.');
  }
  return Geolocator.getPositionStream(
    // Match the native demo's Android LocationManager path, including AOSP
    // devices without Google Play Services and emulator GPS injection.
    locationSettings: defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            forceLocationManager: true,
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2,
          ),
  );
}
