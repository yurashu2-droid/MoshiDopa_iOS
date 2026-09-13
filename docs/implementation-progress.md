# Native UI / PiP implementation progress

Branch: `codex/ios-native-ui-pip` (based on design commit `6e06410`).

## Current checkpoint

- Android baseline: all 480 recorded file hashes matched at implementation start.
- P1: XcodeGen 2.46.0, iOS 17, Swift 5, macOS 15 / Xcode 26.3 workflow executing; no successful native build confirmed yet.
- P2A: Luna MAX delivered sample-data SwiftUI screens and copied Android artwork; parent integrated review fixes. Rendered comparison is pending CI artifacts.
- P2B: Sol Mid delivered app-lifetime SessionService/SQLite/PiP sample frames and nine unit tests; parent source review is underway. Compilation and device behavior remain unverified.
- Parent: app entry, project, CI, XCTest UI routes, integration and review.

## Parent review checkpoint

- Rechecked all 480 Android baseline hashes and HEAD; no changes found.
- Reviewed the common amount calculation, monotonic elapsed time, frozen stop retry, SQLite recovery tests, and PiP sheet lifetime/restore handling.
- Added a UI integration test for actual foreground money increase, explicit stop/save, and saved-history visibility after app relaunch. This test does not assert background PiP behavior and has not yet run.
- Requested fixes for misleading Live Activity availability copy, missing display-surface previews, and incorrect tab destinations. These remain subject to rendered-image review.
- Integrated explicit receipt selection, period-aware history buckets, September/August fixtures for all story modes, and four distinct Live Activity preview surfaces. UI compilation and visual fidelity remain unverified.
- Sol Medium independently reviewed Core/Platform/tests/project/CI and found a PiP preparation failure path that retained the audio session when diagnostic logging threw. Parent fixed this with deferred audio cleanup in `ed3349d` and reviewed the error paths. Xcode tests have not run.
- The user completed Git authentication and the branch was pushed. Remaining acceptance work requires successful native CI, artifact download, parent image/video comparison, corrections, and rerun. Device-only PiP acceptance remains separately unverified.

## Evidence required before completion

CI dispatch checkpoint: authentication blocker resolved. [Initial run 34779188320](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34779188320) at `c594cad` incorrectly skipped native verification because the filter inspected only the final documentation commit. This is **not** a successful native build. Parent corrected the filter to inspect the full push and new branches in `dd3678f`. [Run 34779218511](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34779218511) is executing native verification; results pending.

- [ ] Successful native Simulator build and tests at a named commit/run.
- [ ] Successful unsigned iphoneos Release build and downloadable artifact.
- [ ] Actual PNGs / xcresult / motion video downloaded and reviewed by parent.
- [ ] UI references: home, history, settings, counter, receipt, statement, onboarding, whatif, measurement; empty/populated/large states.
- [ ] Navigation and meaningful state interactions verified.
- [ ] PiP core/tests reviewed; real device trial instructions and build ready.
- [ ] Device-only conditions clearly unverified if no device is available.

No App Store submission or main merge is included. Old Expo data remains untouched; migration is a later integration stage. Mock UI data must never enter the PiP store.

## CI review: run 34779516989

At `fa280ad`, the Simulator app compiled and all nine core tests passed. Three of seven UI tests passed; four failed. This run is not accepted as successful CI, and the device build was skipped.

Parent downloaded the xcresult and attachments. Accessibility dumps show receipt/onboarding screen identifiers on ScrollView rather than Other; tests now query identifiers across element types. Real foreground money increased; the saved history row was below the lazy List viewport, so the test now scrolls to check it before and after relaunch.

Parent inspected the home screenshot: missing wordmark, mascots and paper texture. Runtime logs confirm named-image lookup failures. The unchanged PNG artwork is now packaged into named asset-catalog image sets. Visual acceptance awaits a new rendered comparison.

PiP delegate callbacks now use a lock-protected playback snapshot for synchronous queries and main-actor tasks for UI state. Tests and device concurrency behavior require rerun. CI now attempts screenshots after test failures and independently attempts the unsigned device build, preserving failed test status.

## Parent visual correction and next CI

Previous turn made concrete progress: named artwork moved to catalogs, failing UI queries corrected and evidence handling improved. Run [34780290813](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34780290813) at `1d8fed7` then failed compilation because the newly introduced catalog lacked Xcode's default AppIcon set. No tests or visual acceptance are claimed for that run. Added the Android icon source unchanged and a macOS build-time sizing step, documented for local builds as well as CI.

Parent compared the actual Android home and iOS home/settings PNGs from run 34779516989. Home corrections: explicit wordmark size, integer floor amount as Android, proportional heavy digits, amount-bound available width, corrected tagline, tape and marker, side-by-side icon/text start cards, recent receipts before secondary demo links. Shared corrections: thinner navigation, fine deterministic paper edges and visible background/card fibre texture. These edits still require rendered verification. Added a hosted test that loads representative artwork by the runtime names that previously failed. Android's 480 recorded hashes and HEAD were rechecked unchanged.

Luna MAX refined only the settings top-level hierarchy and sizing; parent reviewed the diff and required the sample annotation and “値札の設定” terminology to remain. Parent verified Android MainActivity bottom navigation targets `home/history/settings`, corrected native measurement-tab destinations to home, and added a UI assertion for returning from settings/counter to home. START SPEND/INVEST still opens the input screen with the selected mode.
