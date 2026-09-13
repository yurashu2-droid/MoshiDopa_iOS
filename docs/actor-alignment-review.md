# Actor registration correction

Luna MAX isolated the Android young actor rig coordinates; parent verified `WhatIfActors.kt` and applied the minimum correction. The body is anchored at (585, 282), not (585, 468), at half of its original 335×746 size. The arm uses the Android pivot and 0.51 scale. Each face expression retains its aspect ratio and is centered in the same 317×305 registration box before the 0.6 transform.

Concept: a coherent paper character listens, speaks and reacts without its body parts separating. Preserve the existing dialogue timing and expressions. Phase review: quiet, speaking, pointing, reaction, completed transcript. Parent also keeps the actor stage above the changing current dialogue during playback, and removes a duplicate page heading, following Android WhatIfStage/WhatIfActivity. Full dialogue remains in the completed/shared image.

This corrects observed disconnected geometry; it does not establish complete Android camera/spring parity. No new rendered image or normal-speed validation has run yet. The next CI must check the initial pose, talking pose, reaction face, whole transcript and exported image, plus skip/replay/mode changes. Android source files were read only.
