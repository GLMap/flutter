import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glmap_flutter/glmap_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
    await rootBundle.loadString('assets/stage-a.json'),
  ) as Map<String, dynamic>;
  fixture['trackJson'] = jsonEncode(fixture['track']);
  runApp(LabApp(fixture: fixture));
}

class LabApp extends StatelessWidget {
  const LabApp({super.key, required this.fixture});
  final Map<String, dynamic> fixture;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GLMap lab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xff2650d6)),
    home: LabScreen(fixture: fixture),
  );
}

class LabScreen extends StatefulWidget {
  const LabScreen({super.key, required this.fixture});
  final Map<String, dynamic> fixture;
  @override
  State<LabScreen> createState() => LabScreenState();
}

class LabScreenState extends State<LabScreen> {
  GLMapController? controller;
  String status = 'Creating native map…';
  int generation = 0;
  bool visible = true;
  bool panel = true;

  Future<void> refresh() async {
    final current = controller;
    if (current == null) return;
    try {
      final state = await current.captureState();
      final diagnostics = await current.diagnostics();
      if (!mounted || current != controller) return;
      setState(
        () => status =
            'GLMap ${diagnostics['sdk']} · taps ${diagnostics['taps']} · zoom ${state.zoom.toStringAsFixed(2)}\n'
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

  void toggleMap() => setState(() {
    visible = !visible;
    controller = null;
    generation++;
    status = visible ? 'Creating native map…' : 'Native map disposed';
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('GLMap · Flutter / A'),
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
                  fixture: widget.fixture,
                  onCreated: (value) {
                    controller = value;
                    refresh();
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
                    onPressed: () async {
                      FocusManager.instance.primaryFocus?.unfocus();
                      final camera =
                          widget.fixture['camera'] as Map<String, dynamic>;
                      await controller?.setCamera(
                        latitude: camera['latitude'],
                        longitude: camera['longitude'],
                        zoom: camera['zoom'],
                      );
                      await refresh();
                    },
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
