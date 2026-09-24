# GLMap Flutter

GLMap brings native maps, search and routing to Flutter apps on **Android and
iOS**. Embed an interactive map, draw markers and routes, search for places, and
use downloaded data offline. Search and routing can also work without a map view.

This repository contains the Flutter packages and a demo app with **20 API
examples**.

- [Add a map to your app](#add-a-map-to-your-app)
- [Run the demo](#run-the-demo)
- [Explore the packages](#packages)

## Requirements

- Flutter 3.47.4 or later, with Dart compatible with `^3.13.3`.
- Android API 24 or later; Java 17 for Android builds.
- iOS 16.4 or later; Xcode and Flutter's Swift Package Manager integration.
- A suitable GLMap API key and network access for online tiles, search, routing
  and downloads. The demo includes data for offline map display and search.

The Flutter plugins depend on native GLMap SDK 2.2.0 through Maven on Android
and Swift Package Manager on iOS. Configure the host project as described below.

## Add a map to your app

### 1. Add the Flutter dependency

Add [glmap](https://pub.dev/packages/glmap) from pub.dev:

```sh
flutter pub add glmap
```

Or add it to your app's `pubspec.yaml` and run `flutter pub get`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  glmap: ^0.1.0-beta.1
```

The package includes `glmap_core` as a dependency. Add Search or Route separately
when your app needs those APIs; see [Packages](#packages).

### 2. Configure the native host

**Android:** add the public Maven repository to the repositories used by your app
(normally `allprojects.repositories` in `android/build.gradle.kts`):

```kotlin
maven { url = uri("https://maven.globus.software/artifactory/libs") }
```

In `android/app/build.gradle.kts`, set the minimum SDK and keep map/font assets
uncompressed. Merge these settings into the existing `android` block:

```kotlin
android {
    defaultConfig {
        minSdk = 24 // Or a higher minimum required by your app.
    }
    androidResources {
        noCompress += listOf("vm", "ttf", "otf")
    }
}
```

Use Java 17 for the Android build. See the [demo Android host](example/android/)
for a complete project configuration.

**iOS:** set the Runner deployment target to iOS 16.4 or later in Xcode and enable
[Flutter's Swift Package Manager integration](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers):

```sh
flutter config --enable-swift-package-manager
```

The plugins declare their native dependencies on
[GLMapSwift](https://github.com/GLMap/GLMapSwift). See the
[demo iOS host](example/ios/) for its project configuration.

### 3. Create the map

Replace `lib/main.dart` with this minimal online-map app. The `glmap` import also
exports the Core initialization API and shared coordinate types.

```dart
import 'package:flutter/material.dart';
import 'package:glmap/glmap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GLMapSDK.initialize(
    apiKey: const String.fromEnvironment('GLMAP_API_KEY'),
  );

  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('My map')),
        body: GLMap(
          initialCenter: const GLMapGeoPoint(
            latitude: 42.4341,
            longitude: 19.26,
          ),
          initialZoom: 13,
          onCreated: (controller) async {
            await controller.setOnlineTiles(true);
          },
        ),
        bottomNavigationBar: const SafeArea(
          child: Text(
            '© OpenStreetMap contributors',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
```

Initialize the SDK before creating the map. `onCreated` provides a
`GLMapController` for camera movement, tap events and drawing. The widget owns the
controller and its drawable handles; do not reuse them after removing that map.

### 4. Supply a key and run

Create `config/local.json` in your app and **add it to your `.gitignore`**:

```json
{"GLMAP_API_KEY":"your-demo-key"}
```

Choose an Android or iOS target from `flutter devices`, then run:

```sh
flutter devices
flutter run -d <device-id> --dart-define-from-file=config/local.json
```

Replace `<device-id>` with the actual target ID. Build-time keys are embedded in
the app; use an appropriate demo key and never commit it. This example uses
online tiles. For offline display, register a bundled or downloaded map dataset
through [Core](packages/glmap_core/README.md), as the demo does below.

## Run the demo

The demo shows maps, camera controls, drawings, search, routing and downloads.
Its bundled Montenegro dataset supports offline map display and search without
an online service request.

```sh
git clone https://github.com/GLMap/flutter.git glmap_flutter
cd glmap_flutter
flutter pub get
flutter devices
cd example
flutter run -t lib/demo_main.dart -d <device-id>
```

If you already have this repository, skip the clone and start from its root.
Use an Android device/emulator or an iOS device/simulator that meets the
[requirements](#requirements).
The Dart workspace connects the demo to the packages in `packages/` automatically.

Use **`lib/demo_main.dart`** to open the catalog; the default `lib/main.dart` is a
separate lifecycle sample. Start with **Dark Theme** or **Search** to explore the
bundled offline data. Online features and downloads require a suitable API key:
enter one with the catalog's key button for the current session, or create
`example/config/local.json` in the format shown above and run from `example/`:

```sh
flutter run -t lib/demo_main.dart -d <device-id> \
  --dart-define-from-file=config/local.json
```

This repository already ignores `config/local.json`. A key entered through the
catalog is not persisted; a build-time key is embedded in the app.

See the [demo code guide](example/README.md) for the directory structure, startup
flow and the source file behind each screen.

## Packages

Use only the modules your app needs. Map, Search and Route each depend on Core,
not on one another; Search and Route do not pull in the map renderer.

| Package | Purpose |
| --- | --- |
| [glmap_core](packages/glmap_core/README.md) | SDK initialization, shared types, storage and downloads |
| [glmap](packages/glmap/README.md) | Map widget, camera, gestures, vector layers and drawings |
| [glsearch](packages/glsearch/README.md) | Text/category search, autocomplete and POI queries |
| [glroute](packages/glroute/README.md) | Road routing, custom routes, maneuvers and tracking |

## Contributing

See the [source guide](SOURCE.md) for package structure and API development, and
[VERIFICATION.md](VERIFICATION.md) for integration-test commands, test coverage
and contributor checks.

## Licensing

See [LICENSE](LICENSE) and the license file in each package. Native SDK and map-data
terms also apply; bundled map data is © OpenStreetMap contributors.
