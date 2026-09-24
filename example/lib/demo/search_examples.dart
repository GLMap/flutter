import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:glmap_flutter/glmap_flutter.dart';

import 'common.dart';

class SearchDemo extends StatefulWidget {
  const SearchDemo({super.key});
  @override
  State<SearchDemo> createState() => _SearchDemoState();
}

class _SearchDemoState extends State<SearchDemo> {
  GLMapMarkers? markers;
  GLMapImage? selectedImage;

  final query = TextEditingController();
  GLMapController? map;
  GLMapRequest<List<GLMapPlace>>? request;
  StreamSubscription<GLMapTap>? taps;
  Timer? debounce;
  List<GLMapPlace> places = [];
  Uint8List? pin, selectedPin;
  bool offline = true, loading = false;
  int generation = 0, selected = -1;
  String status = 'Search places or browse nearby restaurants';
  Future<void> search({bool autocomplete = false}) async {
    if (pin == null || !mounted) return;
    final token = ++generation;
    await request?.cancel();
    if (!mounted || token != generation) return;
    setState(() => loading = true);
    final pending = GLMapSDK.search(
      query.text,
      center: podgorica,
      offline: offline,
      autocomplete: autocomplete,
      categories: query.text.isEmpty ? ['restaurant'] : [],
    );
    request = pending;
    try {
      final result = await pending.result;
      if (!mounted || token != generation) return;
      setState(() {
        places = result;
        selected = -1;
        status = '${places.length} results · ${offline ? 'offline' : 'online'}';
      });
      await selectedImage?.remove();
      selectedImage = null;
      await (markers ??= map!.createMarkers()).set(
        pointGeoJson(result.map((p) => p.point).toList()),
        pin!,
      );
    } catch (error) {
      if (mounted && token == generation) {
        setState(() => status = describeError(error));
      }
    } finally {
      if (mounted && token == generation) setState(() => loading = false);
    }
  }

  Future<void> select(int index) async {
    if (index < 0 || index >= places.length) return;
    setState(() => selected = index);
    try {
      await (selectedImage ??= map!.createImage()).set(
        places[index].point,
        selectedPin!,
      );
      await map!.animateCamera(
        center: places[index].point,
        zoom: 16,
        fly: false,
      );
    } catch (error) {
      if (mounted) setState(() => status = describeError(error));
    }
  }

  Future<void> ready(GLMapController controller) async {
    map = controller;
    pin = await pinImage();
    selectedPin = await pinImage(Colors.red);
    if (!mounted) return;
    taps = controller.taps.listen((tap) async {
      try {
        final snapshot = places;
        final points = await controller.project(
          snapshot.map((p) => p.point).toList(),
        );
        if (!mounted || !identical(snapshot, places)) return;
        var index = -1;
        var distance = 30.0;
        for (var i = 0; i < points.length; i++) {
          final d = (points[i] - tap.screenPoint).distance;
          if (d < distance) {
            index = i;
            distance = d;
          }
        }
        if (index >= 0) await select(index);
      } catch (error) {
        if (mounted) setState(() => status = describeError(error));
      }
    });
    await search();
  }

  @override
  void dispose() {
    generation++;
    debounce?.cancel();
    request?.cancel();
    taps?.cancel();
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Search')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: query,
              decoration: InputDecoration(
                hintText: 'Place or empty for restaurants',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () => search(),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onSubmitted: (_) {
                debounce?.cancel();
                search();
              },
              onChanged: (_) {
                debounce?.cancel();
                debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => search(autocomplete: true),
                );
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Offline search'),
            subtitle: const Text('GLSearchRequest · bundled Montenegro'),
            value: offline,
            onChanged: (value) {
              setState(() => offline = value);
              debounce?.cancel();
              search();
            },
          ),
          Expanded(
            flex: 3,
            child: GLMap(
              initialCenter: podgorica,
              initialZoom: 13,
              onCreated: ready,
            ),
          ),
          SizedBox(
            height: 2,
            child: loading ? const LinearProgressIndicator(minHeight: 2) : null,
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(status, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: places.length,
              itemBuilder: (context, index) {
                final p = places[index];
                return ListTile(
                  selected: index == selected,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(p.name),
                  subtitle: Text(p.detail),
                  onTap: () => select(index),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class POITapDemo extends StatefulWidget {
  const POITapDemo({super.key});
  @override
  State<POITapDemo> createState() => _POITapDemoState();
}

class _POITapDemoState extends MapDemoState<POITapDemo> {
  GLMapBalloon? balloon;

  @override
  String get title => 'POI Tap';
  @override
  String get api => 'GLMapViewState + GLSearch · identify a visible label';
  @override
  double get zoom => 16;
  @override
  Future<void> ready(GLMapController controller) async {
    message('Tap a map label');
  }

  @override
  Future<void> tapped(GLMapTap tap) async {
    final object = await map!.pickObject(tap.screenPoint);
    if (object == null) {
      message('No visible POI here');
      return;
    }
    await (balloon ??= map!.createBalloon()).set(
      object.point,
      object.name,
    );
    message('${object.name}\n${object.detail}');
  }

  @override
  Widget controls() => button(
    'Reset view',
    () => map!.animateCamera(center: podgorica, zoom: 16),
  );
}
