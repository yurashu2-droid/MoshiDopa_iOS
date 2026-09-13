# Interview fidelity implementation review

The interview asks the saved past self a question, follows the answer with a camera handoff, shows the purchase/time consequence, and ends on the reaction. Android `WhatIfActors`, `WhatIfStage`, `WhatIfMotion`, `WhatIfSpring`, and `WhatIfLegacyActors` are the behavior references. No Android sources or assets were changed.

## Implemented source alignment

- Clock is 18.7 seconds: opening wide; interviewer at 0.65; young at 3.6; interviewer at 6; item at 8.2 (interviewer fallback without an item); young at 10.4; punchline at 12.6; final reply at 15; closing wide at 17.3.
- Camera uses Android target positions, zooms, 430 ms overshoot and 220 ms settling, restrained deterministic handheld drift/roll. It transforms only the illustrated world.
- SPEND uses unchanged short-old-man sheet crops (298/133/233/200, 301/353/233/200, 158/567/273/417), registered at (310,609), and self-mic-v3/point/rest arm drawings. The blank sheet face is excluded. The body, hand and neck stay within each actor's shared transform.
- Young registration is (660,655), body at local (-75,-373), arm shoulder at (63,-315), and face pivot at (19,-350). Speech deformation, face swap after pop midpoint, neck nod, arm follow-through, and feet-anchored body spring use the Android speech clock. Final SPEND shock begins at 15.65, followed by a head droop and persistent 16% body settling.
- INVEST uses the original generated atlases with Android native magenta removal, per-cell artwork bounds and feet registration. Talking uses cell 1; final proud/cheer uses cells 10/11 at the Android amount threshold.
- Stage is a fixed 1080×800 viewport corresponding to Android y230…1030. Bottom silhouettes fade in the y790…1030 paper zone. The prop uses Android world registration and item landing deformation.
- Current and previous captions stay outside the camera. The opening has no question until 0.65; punchline starts at 12.6; final SPEND caption is the ellipsis at 15. Money reveals at 13.5 within space reserved from the first frame. Skip/reduced motion preserve the full transcript and final result; static share rendering uses the same final clock.

## Diagnostic phase plan

Render 0, 0.65, 1.3, 3.6, 4.25, 6.65, 7.7, 8.2, 8.85, 10.4, 11.05, 13.25, 13.5, 15, 15.65, 15.83, 16.3, 17.3, 17.95 and 18.7 seconds. Inspect actor seams, the old neck and mic hand, young shock pivot, item landing, camera overshoot/settling, plus INVEST proud/cheer final artwork. Inspect normal-speed playback and compact-screen wrapping. Render acceptance is pending: this Windows workspace has no Xcode/simulator.

The above was the implementation handoff's diagnostic plan. Parent's executed review used the ten decisive XCTest phase PNGs (SPEND 0/1.3/4.25/8.85/13.5/15.83/18.7 and INVEST 4.25/15.83/18.7), three shared cards and normal-speed playback of the actual run-34784373373 video. Not every suggested timestamp was exported separately. The 19.88-second recording includes the natural full-transcript ending. This review found and corrected INVEST closing-wide head cropping: its native viewport now uses (480,320,1.38×0.952), interpolated through the same camera path. Other poses remain unchanged. Parent verified the corrected final phase and shared INVEST image in successful run 34785720445 at `3d8d4b9`; rendered acceptance for this Goal is complete. Signed-device animation performance, VoiceOver and Dynamic Type remain separate checks. See [final evidence](native-verification.md).

## Remaining intentional native differences

The surrounding native receipt header, torn-paper bubble shape, SwiftUI fonts/emoji rendering, and complete-transcript layout remain native. Android's exact bubble canvas typography/tail coordinates are not reproduced. There is no Android `frame.stretch` speech contribution to item scale (its ITEM shot has only landing stretch); the implemented item landing matches that visible phase. UIKit/CGImage magenta and edge handling needs rendered comparison, as well as emoji item shape across platforms. The final reduced-motion card shows its complete transcript before the stage, as in the existing native share card.

## Verification

Read the Android behavior and inspected the existing pre-fix `artifacts/run-34781229834/review-motion/frame-03.png`: it shows separated young geometry and the tall old-man silhouette. Source diff whitespace check passes. Build and rendered visual checks are delegated to the parent task's next macOS CI run; no claim of rendered acceptance is made.
