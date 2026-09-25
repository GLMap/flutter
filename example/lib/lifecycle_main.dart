import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glmap/glmap.dart';

import 'demo/common.dart' show pinImage;

Future<Map<String, dynamic>> loadLifecycleFixture() async =>
    jsonDecode(await rootBundle.loadString('assets/stage-a.json'))
        as Map<String, dynamic>;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GLMapSDK.initialize(
    apiKey: const String.fromEnvironment('GLMAP_API_KEY'),
  );
  runApp(LifecycleApp(fixture: await loadLifecycleFixture()));
}

class LifecycleApp extends StatelessWidget {
  const LifecycleApp({super.key, required this.fixture});
  final Map<String, dynamic> fixture;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GLMap lifecycle sample',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xff2650d6)),
    home: LifecycleScreen(fixture: fixture),
  );
}

/// Camera, overlays and repeated disposal using the same public map as the catalog.
class LifecycleScreen extends StatefulWidget {
  const LifecycleScreen({super.key, required this.fixture});
  final Map<String, dynamic> fixture;

  @override
  State<LifecycleScreen> createState() => LifecycleScreenState();
}

class LifecycleScreenState extends State<LifecycleScreen> {
  GLMapController? controller;
  String status = 'Creating native map…';
  int generation = 0;
  bool visible = true;
  bool panel = true;

  Map<String, dynamic> get camera =>
      widget.fixture['camera'] as Map<String, dynamic>;

  Future<void> prepare(GLMapController current) async {
    try {
      final layer = await current.createVectorLayer(drawOrder: 1);
      await layer.replace(
        GLMapGeometry.geoJson(jsonEncode(widget.fixture['track'])),
        style: 'line{width:4pt;color:#E74C3C;}',
      );
      if (!mounted || controller != current) return;
      final marker = widget.fixture['marker'] as Map<String, dynamic>;
      final png = await pinImage();
      if (!mounted || controller != current) return;
      await current.createImage().set(
        GLMapGeoPoint(
          latitude: (marker['latitude'] as num).toDouble(),
          longitude: (marker['longitude'] as num).toDouble(),
        ),
        png,
      );
      if (mounted && controller == current) await refresh();
    } catch (error) {
      if (mounted && controller == current) {
        setState(() => status = 'ERROR: $error');
      }
    }
  }

  Future<void> refresh() async {
    final current = controller;
    if (current == null) return;
    try {
      final state = await current.captureState();
      final diagnostics = await current.diagnostics();
      if (!mounted || current != controller) return;
      setState(
        () => status =
            'GLMap · taps ${diagnostics['taps']} · zoom ${state.zoom.toStringAsFixed(2)}\n'
            'lat ${state.latitude.toStringAsFixed(4)} · lon ${state.longitude.toStringAsFixed(4)} · angle ${state.angle.toStringAsFixed(1)}',
      );
    } catch (error) {
      if (mounted && current == controller) {
        setState(
          () => status =
              error is PlatformException && error.code == 'map_unavailable'
              ? 'Creating native map… Tap Read state when visible.'
              : 'ERROR: $error',
        );
      }
    }
  }

  Future<void> resetCamera() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final current = controller;
    if (current == null) return;
    try {
      await current.setCamera(
        latitude: (camera['latitude'] as num).toDouble(),
        longitude: (camera['longitude'] as num).toDouble(),
        zoom: (camera['zoom'] as num).toDouble(),
      );
      if (mounted && current == controller) await refresh();
    } catch (error) {
      if (mounted && current == controller) {
        setState(() => status = 'ERROR: $error');
      }
    }
  }

  void toggleMap() => setState(() {
    visible = !visible;
    controller = null;
    generation++;
    status = visible ? 'Creating native map…' : 'Native map disposed';
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('GLMap · Lifecycle'),
      actions: [
        IconButton(
          key: const Key('toggle-panel'),
          tooltip: 'Toggle overlay',
          icon: const Icon(Icons.layers),
          onPressed: () => setState(() => panel = !panel),
        ),
      ],
    ),
    body: Stack(
      children: [
        Positioned.fill(
          child: visible
              ? GLMap(
                  key: ValueKey('map-$generation'),
                  initialCenter: GLMapGeoPoint(
                    latitude: (camera['latitude'] as num).toDouble(),
                    longitude: (camera['longitude'] as num).toDouble(),
                  ),
                  initialZoom: (camera['zoom'] as num).toDouble(),
                  onCreated: (value) {
                    controller = value;
                    prepare(value);
                  },
                )
              : const Center(
                  child: Text('Map removed. Open it again to test disposal.'),
                ),
        ),
        if (panel)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Prague → Vienna → Budapest',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const TextField(
                      key: Key('search-field'),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Keyboard / overlay test',
                      ),
                    ),
                    Semantics(
                      identifier: 'native-state',
                      container: true,
                      child: Text(
                        status,
                        key: const Key('status'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (panel)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              top: false,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  FilledButton(
                    key: const Key('reset-camera'),
                    onPressed: resetCamera,
                    child: const Text('Reset'),
                  ),
                  FilledButton(
                    key: const Key('refresh-state'),
                    onPressed: refresh,
                    child: const Text('Read state'),
                  ),
                  FilledButton(
                    key: const Key('toggle-map'),
                    onPressed: toggleMap,
                    child: Text(visible ? 'Close map' : 'Open map'),
                  ),
                  FilledButton(
                    key: const Key('navigate'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: const Text('Navigation test')),
                          body: Center(
                            child: FilledButton(
                              key: const Key('back-to-map'),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Back to map'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Next screen'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
