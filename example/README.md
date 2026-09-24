# Flutter API demo

`lib/demo_main.dart` opens the catalog of **20 small API examples**, following the existing Swift and Kotlin demos. Each screen contains its own SDK calls in `lib/demo/`. Montenegro is bundled for offline map display and search.

## Run

Prepare the local SDK with GLMap, GLMapCore, GLSearch and GLRoute; see [setup and verification](../README.md). Then:

```sh
flutter pub get
flutter run -t lib/demo_main.dart -d <simulator-or-emulator-id>
```

Online SDK services need a suitable API key. Use the key button in the catalog for the current session, or an ignored `config/local.json` containing `{"GLMAP_API_KEY":"your-demo-key"}`:

```sh
flutter run -t lib/demo_main.dart -d <device-id> --dart-define-from-file=config/local.json
```

The app does not persist a key entered in the dialog. A build-time key is embedded in that build; use a demo key.

## Examples

| Source | Screens |
| --- | --- |
| `demo/map_examples.dart` | Online Map (vector/raster), Dark Theme, 3D Terrain, Fly To, Zoom to BBox |
| `demo/draw_examples.dart` | Image, Image Group, Markers & Clustering, Balloon, Track Arrows, User Location, Lines & Polygons, GeoJSON, GPS Track |
| `demo/search_examples.dart` | Search, POI Tap |
| `demo/routing_examples.dart` | Route Building, Turn-by-Turn Navigation |
| `demo/download_examples.dart` | Download Maps, Download BBox |

- **Search:** bundled Montenegro supports offline text/category search, autocomplete, markers and list selection. Switch to online to call the online SDK service.
- **Route Building:** tap a destination, long press a start point, choose car/bicycle/pedestrian, then build. Offline road routing requires downloaded navigation data. The sample passes `assets/valhalla.json` explicitly to the wrapper.
- **Turn-by-Turn:** starts with a clearly labeled custom route built by `GLRouteBuilder`, allowing reproducible tracker replay without network/data downloads. `Next position` feeds its coordinates to the native tracker. `Use GPS` starts foreground location updates; tapping the map requests a real online road route to that destination. This sample has no voice guidance, background service or automatic rerouting.
- **Downloads:** regional catalog/download/cancel/delete and fixed-area map/navigation/elevation downloads call GLMapManager. A valid key/network is needed. Completed BBox files are retained in the wrapper’s `glmap-areas` directory and re-registered during SDK initialization. Repeating the same bounds reuses the completed files; partial downloads are not installed. GPS permission is requested only after pressing `Use GPS`.
- **GeoJSON:** loads the native examples' UK postcode asset and uses native vector hit testing when tapped.

## Tests

```sh
flutter analyze
flutter test integration_test/demo_test.dart -d <device-id>
flutter drive -d <device-id> --driver test_driver/demo_driver.dart \
  --target integration_test/demo_test.dart --dart-define=DEMO_SCREENSHOTS=true
```

The driver saves screenshots under the example's `build/demo-screenshots` (override with `DEMO_SCREENSHOT_DIR`). The integration suite checks real native offline search/cancellation, route replay/cancellation, vector hit testing, and the 20-screen catalog. Authenticated services and fresh-process restoration have separate tests:

```sh
# Keep downloaded data for the following fresh-process test.
flutter test integration_test/online_test.dart -d <device-id> --no-uninstall \
  --dart-define-from-file=config/local.json
flutter drive -d <device-id> --driver test_driver/demo_driver.dart \
  --target integration_test/offline_restore_test.dart --keep-app-running \
  --dart-define-from-file=config/local.json --dart-define=DEMO_SCREENSHOTS=true
```

The online suite checks search, three route modes, BBox cancellation/download/cache reuse, region catalog/download/delete and transfer events. The restore test adds no bundled datasets and starts no downloads: it uses offline search/road routing, exercises the Route Building screen, and captures terrain from the retained files. These tests use explicit offline APIs; they do not put the device in airplane mode. Keep verbose authenticated logs in ignored `.artifacts/`, because native network messages can contain the API key.

Native input tests use the **normal demo entry point**:

```sh
# iOS: configure the entry point before Xcode builds it.
flutter build ios --simulator --debug --config-only -t lib/demo_main.dart
xcrun simctl location <simulator-id> set 42.4341,19.2600
xcrun simctl privacy <simulator-id> reset location software.globus.lab.glmapLabExample
xcodebuild -project ios/Runner.xcodeproj -scheme StageA \
  -destination 'platform=iOS Simulator,id=<simulator-id>' \
  -parallel-testing-enabled NO -only-testing:RunnerUITests/DemoCatalogTests \
  CODE_SIGNING_ALLOWED=NO test

# Android: use one emulator; feed location while the test runs.
adb -s emulator-5554 emu geo fix 19.2600 42.4341
cd android
ANDROID_SERIAL=emulator-5554 ./gradlew :app:connectedDebugAndroidTest \
  -Ptarget=lib/demo_main.dart \
  -Pandroid.testInstrumentationRunnerArguments.class=software.globus.lab.glmap_lab_example.DemoCatalogTest
```

Read `../VERIFICATION.md` for current outcomes and pending checks.

## Earlier lab entry points

`lib/main.dart` remains the Stage A embedding/gesture experiment; `lib/vector_main.dart` is the vector experiment. Their tests require those entry points. Run only the matching XCTest/UIAutomator class. See the [package README](../README.md) for prior reports.

Fixtures copied from the existing native examples: `Montenegro.vm`, `uk_postcodes.geojson`, `track-arrow.svg`. `valhalla.json` comes from the matching SDK’s `Resources/framework/valhalla.json`; the older reference-app config lacks fields required by the current routing engine. Map data is © OpenStreetMap contributors; existing SDK/data terms continue to apply.
