# GLMap for Flutter

Native GLMap views, camera snapshots, vector layers, drawables, offline data,
search and routing for Android and iOS. Local beta preparation; **not published**.
Native SDK baseline and intended release version are recorded in `native-sdk.json`.
The released GLMap 2.1.0 is not compatible with this wrapper.

## Requirements

Flutter 3.47.4 / Dart 3.13.3; Android API 24+, compile SDK 36, Java 17;
iOS 16.4+, Xcode and Flutter SwiftPM integration. iOS uses SwiftPM, not CocoaPods.
The library contains no JNI/FFI benchmark adapter or NDK build requirement.
GLMap binaries retain their vendor license.

## Native SDK while 2.2.0 is unpublished

Build the recorded `dev` revision (or a deliberately selected newer revision):

```sh
python3 scripts/prepare-native-sdk.py --sdk-root /path/to/glmap --output /path/to/prepared-sdk
export GLMAP_SDK_DIR=/path/to/prepared-sdk
```

The script builds Release AARs including **Core**, and both iOS device and arm64
simulator slices, retaining native POM dependencies and recording binary hashes.
Pass the same environment to Flutter and Xcode. No binaries or keys belong in Git.
After native publication, unset `GLMAP_SDK_DIR`: Maven and SwiftPM resolve exact
GLMap 2.2.0. Do not fall back to 2.1.0. The override is explicit, not a sibling path.

## Example and integration

```sh
cd example
flutter pub get
flutter run -t lib/demo_main.dart -d <device>
```

For a different app, use a Git/path dependency on this repository and import
`package:glmap_flutter/glmap_flutter.dart`. Keep `publish_to: none` until release approval.
Add the GLMap Maven repository to the host's repository configuration:
`https://maven.globus.software/artifactory/libs`. With a local native override also add
`${GLMAP_SDK_DIR}/maven`. The example shows this configuration. Use `noCompress` for
`vm`, `ttf`, `otf` assets; the host owns network/location permissions.

```dart
await GLMapSDK.initialize(apiKey: yourKey);
GLMap(onCreated: (map) async {
  await map.setCamera(latitude: 42.4341, longitude: 19.26, zoom: 12);
  final camera = await map.captureState();
});
```

`initialize` calls the current Android SDK's central initializer and reports failure;
there are no independent Map/Search/Route library loaders in the wrapper.
Search/download services do not require a map. Map-owned handles cannot transfer
between maps; removing their widget rejects pending calls with `map_disposed`.
Vector requests return `ready`, `superseded`, `cancelled`, or `failed`; `ready` means
installed batches, not frame presentation. Packed coordinates are `[longitude, latitude]`.
Await dependent commands; separate Pigeon methods do not imply a single FIFO.

The example has 20 feature screens. Offline data is included for the example;
authenticated services require your key. Configure it locally as described in the
example, never in a committed source file. Background navigation, voice guidance
and automatic rerouting are outside this example's scope.

## Verification

```sh
flutter analyze
cd example
flutter test integration_test/demo_test.dart -d <device>
flutter test integration_test/api_test.dart -d <device>
flutter test integration_test/vector_test.dart -d <device>
flutter build apk --release -t lib/demo_main.dart
flutter build ios --release --no-codesign -t lib/demo_main.dart
```

See `VERIFICATION.md` for actual results and remaining release gates.
Generated Pigeon code is committed; regenerate from `pigeons/map.dart` and
`pigeons/features.dart`. Historical transport benchmarks remain in the original
lab and are deliberately not shipped in this package. See `SOURCE.md` for provenance.
