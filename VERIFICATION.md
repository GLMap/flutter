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
python3 scripts/check-example.py
python3 scripts/check-vector-api.py
(cd example && flutter test test)
```

Run the main integration suites from `example/` on each platform:

```sh
flutter test integration_test/demo_test.dart integration_test/api_test.dart \
  integration_test/vector_test.dart integration_test/lifecycle_test.dart \
  integration_test/vector_demo_test.dart -d <device-id>
```

| Suite | Coverage |
| --- | --- |
| `demo_test.dart` | Demo catalog, bundled data, offline search, custom-route tracking, hit testing and drawable ownership |
| `api_test.dart` | Camera/state API, input validation, concurrent captures and map disposal isolation |
| `vector_test.dart` | Geometry retention, style updates, rejection, ordered updates and layer removal |
| `lifecycle_test.dart` | Public map embedding, overlays, navigation, repeated disposal and stale diagnostics/capture rejection |
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

Both native input suites use the default catalog entry, `lib/main.dart`.
`LifecycleViewTests` / `LifecycleViewTest` open **Lifecycle sample** from the
catalog toolbar; the catalog tests exercise drawings and foreground location.
On iOS, configure the default entry before running the UI test scheme:

```sh
flutter build ios --simulator --debug --config-only
xcrun simctl location <simulator-id> set 42.4341,19.2600
xcodebuild -project ios/Runner.xcodeproj -scheme DemoTests \
  -destination 'platform=iOS Simulator,id=<simulator-id>' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  CODE_SIGNING_ALLOWED=NO test
```

The standard `Runner` scheme also includes the Swift `RunnerTests` unit tests.
They check registration of the actual map plugin and its platform-view creation
codec; they do not call a placeholder platform-version API.

On Android, run `DemoCatalogTest` and `LifecycleViewTest` from the generated app
build using the default Flutter entry. Both test classes belong to
`software.globus.glmap.flutter.demo`. Feed the emulator's location while the
catalog location test runs:

```sh
adb -s <emulator-id> emu geo fix 19.2600 42.4341
```

Allow foreground location access when prompted. Input tests use native gestures,
not synthetic Dart tap callbacks. See [recorded results](#recorded-results) for
actual target types and service/device coverage.

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

## Published GLMap 2.2.0 validation — 2026-09-29

The native release is now pinned to `36a343f9275d76734466ecae1f39b9c0e0655a8b`
and SwiftPM tag `2.2.0` resolves to `b07267c4bdd7cfcde5e001708c95d897eaa2f19a`.
The following checks used public Maven/SwiftPM artifacts with `GLMAP_SDK_DIR`
unset, not the earlier `2.2.0-dev.*` builds. See
[release-2.2.0.json](tests/results/release-2.2.0.json) for the run summary:

- `flutter pub get`, `flutter analyze`, module/pin, example and vector-call-site
  checks passed. Both host widget/channel tests passed (**2/2**).
- Android 17 arm64 emulator: all five integration suites listed above passed
  (**10/10**), including all 20 catalog screens, API, vector and lifecycle checks.
- iPhone 17 / iOS 27.0 arm64 simulator: the same suites passed (**10/10**), run as
  API/lifecycle/vector (**5/5**) and catalog/vector-demo (**5/5**).
- Both vector suites observed superseded updates and cancellation on removal.
- The demo's SwiftPM lockfiles record the public release revision. Native
  dependency consistency is checked by `scripts/check-modules.py`.
- Packaged Android ELF build IDs and iOS simulator framework UUIDs matched the
  public 2.2.0 artifacts. Android `world.vm` remained uncompressed; published
  vector headers/classes expose the required status-bearing completion API.

These are Debug emulator/simulator runs from this workspace, not clean-checkout,
signed physical-device or authenticated-service validation. No new headless-app,
full native-gesture, device Release or offline-restoration run is claimed. Prior
results below remain historical evidence for their original dev SDK versions;
references there to matching pins refer to the pins at the time of those runs.

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

### Catalog and channel cleanup validation

The cleanup was checked on **2026-09-25**. The
[run summary](tests/results/flutter-demo-cleanup.json) records the tested source
fingerprint, toolchain, commands and target types.

| Check | Outcome |
| --- | --- |
| Dart analysis, package boundaries and example identity checks | Passed |
| Host widget/channel tests | 2/2, including default entry and diagnostics disposal/late replies |
| Pigeon regeneration | Dart/Kotlin/Swift generated together; repeated generation and formatting produced identical output |
| Android integration suites | 10/10 on an arm64 Android 14 emulator |
| iOS integration suites | 10/10 on an arm64 iPhone 17 / iOS 27.0 simulator |
| Catalog coverage | All 20 screens opened, performed their bundled/offline actions and closed on both platforms |
| Android native input tests | 2/2 through AndroidJUnitRunner using the Gradle-built Debug app/test APKs |
| iOS native input tests | 5/5 through the `DemoTests` scheme |
| iOS registration unit tests | 2/2 through `Runner`, testing the actual linked plugin and creation codec |
| Android Release APK | Built; this is not a separate Release runtime suite |
| iOS device Release app | Built without signing; not installed or run on a physical device |
| Native identities and Core resources | Android Debug/Release build IDs and iOS simulator/device framework UUIDs/resources matched the selected SDK |
| Documentation and whitespace checks | Passed |

Native validation used prebuilt `2.2.0-dev.515481f9f` artifacts through an explicit
local override. Native and Swift package revisions matched `native-sdk.json`, and
neither the native pin nor the dependency lock changed. These runs do not validate
public Maven/SwiftPM release resolution. Location tests used injected emulator or
simulator positions, not physical GPS or authenticated online services.

Earlier Android UI attempts exposed assumptions in the input harness: it checked
the resumed semantics tree too early, and its generic pinch path could intersect
Flutter controls or stay below the native gesture threshold. The final harness
waits for the current screen, keeps both fingers on the native map, and checks an
actual zoom increase. A separate attempt lost its emulator before test execution;
the final two tests ran directly with AndroidJUnitRunner on a fresh emulator.

A Release build immediately after integration testing encountered a stale generated
plugin registrant with a Debug-only integration-test plugin. Running the normal
build with dependency/plugin refresh regenerated it and the build passed; no
generated registrant was hand-edited. Non-fatal toolchain warnings remain.
No signed physical-device, authenticated-service, downloaded-data restoration or
new standalone headless runtime checks are claimed for this change.

### Unified native vector completions

The status-bearing `setVectorObject(s)` API was validated on **2026-09-25** with
native SDK `2.2.0-dev.05553b111`. The native/Swift revisions are recorded in
`native-sdk.json`; [vector-status.json](tests/results/vector-status.json) records
the tested source fingerprint and artifact provenance. The Android call uses
`setVectorObjects(..., UpdateCompletion)`, and Apple uses `completion:` with a
`GLMapVectorLayerUpdateResult`. Flutter preserves all four terminal outcomes.

- Android 14 arm64 emulator: **10/10** integration scenarios passed, including
  concurrent vector updates, supersession, removal cancellation and disposal.
- iPhone 17 / iOS 27.0 arm64 simulator: the same **10/10** scenarios passed.
- Dart analysis, host widget/channel tests, module/example checks and the new
  `scripts/check-vector-api.py` check passed. The API check also inspected the
  actual packaged Android class and Apple headers, not only wrapper source.
- Android and iOS simulator native IDs and Core resources matched the newly built
  SDK artifacts. Native SDK libraries were built for Android and Apple simulator/
  device; this is not a new signed device run or wrapper-device-build claim.

The native SDK was built with its existing working-tree delta, recorded by the
SDK manifest hash in the result. No native source was edited for this wrapper
migration. These local-artifact runs do not establish public dependency resolution,
authenticated-service coverage, headless runtime coverage or new full UI coverage.
Earlier results above retain their original SDK/version scope.

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
