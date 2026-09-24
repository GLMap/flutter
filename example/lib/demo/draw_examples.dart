import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glmap_flutter/glmap_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'common.dart';

class ImageDemo extends StatefulWidget {
  const ImageDemo({super.key});
  @override
  State<ImageDemo> createState() => _ImageDemoState();
}

class _ImageDemoState extends MapDemoState<ImageDemo> {
  GLMapImage? image;

  Uint8List? png;
  @override
  String get title => 'Image';
  @override
  String get api => 'GLMapImage · tap to move the pin';
  @override
  Future<void> ready(GLMapController controller) async {
    png = await pinImage();
    await (image ??= controller.createImage()).set(center, png!);
  }

  @override
  Future<void> tapped(GLMapTap tap) =>
      (image ??= map!.createImage()).set(tap.point, png!);
  @override
  Widget controls() => button(
    'Reset pin',
    () => (image ??= map!.createImage()).set(center, png!),
  );
}

class ImageGroupDemo extends StatefulWidget {
  const ImageGroupDemo({super.key});
  @override
  State<ImageGroupDemo> createState() => _ImageGroupDemoState();
}

class _ImageGroupDemoState extends MapDemoState<ImageGroupDemo> {
  GLMapImageGroup? imageGroup;

  final points = [...sampleLine];
  Uint8List? png;
  @override
  String get title => 'Image Group';
  @override
  String get api => 'GLMapImageGroup · long press to add, tap to remove';
  Future<void> draw() async {
    await (imageGroup ??= map!.createImageGroup()).set(points, png!);
    message('${points.length} pins share one image');
  }

  @override
  Future<void> ready(GLMapController controller) async {
    png = await pinImage(Colors.deepOrange);
    await draw();
  }

  @override
  Future<void> tapped(GLMapTap tap) async {
    if (tap.longPress) {
      points.add(tap.point);
    } else {
      final display = await map!.project(points);
      var nearest = -1;
      var distance = 32.0;
      for (var i = 0; i < display.length; i++) {
        final d = (display[i] - tap.screenPoint).distance;
        if (d < distance) {
          nearest = i;
          distance = d;
        }
      }
      if (nearest >= 0) points.removeAt(nearest);
    }
    await draw();
  }

  @override
  Widget controls() => button('Reset group', () async {
    points
      ..clear()
      ..addAll(sampleLine);
    await draw();
  });
}

class MarkerClusteringDemo extends StatefulWidget {
  const MarkerClusteringDemo({super.key});
  @override
  State<MarkerClusteringDemo> createState() => _MarkerClusteringDemoState();
}

class _MarkerClusteringDemoState extends MapDemoState<MarkerClusteringDemo> {
  GLMapMarkers? markers;

  Uint8List? png;
  bool clustered = true;
  final points = List.generate(
    400,
    (i) => GLMapGeoPoint(
      latitude: 42.425 + (i ~/ 20) * 0.001,
      longitude: 19.245 + (i % 20) * 0.0015,
    ),
  );
  @override
  String get title => 'Markers & Clustering';
  @override
  String get api => 'GLMapMarkerLayer · native clustering';
  Future<void> draw() => (markers ??= map!.createMarkers()).set(
    pointGeoJson(points),
    png!,
    clusteringRadius: clustered ? 32 : 0,
  );
  @override
  Future<void> ready(GLMapController controller) async {
    png = await pinImage(Colors.amber);
    await draw();
    message('400 markers · zoom in to separate clusters');
  }

  @override
  Widget controls() => SwitchListTile(
    title: const Text('Native clustering'),
    value: clustered,
    onChanged: (v) {
      setState(() => clustered = v);
      run(draw);
    },
  );
}

class BalloonDemo extends StatefulWidget {
  const BalloonDemo({super.key});
  @override
  State<BalloonDemo> createState() => _BalloonDemoState();
}

class _BalloonDemoState extends MapDemoState<BalloonDemo> {
  GLMapImageGroup? imageGroup;
  GLMapBalloon? balloon;

  @override
  String get title => 'Balloon';
  @override
  String get api => 'GLMapBalloon · native text and background';
  @override
  Future<void> ready(GLMapController controller) async {
    await (imageGroup ??= controller.createImageGroup()).set(
      sampleLine,
      await pinImage(),
    );
    message('Tap a pin to show its balloon');
  }

  @override
  Future<void> tapped(GLMapTap tap) async {
    final points = await map!.project(sampleLine);
    for (var i = 0; i < points.length; i++) {
      if ((points[i] - tap.screenPoint).distance < 32) {
        await (balloon ??= map!.createBalloon()).set(
          sampleLine[i],
          'Landmark ${i + 1}',
        );
        return;
      }
    }
  }

  @override
  Widget controls() => button(
    'Show first landmark',
    () => (balloon ??= map!.createBalloon()).set(
      sampleLine.first,
      'Landmark 1',
    ),
  );
}

class LinesPolygonsDemo extends StatefulWidget {
  const LinesPolygonsDemo({super.key});
  @override
  State<LinesPolygonsDemo> createState() => _LinesPolygonsDemoState();
}

class _LinesPolygonsDemoState extends MapDemoState<LinesPolygonsDemo> {
  GLMapVectorLayer? layer;
  bool alternate = false;
  @override
  String get title => 'Lines & Polygons';
  @override
  String get api => 'GLMapVectorLayer · geometry and MapCSS';
  @override
  Future<void> ready(GLMapController controller) async {
    layer = await controller.createVectorLayer();
    await layer!.replace(
      GLMapGeometry.geoJson(
        jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  for (final p in sampleLine) [p.longitude, p.latitude],
                ],
              },
            },
            {
              'type': 'Feature',
              'properties': {},
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  [
                    [19.261, 42.427],
                    [19.274, 42.427],
                    [19.274, 42.434],
                    [19.261, 42.434],
                    [19.261, 42.427],
                  ],
                ],
              },
            },
          ],
        }),
      ),
      style: 'line{width:5pt;color:#2764E1;} area{fill-color:#F29A3860;color:#F29A38;}',
    );
  }

  @override
  Widget controls() => button('Change style', () async {
    alternate = !alternate;
    await layer!.setStyle(
      alternate
          ? 'line{width:8pt;color:#E34B52;} area{fill-color:#2764E180;color:#2764E1;}'
          : 'line{width:5pt;color:#2764E1;} area{fill-color:#F29A3860;color:#F29A38;}',
    );
  });
}

class GeoJsonDemo extends StatefulWidget {
  const GeoJsonDemo({super.key});
  @override
  State<GeoJsonDemo> createState() => _GeoJsonDemoState();
}

class _GeoJsonDemoState extends MapDemoState<GeoJsonDemo> {
  GLMapVectorLayer? layer;
  @override
  String get title => 'GeoJSON';
  @override
  String get api => 'GeoJSON asset · vector layer · native hit testing';
  @override
  GLMapGeoPoint get center => const GLMapGeoPoint(latitude: 54, longitude: -3);
  @override
  double get zoom => 5;
  Future<void> draw() async {
    layer ??= await map!.createVectorLayer();
    await layer!.replace(
      GLMapGeometry.geoJson(
        await rootBundle.loadString('assets/uk_postcodes.geojson'),
      ),
      style: 'area{fill-color:#3498DB40;width:1.5pt;color:#2C3E50;}',
    );
    message('Tap a UK postcode region');
  }

  @override
  Future<void> ready(GLMapController controller) => draw();
  @override
  Future<void> tapped(GLMapTap tap) async {
    final hit = await layer?.pickFeature(tap.screenPoint);
    if (hit == null) {
      message('No feature here');
      return;
    }
    final feature = jsonDecode(hit) as Map<String, dynamic>;
    message('Selected: ${feature['properties']}');
  }

  @override
  Widget controls() => Wrap(
    spacing: 8,
    children: [
      button('Load GeoJSON', draw),
      button('Remove layer', () async {
        await layer?.remove();
        layer = null;
        message('Layer removed');
      }),
    ],
  );
}

class TrackArrowsDemo extends StatefulWidget {
  const TrackArrowsDemo({super.key});
  @override
  State<TrackArrowsDemo> createState() => _TrackArrowsDemoState();
}

class _TrackArrowsDemoState extends MapDemoState<TrackArrowsDemo> {
  GLMapTrack? track;

  double progress = 0;
  @override
  String get title => 'Track Arrows';
  @override
  String get api => 'GLMapTrack · GLMapLineArrow · track progress';
  Future<void> draw() => (track ??= map!.createTrack()).setGeometry(
    packed(sampleLine),
    progress: progress,
    arrows: true,
  );
  @override
  Future<void> ready(GLMapController controller) async {
    await controller.setStyleOptions({}, assetDirectory: 'assets');
    await draw();
  }

  @override
  Widget controls() => Slider(
    value: progress,
    max: (sampleLine.length - 1).toDouble(),
    label: 'Progress ${progress.toStringAsFixed(1)}',
    onChanged: (v) {
      setState(() => progress = v);
    },
    onChangeEnd: (_) => run(draw),
  );
}

class LocationDemo extends StatefulWidget {
  const LocationDemo({super.key, this.record = false});
  final bool record;
  @override
  State<LocationDemo> createState() => _LocationDemoState();
}

class _LocationDemoState extends MapDemoState<LocationDemo> {
  GLMapImage? image;
  GLMapTrack? track;

  StreamSubscription<Position>? locations;
  Uint8List? png;
  final recorded = <GLMapGeoPoint>[];
  int replayIndex = 0;
  @override
  String get title => widget.record ? 'GPS Track' : 'User Location';
  @override
  String get api => widget.record
      ? 'Foreground GPS → GLMapTrack'
      : 'Foreground GPS → map position';
  @override
  Future<void> ready(GLMapController controller) async {
    png = await pinImage(Colors.teal);
    message('Use GPS or replay sample positions');
  }

  Future<void> update(GLMapGeoPoint p) async {
    if (!mounted) return;
    await (image ??= map!.createImage()).set(p, png!);
    if (widget.record) {
      recorded.add(p);
      if (recorded.length >= 2) {
        await (track ??= map!.createTrack()).setGeometry(packed(recorded));
      }
    }
    await map!.animateCamera(center: p, zoom: 15, duration: 0.5, fly: false);
    message(
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}${widget.record ? ' · ${recorded.length} points' : ''}',
    );
  }

  Future<void> startGps() async {
    await locations?.cancel();
    final stream = await foregroundPositions();
    if (!mounted) return;
    locations = stream.listen(
      (p) => run(
        () =>
            update(GLMapGeoPoint(latitude: p.latitude, longitude: p.longitude)),
      ),
      onError: (Object error) => message(describeError(error)),
    );
    message('Waiting for GPS…');
  }

  @override
  Widget controls() => Wrap(
    spacing: 8,
    children: [
      button('Use GPS', startGps),
      button(
        'Next sample',
        () => update(sampleLine[(replayIndex++) % sampleLine.length]),
      ),
      button('Stop', () async {
        await locations?.cancel();
        locations = null;
        message('Location updates stopped');
      }),
    ],
  );
  @override
  void dispose() {
    locations?.cancel();
    super.dispose();
  }
}
