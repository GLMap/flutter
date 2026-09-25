# Verification evidence

See [VERIFICATION.md](../../VERIFICATION.md) for test commands, recorded results
and the release-validation procedure.

## Contents

- [vector-status.json](vector-status.json): unified native vector completion API,
  current SDK/source identities and Android/iOS API/lifecycle validation.

- [flutter-demo-cleanup.json](flutter-demo-cleanup.json): current catalog/channel
  cleanup validation, with source fingerprint, build/test commands and explicit
  emulator/simulator/device-build distinctions.
- `android-integration.txt` and `ios-integration.txt`: earlier saved output from
  the demo, API/lifecycle and vector integration suites.
- `headless-android-*.txt` and `headless-ios-*.txt`: Core-only, Search-only and
  Route-only test output.
- `headless-android-libraries.json` and `headless-ios-frameworks.json`: recorded
  native library lists for those minimal applications.
- `artifacts.json` and `source-sha256.json`: saved artifact/source identities.
  Regenerate these records for each tested build; a version string alone does
  not identify the tested binary.

The saved logs describe individual test runs. Some output is abbreviated; use
the recorded pass counts only for the suites shown, not as evidence for
authenticated services or signed device deployment.

## Adding results

Record the tested revision, command, toolchain, platform and target type. Mark
emulator/simulator tests, unsigned device builds, signed physical-device runs and
authenticated service tests separately. Explain skipped checks and unavailable
dependencies instead of treating them as passed.

Keep generated apps and full working logs under ignored `build/`. Before sharing
a summary, remove API keys, personal paths and links to unavailable logs. Do not
commit credentials or unreviewed authenticated network output.
