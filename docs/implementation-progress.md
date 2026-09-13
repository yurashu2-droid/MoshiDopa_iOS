# Native UI / PiP implementation progress

Branch: `codex/ios-native-ui-pip` (based on design commit `6e06410`).

## Current checkpoint

- Android baseline: all 480 recorded hashes and HEAD rechecked unchanged after the visual fixes.
- P1: complete at `3d8d4b9`, run 34785720445: Simulator build, 14 unit tests, 9 primary UI tests, 2 compact UI tests and unsigned iphoneos Release build succeeded. All artifacts downloaded.
- P2A: sample-data SwiftUI screens and parent rendered review complete for this Goal. Corrections include artwork packaging, ink contrast, hit targets, safe-area clipping and interview actor/camera registration. Scope and evidence are recorded in [native-verification.md](native-verification.md).
- P2B: common SessionService/SQLite/real sample-buffer renderer implemented and parent source review completed, including stop retry/recovery, audio cleanup and delegate isolation. Signed-device background behavior remains unverified.
- Parent owns integration, CI, final image/video review and acceptance. Luna MAX performed the bounded settings refinement; Sol Medium reviewed the PiP/core implementation.

## Parent review checkpoint (historical, before native runs)

- Rechecked all 480 Android baseline hashes and HEAD; no changes found.
- Reviewed the common amount calculation, monotonic elapsed time, frozen stop retry, SQLite recovery tests, and PiP sheet lifetime/restore handling.
- Added a UI integration test for actual foreground money increase, explicit stop/save, and saved-history visibility after app relaunch. This test does not assert background PiP behavior and has not yet run.
- Requested fixes for misleading Live Activity availability copy, missing display-surface previews, and incorrect tab destinations. These remain subject to rendered-image review.
- Integrated explicit receipt selection, period-aware history buckets, September/August fixtures for all story modes, and four distinct Live Activity preview surfaces. UI compilation and visual fidelity remain unverified.
- Sol Medium independently reviewed Core/Platform/tests/project/CI and found a PiP preparation failure path that retained the audio session when diagnostic logging threw. Parent fixed this with deferred audio cleanup in `ed3349d` and reviewed the error paths. Xcode tests have not run.
- The user completed Git authentication and the branch was pushed. Remaining acceptance work requires successful native CI, artifact download, parent image/video comparison, corrections, and rerun. Device-only PiP acceptance remains separately unverified.

## Completion evidence (historical dispatch notes follow)

CI dispatch checkpoint: authentication blocker resolved. [Initial run 34779188320](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34779188320) at `c594cad` incorrectly skipped native verification because the filter inspected only the final documentation commit. This is **not** a successful native build. Parent corrected the filter to inspect the full push and new branches in `dd3678f`. [Run 34779218511](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34779218511) is executing native verification; results pending.

- [x] Successful native Simulator build and tests at a named commit/run.
- [x] Successful unsigned iphoneos Release build and downloadable artifact.
- [x] Actual PNGs / xcresult / motion video downloaded and reviewed by parent.
- [x] UI references: home, history, settings, counter, receipt, statement, onboarding, whatif, measurement; empty/populated/large states.
- [x] Navigation and meaningful state interactions verified.
- [x] PiP core/tests reviewed; unsigned build/source and signing/device-trial instructions ready.
- [x] Device-only conditions clearly unverified; no device acceptance claimed.

No App Store submission or main merge is included. Old Expo data remains untouched; migration is a later integration stage. Mock UI data must never enter the PiP store.

Final acceptance: [run 34785720445](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34785720445) at `3d8d4b9d99e0a5517458d40ebfca68c0a7dfe840` is green. Parent downloaded all artifacts and confirmed the last viewport/headroom fixes in actual PNGs. The following sections are chronological findings, including failures and then-pending checks; [native-verification.md](native-verification.md) is the final consolidated status. P2B device behavior remains unverified as expressly permitted for this Goal's source/build/test-procedure handoff.

## CI review: run 34779516989

At `fa280ad`, the Simulator app compiled and all nine core tests passed. Three of seven UI tests passed; four failed. This run is not accepted as successful CI, and the device build was skipped.

Parent downloaded the xcresult and attachments. Accessibility dumps show receipt/onboarding screen identifiers on ScrollView rather than Other; tests now query identifiers across element types. Real foreground money increased; the saved history row was below the lazy List viewport, so the test now scrolls to check it before and after relaunch.

Parent inspected the home screenshot: missing wordmark, mascots and paper texture. Runtime logs confirm named-image lookup failures. The unchanged PNG artwork is now packaged into named asset-catalog image sets. Visual acceptance awaits a new rendered comparison.

PiP delegate callbacks now use a lock-protected playback snapshot for synchronous queries and main-actor tasks for UI state. Tests and device concurrency behavior require rerun. CI now attempts screenshots after test failures and independently attempts the unsigned device build, preserving failed test status.

## Parent visual correction and next CI

Previous turn made concrete progress: named artwork moved to catalogs, failing UI queries corrected and evidence handling improved. Run [34780290813](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34780290813) at `1d8fed7` then failed compilation because the newly introduced catalog lacked Xcode's default AppIcon set. No tests or visual acceptance are claimed for that run. Added the Android icon source unchanged and a macOS build-time sizing step, documented for local builds as well as CI.

Parent compared the actual Android home and iOS home/settings PNGs from run 34779516989. Home corrections: explicit wordmark size, integer floor amount as Android, proportional heavy digits, amount-bound available width, corrected tagline, tape and marker, side-by-side icon/text start cards, recent receipts before secondary demo links. Shared corrections: thinner navigation, fine deterministic paper edges and visible background/card fibre texture. These edits still require rendered verification. Added a hosted test that loads representative artwork by the runtime names that previously failed. Android's 480 recorded hashes and HEAD were rechecked unchanged.

Luna MAX refined only the settings top-level hierarchy and sizing; parent reviewed the diff and required the sample annotation and “値札の設定” terminology to remain. Parent verified Android MainActivity bottom navigation targets `home/history/settings`, corrected native measurement-tab destinations to home, and added a UI assertion for returning from settings/counter to home. START SPEND/INVEST still opens the input screen with the selected mode.

## Foreground frame observation

Parent inspected `artifacts/run-34779516989/test-attachments/EBFBDAD2-809D-4E42-B5F3-F00098D9493B.png`: the real sample-buffer layer and SwiftUI diagnostic text both show ¥0.82 at hourly rate ¥1800, with the layer showing one elapsed second. This is foreground frame evidence only. The same screenshot reports Simulator PiP unsupported, so it is not external-window or SNS/background proof.

## Run 34780765780 compiler correction

At `36548cb`, icon preparation succeeded but Swift could not type-check the combined paper-edge expression at MoshiDopaBrand.swift:50 in reasonable time. Both Simulator and device builds failed; no UI images were produced. Parent split that calculation into explicitly typed intermediate values and a loop, preserving the same edge geometry. Full CI rerun is required.

## Run 34781229834: rendered review and corrections

[Run 34781229834](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34781229834), commit `88cae47255809bcdf642d0ccce46112995fbe36d`: Simulator compilation succeeded, unit tests 10/10 passed, UI tests 5/7 passed, unsigned iphoneos Release build succeeded. Overall result is failure. Parent downloaded the complete artifact, including both build packages, xcresult, 27 standalone PNGs, test attachments and the interview video.

Parent inspected home, settings, history/receipt/counter large-value states, statement, onboarding and measurement PNGs. Artwork now loads. The paper texture incorrectly covered text and enlarged settings row accessibility frames. The settings PiP button overlapped bottom navigation; the history row's middle spacer was not tappable. Corrections bound decoration within backgrounds, exclude it from hit testing, make row labels fully tappable and place the ScrollView above the safe-area navigation inset. Existing failing tests are retained for rerun.

Additional corrections: remove the history phrase “この今日”; make the large fixture end on its recorded day while preserving the seven-digit amount; exercise the same large amount in counter previews, with explicit compact-surface abbreviation. ShareLink and XCTest now use the same UIImage renderer, with ten receipt/statement/interview PNG attachments for parent inspection. These changes are not yet validated by Xcode.

The 16.19-second interview recording was inspected at sampled phases; the young character's disconnected rig requires correction. This is not a completed normal-speed motion review. Recording now begins before launch to include the opening; final timing, whole interaction and corrected geometry require the next CI output. Luna MAX owns only the actor rig correction; parent owns integration and visual acceptance. Sol Medium supplied the bounded shared-image evidence change, reviewed by parent.

Artifacts are split into visual evidence, test records and native builds to avoid the previous single archive exceeding the connector's 512 MiB download limit. The unsigned IPA is a build result, not directly installable on a device. Background PiP updates, SNS coexistence and signing remain unverified; see `pip-device-test.md`.


## Review work following 03c6996

[Run 34783195768](https://github.com/yurashu2-droid/MoshiDopa_iOS/actions/runs/34783195768) at `03c69967c89890814e224fc9ce87a73eedb67b3d` completed successfully: 13 unit tests and 8 UI tests passed; unsigned iphoneos Release build succeeded. Parent verified the exact commit and Xcode 26.3/XcodeGen 2.46.0 in the downloaded environment file. Rendered artifact review is ongoing.

A bounded Sol Medium task aligned the interview with Android's 18.7-second camera/actor sequence, latest short-man sheet, self-mic and investment poses. Parent reviewed registration and timing, verified the required source images exist, and added actual SwiftUI-rendered phase PNGs to the test attachments. Parent also pauses the timeline for completed/reduced-motion states and preserves the completed transcript when hiding time. These newer changes still require CI compilation and rendered review.

Parent added selectable SPEND/INVEST and small/normal/large amount previews, plus update time/rate on larger Live Activity surfaces. A compact iPhone SE check reuses the compiled test bundle for two actual navigation tests and captures seven large-value screens. These additions close UI acceptance coverage gaps; they are not yet successful test evidence. Signed-device installation and PiP test steps are now explicit in `native-development.md`.


Run 34783195768 artifact IDs: visual `10325797406`, tests `10326246243`, builds `10326211327`. Simulator package is 22,580,033 bytes; unsigned device IPA is 18,236,088 bytes. Logs specifically confirm `testHistoryOpensSelectedReceipt`, `testRealMeasurementIncreasesAndSurvivesRelaunch`, and `testWhatIfSkipReplayAndModeChange` passed. Artifacts are available locally under `artifacts/run-34783195768/` once download/extraction completes. These foreground/navigation results do not establish background PiP acceptance.


Parent downloaded and extracted all three run-34783195768 archives. Actual home/settings/history-large PNGs confirm restored ink contrast and the selected-history/PiP navigation tests pass. Scroll content still paints beneath the lower safe area, so the tab bar now provides an opaque world-color background through that area; verification is pending.

Parent subsequently inspected onboarding steps 2–6, selected Instagram receipt, empty statement, INVEST entry and real PiP inline/saved-after-relaunch attachments from this run. No text collision was observed in those onboarding states; selected receipt shows Instagram/¥705.00, empty statement distinguishes no records from zero usage. Inline ¥0.76 and saved ¥1.06 are foreground/persistence evidence only. Android's 480 hashes and HEAD were rechecked unchanged; remote main remains `1fba7b7b0688112eeef24c65c1976bc1ed130870`, retained as an ancestor.

Run 34784373373 at `1380b505c04de91b51ae3e7fb8f987cd7a99e238` compiled and passed 14 unit tests, but its primary UI step failed at VisualFlowTests.swift:148. The new mode/amount test exposed CounterPreview's accessibility label omitting both values while hiding its children. Parent added the same displayed activity/amount to that label; this correction still requires rerun. Compact tests, device build and rendered evidence are pending at this checkpoint. Do not accept this run as green.

The completed run has 14/14 unit, 8/9 primary UI and 2/2 compact UI passes, plus a successful unsigned Release build. All three artifacts were downloaded/extracted: visual `10326521192`, tests `10326426442`, builds `10326586070`, under `artifacts/run-34784373373/`. Parent inspected compact home/settings/counter, all ten deterministic interview phase PNGs, and Live Activity large-amount surfaces. Bottom navigation coverage and actor registration are corrected. New issues: INVEST closing-wide head crop; scrolling content under the status bar. Parent adjusts only INVEST wide framing and clips the ScrollView viewport. Both need new rendering.

Parent opened the actual run-34784373373 MP4 in Chrome on loopback at its default playback speed, observed the conversation/camera progression, money reveal and natural full-transcript ending, and compared the phase PNGs. No frame-by-frame smoothness or real-device performance certification is implied. SPEND composition now keeps the young neck/body connected and the old actor within the stage; final transcript and result remain available by scrolling. Final P2A acceptance still awaits the bounded corrections and passing CI.

Parent inspected all ten exported share PNGs. Four receipts and three statements preserve amount hierarchy, positive INVEST treatment, hidden time/rate and unclipped large values. The three interview exports expose the old tall actor painting beyond its Canvas into the activity label; the new camera-stage clip and registered short-actor implementation address this, awaiting the next rendering. P2A is not yet accepted. Parent checked Apple `GraphicsContext.draw(_:in:style:)` documentation for the Image overload used by the new Canvas (https://developer.apple.com/documentation/swiftui/graphicscontext/draw(_:in:style:)-blhz).
