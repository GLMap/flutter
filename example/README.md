# GLMap demo code guide

The demo is a catalog of **20 Flutter API examples** for Android and iOS. Each
screen keeps its SDK calls close to its UI so you can find a feature, read the
implementation and adapt it to your app.

For requirements, launch commands and API-key setup, see
[Run the demo](../README.md#run-the-demo). The default **`lib/main.dart`** opens the
catalog on both platforms. `lib/demo_main.dart` contains its implementation and
also remains directly runnable.

## Native SDK release

Both hosts use the published GLMap **2.2.0** artifacts through the workspace
plugins: Maven on Android and exact-version SwiftPM on iOS. After updating the
checkout, run `flutter pub get` from the repository root and rebuild the demo;
hot reload is not enough to replace native binaries. No separately built native
SDK is required. The API, vector and lifecycle suites are described in
[VERIFICATION.md](../VERIFICATION.md).

## Directory structure

```text
example/
├── lib/
│   ├── demo_main.dart            # SDK startup, app theme and screen catalog
│   ├── demo/
│   │   ├── common.dart           # Shared map-screen layout and small helpers
│   │   ├── map_examples.dart     # Map display, themes, terrain and camera
│   │   ├── draw_examples.dart    # Images, markers, vectors, tracks and location
│   │   ├── search_examples.dart  # Search UI and map-object picking
│   │   ├── routing_examples.dart # Route building and navigation tracking
│   │   └── download_examples.dart # Regional and bounding-box downloads
│   ├── main.dart                 # Default entry: starts the catalog
│   ├── lifecycle_main.dart       # Focused embedding and lifecycle sample
│   └── vector_main.dart          # Focused vector-layer sample
├── assets/                       # Bundled datasets and sample geometry/config
├── integration_test/             # Flutter tests using the native plugins
├── test_driver/                  # Integration driver and screenshot output
├── android/                      # Android host, permissions and input tests
├── ios/                          # iOS host, permissions and input tests
└── pubspec.yaml                  # Flutter dependencies and asset declarations
```

The repository's Dart workspace resolves the four SDK packages from `../packages/`.
The demo calls their public Dart APIs; native bridge implementations belong to
those packages, not to the demo's platform host directories.

## Startup and screen lifecycle

1. [`main.dart`](lib/main.dart) forwards to the catalog implementation in
   [`demo_main.dart`](lib/demo_main.dart), which initializes Flutter and calls
   `GLMapSDK.initialize` with `GLMAP_API_KEY` from the build environment.
2. It registers `assets/Montenegro.vm` with `GLMapSDK.addAssetDataSet` for offline
   map display and search. An initialization failure is shown in the catalog.
3. `DemoApp` builds the Material theme. `DemoCatalog` filters the `demos` list of
   `DemoEntry` objects and opens the selected screen with Flutter navigation.
   The key button reapplies SDK initialization with a session-only API key.
4. Most map screens extend `MapDemoState` in [`common.dart`](lib/demo/common.dart).
   It creates the `GLMap` widget, stores the controller, subscribes to taps and
   invokes `ready(controller)`. A screen supplies `title`, `api`, `controls()`
   and, when needed, `tapped()`.
5. `MapDemoState.run()` shows busy/error state around asynchronous operations.
   The base class cancels its tap subscription on disposal. Individual screens
   cancel their own requests, timers and GPS/download subscriptions; route
   screens also close retained routes. The map widget owns its controller and
   drawable handles, which become invalid when it is removed.

`common.dart` also holds sample coordinates around Podgorica, pin-image and
GeoJSON helpers, and `foregroundPositions()` for permission-checked location
updates. Feature-specific SDK operations stay in each screen implementation.

## Where to find each feature

Paths below are relative to `lib/demo/`.

| Source | Catalog screens |
| --- | --- |
| [map_examples.dart](lib/demo/map_examples.dart) | Online Map, Dark Theme, 3D Terrain, Fly To, Zoom to BBox |
| [draw_examples.dart](lib/demo/draw_examples.dart) | Image, Image Group, Markers & Clustering, Balloon, Track Arrows, User Location, Lines & Polygons, GeoJSON, GPS Track |
| [search_examples.dart](lib/demo/search_examples.dart) | Search, POI Tap |
| [routing_examples.dart](lib/demo/routing_examples.dart) | Route Building, Turn-by-Turn Navigation |
| [download_examples.dart](lib/demo/download_examples.dart) | Download Maps, Download BBox |

Notable implementation details:

- **Search** combines offline/online queries, debounced autocomplete, cancellation,
  markers and list selection. The bundled data covers Montenegro.
- **POI Tap** uses Search's map-object picking API on the map controller.
- **Route Building** accepts a tap for the destination and a long press for the
  start, then requests a car/bicycle/pedestrian route. Offline road routing needs
  downloaded navigation data and the configuration in `assets/valhalla.json`.
- **Turn-by-Turn Navigation** starts with a custom route from
  `GLRouteSDK.buildRoute`. `Next position` replays coordinates into the native
  tracker without downloads; `Use GPS` enables foreground updates. A map tap
  requests an online road route. This is a tracking example, not a complete
  navigation app: it has no voice guidance, background service or automatic
  rerouting.
- **Downloads** show Core's regional catalog, progress events, cancellation,
  deletion and area downloads. The SDK retains completed area files in the app's
  `glmap-areas` directory and re-registers them during initialization. Repeating
  the same bounds reuses completed files; partial downloads are not installed.
- **User Location / GPS Track** share `LocationDemo`; the catalog uses
  `LocationDemo(record: true)` for track recording. GPS permission is requested
  only after the user presses `Use GPS`.
- **GeoJSON** loads the UK postcode asset and uses native vector hit testing.

## Assets and focused samples

Assets are declared in [`pubspec.yaml`](pubspec.yaml):

| Asset | Use |
| --- | --- |
| `Montenegro.vm` | Offline map display and search in the catalog; not navigation or elevation data |
| `valhalla.json` | Configuration for offline road-routing requests |
| `uk_postcodes.geojson` | Geometry for the GeoJSON screen |
| `track-arrow.svg` | Arrow image for the Track Arrows screen |
| `stage-a.json` | Shared fixture for the focused map and vector samples |

Keep routing configuration compatible with the native SDK. Map data is
© OpenStreetMap contributors; native SDK and data terms also apply.

[`lib/lifecycle_main.dart`](lib/lifecycle_main.dart) demonstrates embedding,
Flutter overlays, navigation and repeated map removal. Open it with the catalog's
**Lifecycle sample** toolbar action or `flutter run -t lib/lifecycle_main.dart`.
[`lib/vector_main.dart`](lib/vector_main.dart) demonstrates vector geometry/style
updates and can be run with its own `-t` entry point.

Both samples initialize Core when launched directly and draw through the public
controller API. Opening the lifecycle screen from the catalog reuses its initialized
SDK and session key. There is no separate native demo renderer. The app name is
**GLMap Flutter Demo**, its Dart package is `glmap_example`, and its Android/iOS
application identifier is `software.globus.glmap.flutter.demo`.

## Add or change an example

1. Put the screen in the matching `lib/demo/*_examples.dart` file. For a standard
   map screen, extend `MapDemoState` and keep the SDK calls in the screen itself.
2. Add a `DemoEntry` to `demos` in `demo_main.dart` so the catalog can display it.
3. Register any new bundled assets in `pubspec.yaml`.
4. Cancel screen-owned work on disposal and close any retained routes. Handle
   asynchronous results arriving after the screen has been removed.
5. Update this guide and the matching integration tests. If adding a screen,
   update the catalog's displayed example count too.

## Tests

`integration_test/demo_test.dart` covers the catalog. `api_test.dart` and
`vector_test.dart` exercise native API and lifecycle behavior. The focused entry
points have `lifecycle_test.dart` and `vector_demo_test.dart`; authenticated services
and retained downloads have `online_test.dart` and `offline_restore_test.dart`.

See [VERIFICATION.md](../VERIFICATION.md) for test commands, screenshot capture,
platform input tests and the required ordering of online/restoration suites.
These tests require an Android or iOS target. Never share API keys or unreviewed
authenticated logs.
