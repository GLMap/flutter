import 'package:flutter/material.dart';
import 'package:glmap/glmap.dart';

import 'common.dart';

class OnlineMapDemo extends StatefulWidget {
  const OnlineMapDemo({super.key});
  @override
  State<OnlineMapDemo> createState() => _OnlineMapDemoState();
}

class _OnlineMapDemoState extends MapDemoState<OnlineMapDemo> {
  GLMapBalloon? balloon;

  @override
  String get title => 'Online Map';
  @override
  String get api => 'Online tiles · tap coordinates';
  bool online = true;
  bool raster = false;
  @override
  Future<void> ready(GLMapController controller) =>
      controller.setOnlineTiles(online);
  @override
  Future<void> tapped(GLMapTap tap) async {
    final text =
        '${tap.point.latitude.toStringAsFixed(5)}, ${tap.point.longitude.toStringAsFixed(5)}';
    await (balloon ??= map!.createBalloon()).set(tap.point, text);
    message(text);
  }

  @override
  Widget controls() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      button(raster ? 'GLMap Vector' : 'OSM Raster', () async {
        raster = !raster;
        await map!.setRasterSource(
          raster ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png' : null,
          attribution: '© OpenStreetMap contributors',
        );
      }),
      SwitchListTile(
        title: const Text('Download visible tiles'),
        subtitle: const Text('Bundled Montenegro remains available offline'),
        value: online,
        onChanged: map == null
            ? null
            : (value) {
                setState(() => online = value);
                run(() => map!.setOnlineTiles(value));
              },
      ),
    ],
  );
}

class DarkThemeDemo extends StatefulWidget {
  const DarkThemeDemo({super.key});
  @override
  State<DarkThemeDemo> createState() => _DarkThemeDemoState();
}

class _DarkThemeDemoState extends MapDemoState<DarkThemeDemo> {
  bool dark = true;
  @override
  String get title => 'Dark Theme';
  @override
  String get api => 'GLMapStyleParser · Theme option';
  Future<void> apply() => map!.setStyleOptions(dark ? {'Theme': 'Dark'} : {});
  @override
  Future<void> ready(GLMapController controller) => apply();
  @override
  Widget controls() =>
      button(dark ? 'Use light theme' : 'Use dark theme', () async {
        setState(() => dark = !dark);
        await apply();
      });
}

class TerrainDemo extends StatefulWidget {
  const TerrainDemo({super.key});
  @override
  State<TerrainDemo> createState() => _TerrainDemoState();
}

class _TerrainDemoState extends MapDemoState<TerrainDemo> {
  double altitude = 1;
  bool hillshades = true, contours = true, slopes = false;
  GLMapRequest<void>? download;
  @override
  String get title => '3D Terrain';
  @override
  String get api => 'Altitude scale · hillshades · contours · slopes';
  Future<void> apply() => map!.setTerrain(
    altitudeScale: altitude,
    hillshades: hillshades,
    contours: contours,
    slopes: slopes,
  );
  @override
  Future<void> ready(GLMapController controller) async {
    await controller.setCamera(
      latitude: center.latitude,
      longitude: center.longitude,
      zoom: 12,
      pitch: 45,
    );
    await apply();
    message('Download elevation for the terrain view.');
  }

  @override
  Widget controls() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Text('Height ×${altitude.toStringAsFixed(1)}'),
          Expanded(
            child: Slider(
              value: altitude,
              min: 0,
              max: 3,
              onChanged: (value) {
                setState(() => altitude = value);
              },
              onChangeEnd: (_) => run(apply),
            ),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: const Text('Hillshades'),
            selected: hillshades,
            onSelected: (v) {
              setState(() => hillshades = v);
              run(apply);
            },
          ),
          FilterChip(
            label: const Text('Contours'),
            selected: contours,
            onSelected: (v) {
              setState(() => contours = v);
              run(apply);
            },
          ),
          FilterChip(
            label: const Text('Slopes'),
            selected: slopes,
            onSelected: (v) {
              setState(() => slopes = v);
              run(apply);
            },
          ),
          button('Download elevation', () async {
            download = GLMapSDK.downloadArea(
              townBounds,
              dataSets: {GLMapDataSet.elevation},
            );
            await download!.result;
            await map!.setOnlineTiles(false);
            message('Elevation ready');
          }),
        ],
      ),
    ],
  );
  @override
  void dispose() {
    download?.cancel();
    super.dispose();
  }
}

class FlyToDemo extends StatefulWidget {
  const FlyToDemo({super.key});
  @override
  State<FlyToDemo> createState() => _FlyToDemoState();
}

class _FlyToDemoState extends MapDemoState<FlyToDemo> {
  bool coast = false;
  @override
  String get title => 'Fly To';
  @override
  String get api => 'Native camera animation · flyToMode';
  @override
  Future<void> ready(GLMapController controller) async {
    message('Fly between Podgorica and the coast.');
  }

  @override
  Widget controls() =>
      button(coast ? 'Fly to Podgorica' : 'Fly to Kotor', () async {
        coast = !coast;
        await map!.animateCamera(
          center: coast
              ? const GLMapGeoPoint(latitude: 42.4247, longitude: 18.7712)
              : podgorica,
          zoom: coast ? 14 : 12,
        );
      });
}

class ZoomToBBoxDemo extends StatefulWidget {
  const ZoomToBBoxDemo({super.key});
  @override
  State<ZoomToBBoxDemo> createState() => _ZoomToBBoxDemoState();
}

class _ZoomToBBoxDemoState extends MapDemoState<ZoomToBBoxDemo> {
  bool country = false;
  @override
  String get title => 'Zoom to BBox';
  @override
  String get api => 'Native bounding-box fitting';
  @override
  Future<void> ready(GLMapController controller) =>
      controller.fitBounds(townBounds);
  @override
  Widget controls() => Wrap(
    spacing: 8,
    children: [
      button('Fit Podgorica', () => map!.fitBounds(townBounds)),
      button(
        'Fit Montenegro',
        () => map!.fitBounds(
          const GLMapBounds(
            south: 41.85,
            west: 18.43,
            north: 43.57,
            east: 20.36,
          ),
        ),
      ),
      button('Read camera', () async {
        final state = await map!.captureState();
        message(
          '${state.latitude.toStringAsFixed(4)}, ${state.longitude.toStringAsFixed(4)} · zoom ${state.zoom.toStringAsFixed(2)}',
        );
      }),
    ],
  );
}
