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

## Evidence required before completion

- [ ] Successful native Simulator build and tests at a named commit/run.
- [ ] Successful unsigned iphoneos Release build and downloadable artifact.
- [ ] Actual PNGs / xcresult / motion video downloaded and reviewed by parent.
- [ ] UI references: home, history, settings, counter, receipt, statement, onboarding, whatif, measurement; empty/populated/large states.
- [ ] Navigation and meaningful state interactions verified.
- [ ] PiP core/tests reviewed; real device trial instructions and build ready.
- [ ] Device-only conditions clearly unverified if no device is available.

No App Store submission or main merge is included. Old Expo data remains untouched; migration is a later integration stage. Mock UI data must never enter the PiP store.
