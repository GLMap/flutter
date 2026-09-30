# Repository guidance

## Scope and structure

This repository provides Flutter bindings for Android and iOS. Keep changes focused
on the public Dart API, platform bridges, examples and tests.

- `glmap_core` owns initialization, shared types, storage and downloads.
- `glmap`, `glsearch` and `glroute` depend on Core, not on one another.
- Search and Route must remain usable without a map widget or renderer.
- Keep public API documentation and examples in sync with behavior changes.
- The default example entry opens the shared catalog. Lifecycle and vector samples
  use the public SDK and remain available as explicit entry points.

## Implementation and checks

- Edit channel definitions in each package's `pigeons/` directory, then regenerate
  Dart, Kotlin and Swift bindings together. Do not hand-edit generated bindings.
- Preserve ownership and cancellation rules for map controllers, drawables,
  queries and routes. Test removal, repeated disposal and concurrent operations.
- Use the native dependency versions recorded in `native-sdk.json`; do not
  silently substitute older releases or add machine-specific paths.
- Run `flutter analyze`, `python3 scripts/check-modules.py`,
  `python3 scripts/check-example.py`, `python3 scripts/check-vector-api.py`
  and the host tests in `example/test/`.
  Re-run the relevant Android and iOS integration suites for API or platform
  changes, and the API and lifecycle suites whenever the native dependency
  version changes.
- Report checks actually performed in the chat, not in committed release reports.
  Distinguish host tests, emulator/simulator runs, unsigned device builds,
  signed physical-device runs and authenticated service tests.

## Documentation and repository hygiene

Write installation and usage documentation for the published SDK: use pub.dev
packages and public native dependency repositories. Keep temporary publication
status and release-preparation workarounds out of user guides. Do not refer to
internal projects, private source checkouts, workstation paths or development
history. Do not infer successful checks from publication status.

Do not commit credentials, native SDK binaries or generated platform builds.
Review test logs before sharing them; remove API keys and machine-specific paths.
Do not publish packages, create remotes or change distribution licenses without
approval.
