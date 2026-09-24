import 'package:flutter/material.dart';
import 'package:glmap_flutter/glmap_flutter.dart';

import 'demo/map_examples.dart';
import 'demo/draw_examples.dart';
import 'demo/search_examples.dart';
import 'demo/routing_examples.dart';
import 'demo/download_examples.dart';
import 'demo/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? failure;
  try {
    await GLMapSDK.initialize(
      apiKey: const String.fromEnvironment('GLMAP_API_KEY'),
    );
    await GLMapSDK.addAssetDataSet('assets/Montenegro.vm', GLMapDataSet.map);
  } catch (error) {
    failure = describeError(error);
  }
  runApp(DemoApp(initializationError: failure));
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key, this.initializationError});
  final String? initializationError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GLMap Flutter',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2764E1)),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7FA),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    ),
    home: DemoCatalog(initializationError: initializationError),
  );
}

class DemoEntry {
  const DemoEntry(
    this.category,
    this.title,
    this.subtitle,
    this.icon,
    this.screen,
  );
  final String category, title, subtitle;
  final IconData icon;
  final Widget screen;
}

const demos = <DemoEntry>[
  DemoEntry(
    'Map Display',
    'Online Map',
    'Vector tiles and tap interaction',
    Icons.public,
    OnlineMapDemo(),
  ),
  DemoEntry(
    'Map Display',
    'Dark Theme',
    'Style parser and theme options',
    Icons.dark_mode_outlined,
    DarkThemeDemo(),
  ),
  DemoEntry(
    'Map Display',
    '3D Terrain',
    'Pitch, elevation and hillshades',
    Icons.terrain_outlined,
    TerrainDemo(),
  ),
  DemoEntry(
    'Camera',
    'Fly To',
    'Native animated camera movement',
    Icons.flight_takeoff,
    FlyToDemo(),
  ),
  DemoEntry(
    'Camera',
    'Zoom to BBox',
    'Fit a region and read the camera',
    Icons.fit_screen,
    ZoomToBBoxDemo(),
  ),
  DemoEntry(
    'Draw Objects',
    'Image',
    'Place and move a pin',
    Icons.place_outlined,
    ImageDemo(),
  ),
  DemoEntry(
    'Draw Objects',
    'Image Group',
    'Many pins sharing one image',
    Icons.scatter_plot_outlined,
    ImageGroupDemo(),
  ),
  DemoEntry(
    'Draw Objects',
    'Markers & Clustering',
    '400 markers with native clustering',
    Icons.bubble_chart_outlined,
    MarkerClusteringDemo(),
  ),
  DemoEntry(
    'Draw Objects',
    'Balloon',
    'Native text callouts',
    Icons.chat_bubble_outline,
    BalloonDemo(),
  ),
  DemoEntry(
    'Draw Objects',
    'Track Arrows',
    'Track progress and a line arrow',
    Icons.arrow_forward,
    TrackArrowsDemo(),
  ),
  DemoEntry(
    'Draw Objects',
    'User Location',
    'Foreground GPS and position replay',
    Icons.my_location,
    LocationDemo(),
  ),
  DemoEntry(
    'Vector Data',
    'Lines & Polygons',
    'Geometry and MapCSS styling',
    Icons.polyline_outlined,
    LinesPolygonsDemo(),
  ),
  DemoEntry(
    'Vector Data',
    'GeoJSON',
    'Load and remove a vector layer',
    Icons.data_object,
    GeoJsonDemo(),
  ),
  DemoEntry(
    'Vector Data',
    'GPS Track',
    'Record positions into a native track',
    Icons.route_outlined,
    LocationDemo(record: true),
  ),
  DemoEntry(
    'Search',
    'Search',
    'Online, offline and autocomplete',
    Icons.search,
    SearchDemo(),
  ),
  DemoEntry(
    'Search',
    'POI Tap',
    'Identify visible map labels',
    Icons.touch_app_outlined,
    POITapDemo(),
  ),
  DemoEntry(
    'Routing',
    'Route Building',
    'Online/offline routes and travel modes',
    Icons.alt_route,
    RouteBuildingDemo(),
  ),
  DemoEntry(
    'Routing',
    'Turn-by-Turn Navigation',
    'Maneuvers and route progress',
    Icons.navigation_outlined,
    TurnByTurnDemo(),
  ),
  DemoEntry(
    'Offline Data',
    'Download Maps',
    'Browse and manage regional datasets',
    Icons.download_outlined,
    DownloadMapsDemo(),
  ),
  DemoEntry(
    'Offline Data',
    'Download BBox',
    'Map, navigation and elevation for an area',
    Icons.crop_free,
    DownloadBBoxDemo(),
  ),
];

class DemoCatalog extends StatefulWidget {
  const DemoCatalog({super.key, this.initializationError});
  final String? initializationError;
  @override
  State<DemoCatalog> createState() => _DemoCatalogState();
}

class _DemoCatalogState extends State<DemoCatalog> {
  String filter = '';
  Future<void> configureKey() async {
    var enteredKey = '';
    final key = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SDK API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use a demo key for online search, routing and downloads.',
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => enteredKey = value,
              obscureText: true,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'API key'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredKey.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (key == null) return;
    try {
      await GLMapSDK.initialize(apiKey: key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SDK key applied for this session')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = demos
        .where(
          (d) => '${d.title} ${d.category}'.toLowerCase().contains(
            filter.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('GLMap · Flutter'),
        actions: [
          IconButton(
            tooltip: 'SDK API key',
            onPressed: configureKey,
            icon: const Icon(Icons.key_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Explore the SDK',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '20 small examples. Open a feature, try it, then read its Dart code.',
            ),
            const SizedBox(height: 16),
            if (widget.initializationError case final error?)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Initialization failed: $error',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Find an example',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (text) => setState(() => filter = text),
            ),
            for (final category in shown.map((d) => d.category).toSet()) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
                child: Text(
                  category.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.2,
                    color: const Color(0xFF59687D),
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final demo in shown.where(
                      (d) => d.category == category,
                    ))
                      ListTile(
                        key: ValueKey(demo.title),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Icon(
                          demo.icon,
                          color: const Color(0xFF2764E1),
                        ),
                        title: Text(demo.title),
                        subtitle: Text(demo.subtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => demo.screen,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Includes Montenegro for offline examples. Online services use your SDK key.',
              style: TextStyle(color: Color(0xFF59687D)),
            ),
          ],
        ),
      ),
    );
  }
}
