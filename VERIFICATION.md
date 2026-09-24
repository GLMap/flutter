# Flutter SDK verification

## Reproduce the checks

Use the toolchain and dependency requirements in [README.md](README.md). Native
integration tests require an Android emulator/device or an iOS simulator/device;
they are not host-only Dart tests.

From the repository root:

```sh
flutter pub get
flutter analyze
python3 scripts/check-modules.py
```

Run the main integration suites from `example/` on each platform:

```sh
flutter test integration_test/demo_test.dart integration_test/api_test.dart \
  integration_test/vector_test.dart -d <device-id>
```

| Suite | Coverage |
| --- | --- |
| `demo_test.dart` | Demo catalog, bundled data, offline search, custom-route tracking, hit testing and drawable ownership |
| `api_test.dart` | Camera/state API, input validation, concurrent captures and map disposal isolation |
| `vector_test.dart` | Geometry retention, style updates, rejection, ordered updates and layer removal |
| `stage_a_test.dart` | Map embedding, overlays, navigation and repeated disposal |
| `vector_demo_test.dart` | Vector sample interactions |
| `online_test.dart` | Authenticated search, road routes, downloads and transfer events |
| `offline_restore_test.dart` | Reuse of downloaded data after a fresh process starts |

The commands below run from `example/`. See the [demo launch guide](README.md#run-the-demo)
for API-key configuration. Offline API coverage does not by itself demonstrate
operation with the device in airplane mode.

### Catalog screenshots

From `example/`, save catalog screenshots with:

```sh
flutter drive -d <device-id> --driver test_driver/demo_driver.dart \
  --target integration_test/demo_test.dart --dart-define=DEMO_SCREENSHOTS=true
```

The driver writes to `build/demo-screenshots`; set `DEMO_SCREENSHOT_DIR` to choose
another output directory.

### Authenticated services and restoration

These suites require an API key and network access for the initial downloads.
Run both on the same target, preserving app data between runs:

```sh
# Keep downloaded data for the following fresh-process test.
flutter test integration_test/online_test.dart -d <device-id> --no-uninstall \
  --dart-define-from-file=config/local.json
flutter drive -d <device-id> --driver test_driver/demo_driver.dart \
  --target integration_test/offline_restore_test.dart --keep-app-running \
  --dart-define-from-file=config/local.json --dart-define=DEMO_SCREENSHOTS=true
```

The online suite checks search, three route modes, area cancellation/download/cache
reuse, region catalog/download/delete and transfer events. The restore test adds
no bundled datasets and starts no downloads: it checks offline search and road
routing, exercises the Route Building screen, and captures terrain using retained
files. These tests use explicit offline APIs; they do not put the device in
airplane mode. Review logs before sharing them: native network messages may
contain the API key.

### Native gestures and location

Use `lib/demo_main.dart` for the native demo input tests. On iOS, configure the
entry point before running the included UI test scheme:

```sh
flutter build ios --simulator --debug --config-only -t lib/demo_main.dart
xcrun simctl location <simulator-id> set 42.4341,19.2600
xcodebuild -project ios/Runner.xcodeproj -scheme StageA \
  -destination 'platform=iOS Simulator,id=<simulator-id>' \
  -parallel-testing-enabled NO -only-testing:RunnerUITests/DemoCatalogTests \
  CODE_SIGNING_ALLOWED=NO test
```

On Android, select the included `DemoCatalogTest` instrumentation class in Android
Studio and set the Flutter entry point to `lib/demo_main.dart` (Gradle property
`target`). Feed the emulator's location while the test runs:

```sh
adb -s <emulator-id> emu geo fix 19.2600 42.4341
```

Run only the input test class matching the entry point. Allow foreground location
access when prompted. See [recorded results](#recorded-results) for outcomes and
remaining device/service checks.

### Headless module checks

`scripts/check-modules.py` checks declared package dependency boundaries. For
runtime coverage, generate separate Core-only, Search-only and Route-only apps:

```sh
python3 scripts/create-headless-probes.py
```

The apps are created under ignored `build/module-probes/{core,search,route}/`.
From each generated app, run this on Android and iOS:

```sh
flutter test integration_test/probe_test.dart -d <device-id>
```

Inspect the resulting APK/framework list as well: a successful run alone does not prove that unused native libraries were
excluded. Expected GLMap libraries are Core alone, Core + Search, or Core + Route;
none of these apps should include the Map renderer.

## Recorded results

The verification summary dated **2026-09-24** records the following results.
See [tests/results/](tests/results/README.md) for the saved evidence and scope of
these runs.

| Check | Recorded outcome |
| --- | --- |
| Android integration | 8/8 tests passed: 4 demo, 2 API/lifecycle, 2 vector |
| iOS integration | 8/8 tests passed: 4 demo, 2 API/lifecycle, 2 vector |
| Core/Search/Route headless apps | Passed on Android and iOS without the Map renderer |
| Headless native library inspection | Only Core and the selected service were present |
| iOS device Release build | Built without signing; this is not a signed installation or device test |
| Dart analysis | Reported clean |
| Package publication dry-runs | Reported zero warnings for all four packages |

The saved integration logs do not identify the target devices. Their pass counts
do not establish signed physical-device coverage; record the target type explicitly
when repeating these suites.

## Release validation

For each SDK release:

- Check native dependency resolution from the public Maven and Swift Package
  Manager repositories with a fresh checkout and the pinned SDK version.
- Run API, lifecycle and module-isolation checks against the release artifacts.
- Validate signed installations on physical Android and iOS devices.
- Run authenticated services and fresh-process offline restoration; report these
  separately from bundled-data tests.
- Review store/privacy requirements and package metadata.
- Check package publication settings and approval. Publish Core before its three
  consumers, which declare compatible `^0.1.0-beta.1` constraints.

Record the command, revision, toolchain, target type, outcome and limitations for
new results. Remove credentials and workstation paths from shared logs. Never
present an unsigned build, a simulator run or a pub dry-run as a deployed release.
