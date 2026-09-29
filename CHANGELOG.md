## Native SDK 2.2.0 release update

- Pin the published GLMap 2.2.0 native and SwiftPM revisions; use public Maven
  and SwiftPM artifacts for the plugins and demo.
- Document native rebuild requirements and add dependency-pin consistency checks.
- Keep Flutter package versions independent at `0.1.0-beta.1`. See
  [VERIFICATION.md](VERIFICATION.md) for checks against the release artifacts.

## 0.1.0-beta.1

- Provide four Flutter packages: `glmap_core`, `glmap`, `glsearch` and `glroute`.
- Add SDK initialization, bundled datasets, regional downloads and area downloads.
- Expose native map views, typed camera snapshots, gestures, vector layers and
  map-owned drawable handles.
- Support online/offline search, POI queries, road routing, custom routes and
  route tracking. Search and Route can be used without the map renderer.
- Include a 20-screen demo catalog and Android/iOS integration coverage for API
  behavior, cancellation, ownership and lifecycle handling.
- Open the shared catalog by default and keep lifecycle/vector samples on the
  public SDK API, with current Android/iOS application and test identities.
- Route map diagnostics through the generated Pigeon API, including disposal and
  late-reply handling.
- Target Android API 24+ and iOS 16.4+ with native SDK 2.2.0.
