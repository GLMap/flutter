# glmap_core

Shared services and types for the GLMap Flutter packages: SDK initialization,
bundled datasets, regional downloads and area downloads. Core does not include
the map renderer and can be used without a map widget.

## Installation

Add [glmap_core](https://pub.dev/packages/glmap_core) to your Flutter app:

```sh
flutter pub add glmap_core
```

## Requirements

Flutter 3.47.4+, Dart `^3.13.3`, Android API 24+ and iOS 16.4+.
The plugin depends on native GLMap Core 2.2.0. Follow the
[Android/iOS host setup](../../README.md#2-configure-the-native-host) before
running your app.

## Initialize and register data

Call initialization after the Flutter binding is ready and before other native
APIs. This example uses the dataset bundled in the repository's demo app:

```dart
import 'package:flutter/widgets.dart';
import 'package:glmap_core/glmap_core.dart';

Future<void> initializeMaps() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GLMapSDK.initialize(
    apiKey: const String.fromEnvironment('GLMAP_API_KEY'),
  );
  await GLMapSDK.addAssetDataSet('assets/Montenegro.vm', GLMapDataSet.map);
}
```

In another application, declare the dataset in that app's `pubspec.yaml` and use
its asset path. Online services and downloads require a suitable API key.

## Downloads and shared types

- `GLMapSDK.regions()` returns a regional catalog; `GLMapRegion` exposes download,
  cancellation and deletion methods.
- `GLMapSDK.downloadArea()` starts a download for a `GLMapBounds` and returns a
  cancellable `GLMapRequest<void>`.
- `GLMapSDK.downloads` reports progress and completion events for regional and
  area downloads. Cancel subscriptions when their UI is disposed.
- `GLMapDataSet` selects map, navigation or elevation data. Register/download the
  datasets needed by offline search, routing and terrain display.
- `GLMapGeoPoint`, `GLMapBounds`, `GLMapPlace` and `GLMapRequest<T>` are shared by
  the other packages. Bounds must have positive extent and must not cross the
  antimeridian.

See the [download demos](../../example/lib/demo/download_examples.dart) and
[example guide](../../example/README.md) for complete flows. Add `glmap`,
`glsearch` or `glroute` only when their APIs are needed. Native SDK and map-data
license terms apply in addition to this package's [LICENSE](LICENSE).
