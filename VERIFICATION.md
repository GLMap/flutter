# Standalone extraction verification — 2026-09-24

Native baseline: **b5ed76b9b68d5651f1eb78f317dcc6fcc93cceb3**, current GLMap `dev`.
Native Release artifacts use the local version `2.2.0-dev.b5ed76b9b`; the framework
bundle's old version string is not their identity. `tests/results/artifacts.json`
records ELF build IDs and Apple UUIDs checked against the prepared SDK.

| Check | Actual result |
| --- | --- |
| Flutter analysis | Pass, no issues |
| Android Release APK | Pass |
| iOS Release device app, no signing | Pass |
| iOS simulator build | Pass, universal native simulator SDK |
| Android emulator integration | **8/8**: demo 4, camera/lifecycle 2, vectors 2 |
| iPhone 17 / iOS 27 simulator integration | **8/8**, same suites |
| iOS demo after initialization-result handling | **4/4** repeated |
| Catalog coverage in those tests | All 20 screens and their offline actions |
| Pub package validation (`--dry-run`) | 0 warnings; no package was uploaded |
| Fresh Flutter app consuming a path dependency | Android Release builds |

The fresh consumer was generated with `flutter create` outside this repository;
it uses only the documented Maven repository/noCompress setup and explicit SDK
override. No old lab paths or JNI/FFI benchmark code are required. Initial extraction
caught and corrected a missing explicit `meta` dependency and the arm64-only SDK's
failure to satisfy Flutter's default universal simulator build. Native SDK preparation
now builds arm64+x86_64 simulator frameworks plus arm64 device frameworks.

Full local logs are under ignored `build/verification/`. Concise test output and
artifact identities are retained under `tests/results/`. Builds using the same
Flutter example must run sequentially: Flutter regenerates shared plugin registrants
when switching between integration tests and Release mode.

## Not established by these runs / release gates

- Native 2.2.0 Maven/SwiftPM publication and clean resolution without the local override.
- Signed iPhone install/TestFlight, physical-device GPU/gesture/memory/performance checks.
- A new authenticated network/download/offline-relaunch run on this exact dev baseline.
- Store privacy/compliance review, public naming/license approval and registry publication.

`publish_to: none` remains deliberately set. Keys, compiled artifacts and historical
lab build caches were not imported. Nothing was published remotely.
