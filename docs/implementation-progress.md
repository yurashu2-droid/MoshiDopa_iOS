# Native UI / PiP implementation progress

Branch: `codex/ios-native-ui-pip` (based on design commit `6e06410`).

## Current checkpoint

- Android baseline: all 480 recorded file hashes matched at implementation start.
- P1: XcodeGen 2.46.0, iOS 17, Swift 5, macOS 15 / Xcode 26.3 workflow authored; not yet run.
- P2A: Luna MAX implementing sample-data SwiftUI screens and copied Android artwork.
- P2B: Sol Mid delivered app-lifetime SessionService/SQLite/PiP sample frames and nine unit tests; parent source review is underway. Compilation and device behavior remain unverified.
- Parent: app entry, project, CI, XCTest UI routes, integration and review.

## Parent review checkpoint

- Rechecked all 480 Android baseline hashes and HEAD; no changes found.
- Reviewed the common amount calculation, monotonic elapsed time, frozen stop retry, SQLite recovery tests, and PiP sheet lifetime/restore handling.
- Added a UI integration test for actual foreground money increase, explicit stop/save, and saved-history visibility after app relaunch. This test does not assert background PiP behavior and has not yet run.
- Requested fixes for misleading Live Activity availability copy, missing display-surface previews, and incorrect tab destinations. These remain subject to rendered-image review.
- Integrated explicit receipt selection, period-aware history buckets, September/August fixtures for all story modes, and four distinct Live Activity preview surfaces. UI compilation and visual fidelity remain unverified.
- Sol Medium independently reviewed Core/Platform/tests/project/CI and found a PiP preparation failure path that retained the audio session when diagnostic logging threw. Parent fixed this with deferred audio cleanup in `ed3349d` and reviewed the error paths. Xcode tests have not run.
- Latest implementation checkpoint: `ed3349d` on local `codex/ios-native-ui-pip`. Repeated push attempts were rejected for missing workflow scope. Remaining acceptance work requires authorized GitHub workflow push and successful CI, followed by artifact download, parent image/video comparison, corrections, and rerun. Device-only PiP acceptance remains separately unverified.

## Evidence required before completion

CI dispatch checkpoint: local implementation commit `bb83b56` was created, but GitHub rejected the push because the current Git credential lacks `workflow` scope for `.github/workflows/ios-native.yml`. No native Actions run or artifact exists yet. The user has been asked to update the Git authentication; never treat the local commit as CI success.

- [ ] Successful native Simulator build and tests at a named commit/run.
- [ ] Successful unsigned iphoneos Release build and downloadable artifact.
- [ ] Actual PNGs / xcresult / motion video downloaded and reviewed by parent.
- [ ] UI references: home, history, settings, counter, receipt, statement, onboarding, whatif, measurement; empty/populated/large states.
- [ ] Navigation and meaningful state interactions verified.
- [ ] PiP core/tests reviewed; real device trial instructions and build ready.
- [ ] Device-only conditions clearly unverified if no device is available.

No App Store submission or main merge is included. Old Expo data remains untouched; migration is a later integration stage. Mock UI data must never enter the PiP store.
