# Source guide

## Package layout

| Directory | Responsibility |
| --- | --- |
| `packages/glmap_core/` | SDK initialization, datasets, downloads and shared types |
| `packages/glmap/` | Map widget, camera, gestures, vectors and drawing handles |
| `packages/glsearch/` | Search requests and map-object queries |
| `packages/glroute/` | Road routing, custom routes and navigation state |
| `example/lib/demo/` | Runnable examples of the public Flutter API |
| `example/integration_test/` | Native API and lifecycle integration tests |
| `tests/results/` | Recorded verification summaries and evidence |

Each package exposes its public Dart API from `lib/<package>.dart`. Channel
schemas live in `pigeons/`, generated Dart channels in `lib/src/`, Android bridge
implementations in `android/src/main/kotlin/`, and iOS bridge implementations under
`ios/<package>/Sources/`.

The native dependency baseline is recorded in [native-sdk.json](native-sdk.json).
See the [requirements](README.md#requirements) for supported platforms and the
[host setup](README.md#2-configure-the-native-host) for native dependency
configuration. Native SDK source and binaries are not part of the Flutter
workspace.

## Dependency boundaries and lifetime

Core is the only shared package dependency. Map does not import Search or Route,
and both services must work without a map widget.

- `GLMapQueryTarget` lets Search query a map without depending on the Map package.
  Importing Search provides the `pickObject` extension.
- `GLMapTrackSource` allows Map to draw retained route geometry without depending
  on the Route package or rebuilding it from returned coordinates.
- `GLMapController` and drawing handles are owned by their map widget. Removal
  must settle pending operations and reject subsequent use of invalid handles.
- `captureState()` returns a snapshot, not an object that follows future camera
  changes. Await a camera command before capturing when ordering matters.
- Cancellable service calls return a `GLMapRequest<T>` with `result` and
  `cancel()`. Callers should handle completion or failure even after cancellation.
- `GLMapRoute` retains native state until `close()`; release it when finished.

Swift implementation targets use distinct names such as `GlobusMapFlutter`.
Small Objective-C registration targets expose Flutter's module names without
colliding with native SDK modules on case-insensitive filesystems. Keep these
registration targets separate when updating iOS bridges.

## Change a channel API

1. Update the public Dart wrapper and the corresponding schema in `pigeons/`.
2. Regenerate bindings from that package's directory. For example:

   ```sh
   cd packages/glmap
   dart run pigeon --input pigeons/map.dart
   dart run pigeon --input pigeons/features.dart
   ```

   The other schemas are `packages/glmap_core/pigeons/core.dart`,
   `packages/glsearch/pigeons/search.dart` and `packages/glroute/pigeons/route.dart`.
   Run Pigeon from the owning package directory so output paths remain correct.
3. Update both Android and iOS implementations. Generated channel types are
   implementation details, not the public Dart API.
4. Add an example or test covering the behavior, including error handling,
   cancellation and disposal where relevant.
5. From the repository root, run `flutter analyze` and
   `python3 scripts/check-modules.py`, then the relevant Android and iOS suites
   described in [VERIFICATION.md](VERIFICATION.md).

Commit the schema and regenerated Dart/Kotlin/Swift files together. Do not edit
generated bindings by hand. Native dependency changes require renewed API and
lifecycle validation on both platforms.
