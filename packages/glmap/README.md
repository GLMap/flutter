# glmap

Native GLMap views for Flutter on Android and iOS: camera control, gestures,
vector layers, hit testing and map-owned drawings.

Depends on `glmap_core`, not on Search or Route. Importing `glmap` also exports
Core's shared types and SDK initialization API.

## Installation

Add [glmap](https://pub.dev/packages/glmap) to your Flutter app:

```sh
flutter pub add glmap
```

## Requirements

Flutter 3.47.4+, Dart `^3.13.3`, Android API 24+ and iOS 16.4+.
The plugin depends on native GLMap 2.2.0. Follow the
[Android/iOS host setup](../../README.md#2-configure-the-native-host) before
running your app.

## Create a map

Initialize Core before constructing a map:

```dart
import 'package:flutter/material.dart';
import 'package:glmap/glmap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GLMapSDK.initialize(
    apiKey: const String.fromEnvironment('GLMAP_API_KEY'),
  );
  runApp(MaterialApp(
    home: Scaffold(
      body: GLMap(
        initialCenter: const GLMapGeoPoint(latitude: 42.4341, longitude: 19.26),
        initialZoom: 12,
        onCreated: (controller) {
          // Use the controller for camera, vector and drawing operations.
        },
      ),
    ),
  ));
}
```

Map display requires map data or access to the online service. See the
[demo app](../../example/README.md) for bundled datasets, keys and complete examples.

## Ownership and behavior

- A `GLMapController` belongs to its widget and becomes invalid when the widget is
  removed. Pending operations settle with an error instead of remaining open.
- `captureState()` returns a snapshot. Await a camera command before capture if
  the order matters; the snapshot does not follow later camera changes.
- Vector layers and drawing handles belong to one map. Do not reuse them on
  another map or after removal.
- Search's `pickObject` extension is available by importing `glsearch`; it is not
  an implicit dependency of Map.
- Route drawing accepts Core's `GLMapTrackSource`, so Map does not need to import
  the Route SDK.

See `example/lib/demo/map_examples.dart` and `draw_examples.dart` in the repository
for camera, vector, image, marker, track and location examples. Native SDK and
map-data license terms apply in addition to this package's [LICENSE](LICENSE).
