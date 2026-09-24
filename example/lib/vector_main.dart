import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glmap/glmap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = jsonDecode(
    await rootBundle.loadString('assets/stage-a.json'),
  ) as Map<String, dynamic>;
  // This demo draws its track through the public Dart API.
  fixture['trackJson'] = '{"type":"FeatureCollection","features":[]}';
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VectorDemo(fixture: fixture),
    ),
  );
}

class VectorDemo extends StatefulWidget {
  const VectorDemo({super.key, required this.fixture});
  final Map<String, dynamic> fixture;
  @override
  State<VectorDemo> createState() => _VectorDemoState();
}

class _VectorDemoState extends State<VectorDemo> {
  GLMapController? controller;
  GLMapVectorLayer? layer;
  String status = 'Creating map…';
  bool busy = false;
  static const green = 'line{width:8pt;color:#00AA44;}';
  static const blue = 'line{width:5pt;color:#2650D6;}';

  Future<void> action(String name, Future<Object?> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await operation();
      if (mounted) setState(() => status = '$name: ${result ?? 'done'}');
    } catch (error) {
      if (mounted) setState(() => status = '$name: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<GLMapVectorUpdateResult> draw() async {
    final target = layer ?? await controller!.createVectorLayer(drawOrder: 3);
    if (mounted) setState(() => layer = target);
    return target.replace(
      GLMapGeometry.geoJson(jsonEncode(widget.fixture['track'])),
      style: green,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('GLMap · Dart vector layer')),
    body: Stack(
      children: [
        Positioned.fill(
          child: GLMap(
            fixture: widget.fixture,
            onCreated: (value) {
              controller = value;
              action('Draw', draw);
            },
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(status),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: busy || controller == null
                      ? null
                      : () => action('Draw', draw),
                  child: const Text('Draw'),
                ),
                FilledButton(
                  onPressed: busy || layer == null
                      ? null
                      : () => action('Restyle', () => layer!.setStyle(blue)),
                  child: const Text('Restyle'),
                ),
                FilledButton(
                  onPressed: busy || layer == null
                      ? null
                      : () => action('Remove', () async {
                          final current = layer!;
                          setState(() => layer = null);
                          await current.remove();
                          return null;
                        }),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
