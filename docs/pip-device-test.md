# P2B native PiP device evidence

Status: implemented PoC source, **not yet verified on a signed device**. Windows source editing, CI compilation, Simulator screenshots and signed-device PiP acceptance are separate evidence. The timer supplies real money frames at a 1 Hz target only while the process receives execution opportunities. No silent audio, private API, or unrestricted background timer is used.

## Entry and data contract

Present `PiPDiagnosticsView()` from the host app. `PiPDiagnosticsModel.shared` retains the service, layer and AVKit controller for the app process lifetime even when the sheet closes. The visible `UIViewRepresentable` embeds the actual sample-buffer layer, not a SwiftUI imitation. User sequence: edit next-session hourly rate → **計測開始** → confirm inline real amount → **PiP開始** → open another app → return → **停止・保存**. Changing the rate does not mutate a running session. Dismissing PiP, pausing its playback or closing the sheet does not stop measurement.

`SessionService` is the sole measurement entry, isolated to the main actor. Start writes before publishing active state. Stop targets UUID, freezes monotonic elapsed at the first attempt, and only clears active state after saving. A failed save exposes an error and retains the same frozen value for retry. Repeated stop returns the existing result; an old stop cannot close a new session. ContinuousClock measures elapsed across sleep without wall-clock drift; timer invocations never add elapsed time. Double amount matches the Android formula; the UI displays two fractional digits, without claiming the final P4 rounding/aggregation contract is settled.

New store: Application Support/MoshiDopaNative/pip-poc-v1.sqlite (SQLite/WAL). The directory is excluded from backup and database/diagnostic files use complete-until-first-authentication protection. Verify actual protection and backup exclusion on a device, including WAL sidecars. The Expo DB and native-event-queue.json are never opened or changed. Reopening the **process** marks unfinished rows interrupted at the last durable checkpoint (normally every 5 seconds while execution is available), never extends to the current wall time, and never invents an end timestamp. Interrupted rows need human review; correction/migration UI is P4.

## Evidence capture

Record commit, signing team/profile, device hardware identifier, iOS version, SNS versions, battery %, low-power state, audio route, thermal state and exact hourly rate. Default 1,800 yen/hour: 15 minutes = 450 yen; 60 minutes = 1,800 yen. Use device screen recording plus external camera where necessary. Screen-recording audio settings must be noted because they may alter coexistence results.

Export from **履歴・フレーム時刻ログを書き出す**, inspect the generated local JSON, then explicitly share it using the OS sheet. The export contains real durable history and persistent JSONL diagnostic events: frame enqueue/backpressure/layer failure, PiP request/start/stop/failure, amount, elapsed milliseconds, wall date and time since the process's diagnostic origin. Raw boot uptime is not exported. An enqueue log proves delivery to AVFoundation, not that the OS displayed it: compare visible amount changes against frame log timestamps. Preserve original export and recording; do not replace missing evidence with preview amounts. Export is optional and local until the user invokes sharing; no network upload is implemented.

The privacy manifest declares SystemBootTime reason 35F9.1 for internal media timing/checkpoint timers. Only app-event elapsed durations are included in export; system boot time is not included. See [Apple required reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons).

## Manual acceptance matrix

All rows are **NOT RUN** until evidence is attached. Run minimum iOS 17 and current supported OS, devices with and without Dynamic Island, signed development builds. Simulator does not establish these results.

| Case | Procedure | Required observation |
|---|---|---|
| 15 minute basic | Start measurement and PiP explicitly, open SNS for ≥15 minutes | Visible real amount continues; target p95 delay ≤2 seconds and no >5 second frozen interval; export and recording agree |
| 60 minute continuous | Same, uninterrupted 60 minutes | Final elapsed/amount match monotonic interval; record CPU, memory, thermal and battery conditions |
| Each SNS audio | YouTube, Instagram, TikTok, X individually; audio on/off before and after PiP | No unintended audio stop/ducking; record actual mixed-audio outcome |
| Competing PiP | Start another app's PiP while counter PiP is active | OS behavior captured; counter dismissal does not stop measurement |
| Lock/resume | Lock 1 minute; unlock and return | No promise of locked PiP; elapsed includes lock interval; amount reconciles, logs show any update gap |
| OS overlays | Notifications, Control Center, route change, incoming call | Record frame gaps/delegates/audio interruption and recovery; no duplicate history |
| Dismiss/restart | Close PiP with OS control; later use PiP start again | Measurement stays active; resumed amount reflects current elapsed |
| Sheet close/reopen | Close diagnostics sheet with/without PiP, reopen | Same session and controller; no interrupted row or duplicate service |
| Explicit stop twice | Stop/save, reopen, inspect history | Exactly one finished row, correct snapshot rate and amount |
| Rate snapshot | Start at 1,800; edit next rate to 2,400 while active | Active and saved row retain 1,800; next session uses 2,400 |
| Process kill/relaunch | Force quit after checkpoint, relaunch diagnostics | Interrupted last-checkpoint duration, no guessed tail or automatic resume |
| Reboot | Reboot with running record, relaunch | Same interrupted recovery rule; no cross-boot inference |
| Wall time/zone change | Change time backward/forward and zone during measurement | Money unchanged by wall jump; start zone preserved |
| Low power / rapid switch | Toggle Low Power Mode; rapidly switch SNS 20 times | Gaps/failures recorded; final amount derives from clock, never tick count |
| Persistence error | With debugger/device harness, make native store unwritable | Error surfaced; stop not reported saved, frozen result retries once storage restored |
| Data protection/backup | Inspect app container flags/attributes and WAL files | Native folder excluded from backup; intended protection effective; legacy unchanged |

## Public API references

[Apple sample-buffer playback delegate](https://developer.apple.com/documentation/avkit/avpictureinpicturesamplebufferplaybackdelegate) defines playback, live time range, render-size and seek completion responsibilities. [Custom player PiP](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player) requires user initiation. [Audio mixing](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers) permits mixing, but does not certify SNS coexistence. [ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock) supplies the continuous process-local elapsed clock. App Review acceptance of a money-only video counter remains a separate unverified distribution gate.
