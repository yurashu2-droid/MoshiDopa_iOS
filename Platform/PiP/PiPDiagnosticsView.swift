import SwiftUI
import AVKit
import AVFAudio
import ActivityKit

struct PiPEvent: Codable {
    let date: Date
    let processElapsedSeconds: TimeInterval
    let kind: String
    let sessionID: UUID?
    let elapsedMilliseconds: Int64?
    let amount: Double?
    let detail: String
}

@MainActor
private final class PiPRestoreReply {
    private var completion: (@Sendable (Bool) -> Void)?
    init(_ completion: @escaping @Sendable (Bool) -> Void) { self.completion = completion }
    func reply(_ restored: Bool) {
        let callback = completion
        completion = nil
        callback?(restored)
    }
}

final class PiPEventStore {
    let url: URL
    init(directory: URL) throws {
        url = directory.appendingPathComponent("pip-diagnostics.jsonl")
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data().write(to: url, options: .atomic)
        }
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
    }
    func append(_ event: PiPEvent) throws {
        var bytes = try JSONEncoder().encode(event)
        bytes.append(0x0A)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: bytes)
    }
}

/// AVKit's synchronous queries can arrive outside the main actor.
/// Every access to these two playback flags is protected by the same lock.
private final class PiPPlaybackState: @unchecked Sendable {
    private let lock = NSLock()
    private var hasContent = false
    private var presentationPaused = false

    func setHasContent(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        hasContent = value
    }

    func setPresentationPaused(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        presentationPaused = value
    }

    func isPresentationPaused() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return presentationPaused
    }

    func isPlaybackPaused() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !hasContent || presentationPaused
    }
}

@MainActor
final class PiPDiagnosticsModel: NSObject, ObservableObject {
    static let shared = PiPDiagnosticsModel()
    @Published var hourlyRateText = "1800"
    @Published private(set) var snapshot: SessionRecord? {
        didSet { playbackState.setHasContent(snapshot != nil) }
    }
    @Published private(set) var history: [SessionRecord] = []
    @Published private(set) var pipStatus = "PiP未開始"
    @Published private(set) var possible = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var exportURL: URL?
    @Published private(set) var isCounting = false
    @Published private(set) var currentTarget: String?
    @Published private(set) var liveStatus = "Live Activity未開始"
    @Published private(set) var displayReady = false
    @Published private(set) var finishingExternal = false
    @Published var trackingMode = UserDefaults.standard.string(forKey: "native.trackingMode") ?? "background" {
        didSet { UserDefaults.standard.set(trackingMode, forKey: "native.trackingMode") }
    }
    @Published private(set) var delivery = UserDefaults.standard.string(forKey: "native.delivery") ?? "pip"
    @Published private(set) var displayStyle = UserDefaults.standard.string(forKey: "native.style") ?? "paper"
    let inlineHost = MoneyLayerHostView(frame: .zero)
    var layer: AVSampleBufferDisplayLayer { inlineHost.sampleLayer }
    private var service: SessionService?
    private var events: PiPEventStore?
    private var controller: AVPictureInPictureController?
    private var observation: NSKeyValueObservation?
    private var displayObservation: NSKeyValueObservation?
    private var pendingPiP: UUID?
    private let liveActivity = MoneyLiveActivityController()
    private var liveUpdateTask: Task<Void, Never>?
    private var liveEndTask: Task<Void, Never>?
    private var pendingLiveUpdate: (SessionRecord, Bool)?
    private var lastLiveUpdate = -Double.infinity
    private var timer: Timer?
    private let renderer = MoneyFrameRenderer()
    private var attached = false
    private var audioActive = false
    nonisolated private let playbackState = PiPPlaybackState()
    private var presentationPaused: Bool {
        get { playbackState.isPresentationPaused() }
        set { playbackState.setPresentationPaused(newValue) }
    }
    private var lastCheckpoint = -Double.infinity
    private var lastFrameLog = -Double.infinity
    private var videoIsReadyForDisplay: Bool {
        if #available(iOS 17.4, *) { return layer.isReadyForDisplay }
        // Older iOS exposes rendering status, not the first-frame readiness property.
        return layer.status == .rendering
    }

    override init() {
        super.init()
        layer.videoGravity = .resizeAspect
        var timebase: CMTimebase?
        let timebaseStatus = CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault,
            sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        if timebaseStatus == noErr, let timebase {
            CMTimebaseSetTime(timebase, time: CMClockGetTime(CMClockGetHostTimeClock()))
            CMTimebaseSetRate(timebase, rate: 1)
            layer.controlTimebase = timebase
        }
        do {
            let url = try SQLiteSessionRepository.applicationStoreURL()
            service = try SessionService(repository: SQLiteSessionRepository(url: url))
            events = try PiPEventStore(directory: url.deletingLastPathComponent())
            history = try service!.history()
            try log("initialized", detail: "Running rows recover as interrupted; no cross-process estimate")
        } catch { service = nil; errorMessage = error.localizedDescription }
        if #available(iOS 17.4, *) {
          displayObservation = layer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] _, change in
            let ready = change.newValue ?? false
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.displayReady = ready
                self.perform { try self.log("display_ready", detail: "\(ready)") }
                if ready { self.completePendingPiP() }
            }
          }
        }
        if AVPictureInPictureController.isPictureInPictureSupported() {
            controller = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: layer, playbackDelegate: self))
            controller?.delegate = self
            controller?.canStartPictureInPictureAutomaticallyFromInline = false
            controller?.requiresLinearPlayback = true
            observation = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] _, change in
                let value = change.newValue ?? false
                Task { @MainActor [weak self] in
                    self?.possible = value
                    if value { self?.completePendingPiP() }
                }
            }
        } else { pipStatus = "この端末ではPiP非対応" }
        Task { await liveActivity.endOrphans() }
    }

    func configureDisplay(delivery: String, style: String) {
        guard snapshot == nil else { return }
        self.delivery = delivery == "liveActivity" ? "liveActivity" : "pip"
        displayStyle = style
        UserDefaults.standard.set(self.delivery, forKey: "native.delivery")
        UserDefaults.standard.set(style, forKey: "native.style")
    }

    func attach() {
        attached = true
        guard timer == nil else { return }
        render()
        timer = Timer.scheduledTimer(withTimeInterval: MoneyFrameRenderer.frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func startMeasurement() {
        perform {
            guard !finishingExternal else { throw TrackingIntentError.operationFailed("外部表示の終了を待ってください。") }
            guard let service else { throw SessionError.missingSession }
            guard let rate = Double(hourlyRateText) else { throw SessionError.invalidRate }
            snapshot = try service.start(hourlyRate: rate, counting: false)
            isCounting = false
            currentTarget = nil
            presentationPaused = false
            history = try service.history()
            try log("measurement_started")
            render()
            controller?.invalidatePlaybackState()
        }
    }

    func startPiP() {
        guard controller?.isPictureInPictureActive != true, pendingPiP == nil else { return }
        perform {
            guard snapshot != nil, attached, let controller else { throw SessionError.missingSession }
            presentationPaused = false
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audio.setActive(true)
            audioActive = true
            var requested = false
            defer {
                if !requested { pendingPiP = nil; deactivateAudio() }
            }
            render()
            controller.invalidatePlaybackState()
            let request = UUID()
            pendingPiP = request
            pipStatus = "PiPの映像を準備中"
            try log("pip_preparing", detail: "ready=\(videoIsReadyForDisplay); bounds=\(layer.bounds); window=\(inlineHost.window != nil)")
            requested = true
            completePendingPiP()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard let self, self.pendingPiP == request else { return }
                self.pendingPiP = nil
                self.pipStatus = "PiP準備失敗。診断ログを確認してください。"
                self.perform { try self.log("pip_preparation_timeout", detail: "ready=\(self.videoIsReadyForDisplay); status=\(self.layer.status.rawValue)") }
                self.deactivateAudio()
            }
        }
    }

    private func completePendingPiP() {
        guard pendingPiP != nil, let controller, controller.isPictureInPicturePossible,
              videoIsReadyForDisplay, inlineHost.window != nil,
              layer.bounds.width > 0, layer.bounds.height > 0 else { return }
        pendingPiP = nil
        perform { try log("pip_user_requested") }
        pipStatus = "PiP開始要求中"
        controller.startPictureInPicture()
    }

    func startLiveActivity() {
        perform {
            guard let snapshot else { throw SessionError.missingSession }
            try liveActivity.start(record: snapshot, style: displayStyle, isCounting: isCounting)
            liveStatus = liveActivity.status
            try log("live_activity_started", detail: String(describing: liveActivity.diagnostics))
        }
    }

    func applicationEnteredBackground() {
        if trackingMode == "background" {
            changeCounting(UIApplication.shared.isProtectedDataAvailable, reason: "app_background")
        }
        else { checkpointForLifecycle() }
    }

    func applicationWillEnterForeground() {
        // Our own app is excluded even when a Shortcuts close event is delayed or missing.
        changeCounting(false, reason: "app_foreground")
        currentTarget = nil
    }

    func deviceProtectedDataUnavailable() {
        changeCounting(false, reason: "protected_data_unavailable")
        currentTarget = nil
    }

    func deviceProtectedDataAvailable() {
        if trackingMode == "background", UIApplication.shared.applicationState == .background {
            changeCounting(true, reason: "protected_data_available_background")
        }
    }

    func targetAppChanged(name: String, opened: Bool) throws {
        errorMessage = nil
        guard trackingMode == "shortcuts" else { throw TrackingIntentError.wrongMode }
        guard snapshot != nil else { throw TrackingIntentError.notArmed }
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { throw TrackingIntentError.emptyTarget }
        if opened {
            currentTarget = target
            changeCounting(true, reason: "target_opened:\(target)")
        } else if currentTarget == target {
            currentTarget = nil
            changeCounting(false, reason: "target_closed:\(target)")
        }
        if let errorMessage { throw TrackingIntentError.operationFailed(errorMessage) }
    }

    private func changeCounting(_ counting: Bool, reason: String) {
        perform {
            guard let service, service.active != nil else { return }
            // Publish the real boundary even if its durable checkpoint fails.
            defer {
                snapshot = service.snapshot()
                isCounting = service.isCounting
                render()
                updateLiveActivity(force: true)
            }
            try service.setCounting(counting)
            snapshot = service.snapshot()
            try log("counting_boundary", detail: reason)
        }
    }

    private func updateLiveActivity(force: Bool = false) {
        guard delivery == "liveActivity", let record = snapshot else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastLiveUpdate >= 5 else { return }
        lastLiveUpdate = now
        pendingLiveUpdate = (record, isCounting)
        guard liveUpdateTask == nil else { return }
        liveUpdateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while let (record, counting) = self.pendingLiveUpdate {
                self.pendingLiveUpdate = nil
                await self.liveActivity.update(record: record, isCounting: counting)
                try? self.log("live_activity_update_completed", record: record, detail: "counting=\(counting); \(self.liveActivity.diagnostics)")
            }
            self.liveStatus = self.liveActivity.status
            self.liveUpdateTask = nil
        }
    }

    func stopAndSave() {
        perform {
            guard let id = snapshot?.id, let service else { throw SessionError.missingSession }
            let finished = try service.stop(sessionID: id)
            pendingPiP = nil
            // Stop the external presentation only after the result is durable.
            controller?.stopPictureInPicture()
            snapshot = nil
            isCounting = false
            currentTarget = nil
            let previousUpdate = liveUpdateTask
            pendingLiveUpdate = nil
            finishingExternal = true
            liveEndTask = Task { @MainActor [weak self] in
                await previousUpdate?.value
                guard let self else { return }
                await self.liveActivity.end(record: finished)
                self.liveStatus = self.liveActivity.status
                self.finishingExternal = false
                self.liveEndTask = nil
            }
            history = try service.history()
            try log("measurement_saved", record: finished)
            deactivateAudio()
            controller?.invalidatePlaybackState()
            render()
        }
    }

    func checkpointForLifecycle() { tick(forceCheckpoint: true) }

    func exportDiagnostics() {
        perform {
            guard let service, let events else { throw SessionError.missingSession }
            try log("export_requested")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            struct Export: Encodable {
                let schema: Int
                let generatedAt: Date
                let operatingSystem: String
                let model: String
                let appVersion: String
                let delivery: String
                let style: String
                let trackingMode: String
                let isCounting: Bool
                let displayReady: Bool
                let pipPossible: Bool
                let liveActivity: [String: String]
                let validation: String
                let records: [SessionRecord]
                let eventJSONLines: String
            }
            let data = Export(schema: 1, generatedAt: Date(), operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                model: UIDevice.current.model,
                appVersion: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "unknown"))",
                delivery: delivery, style: displayStyle, trackingMode: trackingMode, isCounting: isCounting,
                displayReady: videoIsReadyForDisplay, pipPossible: controller?.isPictureInPicturePossible ?? false,
                liveActivity: liveActivity.diagnostics,
                validation: "Device PiP acceptance is unverified until recorded manual test", records: try service.history(),
                eventJSONLines: String(decoding: try Data(contentsOf: events.url), as: UTF8.self))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("MoshiDopa-PiP-\(UUID().uuidString).json")
            try encoder.encode(data).write(to: url, options: .atomic)
            exportURL = url
        }
    }

    private func tick(forceCheckpoint: Bool = false) {
        snapshot = service?.snapshot()
        isCounting = service?.isCounting ?? false
        displayReady = videoIsReadyForDisplay
        completePendingPiP()
        let now = ProcessInfo.processInfo.systemUptime
        if snapshot?.state == .running, forceCheckpoint || now - lastCheckpoint >= 5 {
            perform {
                try service?.checkpoint()
                lastCheckpoint = now
            }
        }
        if snapshot != nil || controller?.isPictureInPictureActive == true { render() }
        updateLiveActivity()
    }

    private func render() {
        guard !presentationPaused else { return }
        do {
            if layer.status == .failed {
                try log("layer_failed", detail: layer.error.map { String(reflecting: $0 as NSError) } ?? "unknown")
                layer.flush()
            }
            guard layer.isReadyForMoreMediaData else {
                if snapshot != nil { try log("frame_backpressure") }
                return
            }
            let frame = try renderer.sample(record: snapshot,
                presentationSeconds: CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock())), style: displayStyle)
            layer.enqueue(frame)
            let now = ProcessInfo.processInfo.systemUptime
            if snapshot != nil, now - lastFrameLog >= 1 {
                lastFrameLog = now
                try log("frame_enqueued", detail: "sampledLog=true; interval=\(MoneyFrameRenderer.frameInterval); pipActive=\(controller?.isPictureInPictureActive ?? false); appState=\(UIApplication.shared.applicationState.rawValue); ready=\(videoIsReadyForDisplay); status=\(layer.status.rawValue); bounds=\(layer.bounds)")
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func log(_ kind: String, record: SessionRecord? = nil, detail: String = "") throws {
        let value = record ?? snapshot
        try events?.append(PiPEvent(date: Date(), processElapsedSeconds: ProcessElapsedClock.seconds(), kind: kind,
            sessionID: value?.id, elapsedMilliseconds: value?.elapsedMilliseconds, amount: value?.amount, detail: detail))
    }
    private func perform(_ work: () throws -> Void) {
        errorMessage = nil
        do { try work() } catch { errorMessage = error.localizedDescription }
    }
    private func deactivateAudio() {
        guard audioActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            audioActive = false
        } catch { errorMessage = error.localizedDescription }
    }
}

extension PiPDiagnosticsModel: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        // OS pause affects presentation only; measurement continues using its own clock.
        playbackState.setPresentationPaused(!playing)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.perform { try self.log("pip_set_playing", detail: "\(playing)") }
            self.controller?.invalidatePlaybackState()
        }
    }
    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { playbackState.isPlaybackPaused() }
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        let detail = "\(newRenderSize.width)x\(newRenderSize.height)"
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.perform { try self.log("pip_render_size", detail: detail) }
        }
    }
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping @Sendable () -> Void) { completionHandler() }
}

extension PiPDiagnosticsModel: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pipStatus = "PiP表示中 · 背景更新は実機で検証"
            self.perform { try self.log("pip_started") }
        }
    }
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pipStatus = "PiP停止 · 計測は停止・保存まで継続"
            self.perform { try self.log("pip_stopped") }
            self.deactivateAudio()
        }
    }
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        let detail = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pipStatus = "PiP開始失敗"
            self.perform { try self.log("pip_start_failed", detail: detail) }
            self.errorMessage = detail
            self.deactivateAudio()
        }
    }
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping @Sendable (Bool) -> Void) {
        Task { @MainActor in
            let reply = PiPRestoreReply(completionHandler)
            let callback: (Bool) -> Void = { restored in
                Task { @MainActor in reply.reply(restored) }
            }
            NotificationCenter.default.post(name: Notification.Name("MoshiDopaRestorePiP"), object: nil,
                userInfo: ["completion": callback])
            // Never report success if no host actually restored the UI.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { reply.reply(false) }
        }
    }
}

final class MoneyLayerHostView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    var sampleLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
}

struct MoneyInlinePlayer: UIViewRepresentable {
    let model: PiPDiagnosticsModel
    func makeUIView(context: Context) -> MoneyLayerHostView { model.inlineHost }
    func updateUIView(_ uiView: MoneyLayerHostView, context: Context) {
        // Wait for SwiftUI to install the real visible inline layer before supplying frames.
        DispatchQueue.main.async { model.attach() }
    }
}

@MainActor
struct PiPDiagnosticsView: View {
    @StateObject private var model = PiPDiagnosticsModel.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            List {
                Section(model.delivery == "pip" ? "PiP · 実際の金額" : "Live Activity · 実際の金額") {
                    MoneyInlinePlayer(model: model)
                        .frame(height: 180).listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    Text(model.snapshot.map { String(format: "%@ ¥%.2f · 開始時給 ¥%.2f", $0.state == .finished ? "保存待ち" : model.isCounting ? "計測中" : "待機・一時停止", $0.amount, $0.hourlyRateAtStart) } ?? "計測していません")
                        .monospacedDigit().accessibilityIdentifier("pip-current-amount")
                    TextField("次回の時給（円）", text: $model.hourlyRateText).keyboardType(.decimalPad)
                        .accessibilityIdentifier("pip.hourlyRate")
                    Text("時給変更は次回の計測から適用します。")
                        .font(.caption)
                    Picker("計測方法", selection: $model.trackingMode) {
                        Text("本体の外にいる時間").tag("background")
                        Text("対象アプリの開閉（Shortcuts）").tag("shortcuts")
                    }.disabled(model.snapshot != nil)
                    Text(model.trackingMode == "background"
                         ? "開始時は待機します。このアプリを離れると加算し、戻ると一時停止します。特定のSNSの識別はしません。画面ロックの除外は端末の通知状況に依存します。"
                         : "対象アプリの「開いたとき」に再開、「閉じたとき」に一時停止をShortcutsで設定してください。設定手順は下部の「対象アプリの連携」にあります。")
                        .font(.caption)
                    Button("1. 待機開始") { model.startMeasurement() }.disabled(model.snapshot != nil || model.finishingExternal)
                        .accessibilityIdentifier("pip-start-session")
                    if model.delivery == "pip" {
                        Button("2. PiP開始") { model.startPiP() }.disabled(model.snapshot == nil)
                            .accessibilityIdentifier("pip-start-window")
                    } else {
                        Button("2. Live Activity開始") { model.startLiveActivity() }.disabled(model.snapshot == nil)
                            .accessibilityIdentifier("live-start-window")
                        Text(ActivityAuthorizationInfo().areActivitiesEnabled ? "Live Activity使用可能" : "Live Activityが無効です")
                            .accessibilityIdentifier("live-authorization")
                    }
                    Button("3. 停止・保存") { model.stopAndSave() }.disabled(model.snapshot == nil)
                        .accessibilityIdentifier("pip-stop-session")
                    Text(model.delivery == "pip" ? model.pipStatus : model.liveStatus)
                        .accessibilityIdentifier("external-display-status")
                    Text("PiP開始可否: \(model.possible ? "準備完了" : "準備待ち/利用不可")")
                        .font(.caption)
                    Text("映像表示準備: \(model.displayReady ? "完了" : "待機")")
                        .font(.caption).accessibilityIdentifier("pip-display-ready")
                    Text("PiPは実行時間がある間に1秒間隔で描画します。Live Activityは更新時点の金額で、背景の連続更新はOSが保証しません。表示を閉じても停止・保存は必要です。")
                        .font(.caption)
                }
                Section("対象アプリの連携") {
                    Text("1. 計測方法を「対象アプリの開閉（Shortcuts）」にする。\n2. Shortcuts → オートメーション → アプリ → 対象SNS →「開いている」→ すぐに実行。もしドパの「対象アプリの計測を再開」を追加し、アプリ名を指定。\n3. 同じSNSの「閉じている」に「対象アプリの計測を一時停止」を追加。同じアプリ名を指定。\n4. もしドパで待機開始し、値札を開始してSNSへ移動。終了時は停止・保存。")
                        .font(.caption)
                    Text("オートメーションはiPhone上で設定が必要です。通知の遅延・欠落、強制終了後の再待機は実機で確認してください。複数SNSはそれぞれ開閉を登録します。")
                        .font(.caption)
                }
                if let error = model.errorMessage {
                    Section("エラー") { Text(error).foregroundStyle(.red).accessibilityIdentifier("pip.error") }
                }
                Section("端末内の実履歴") {
                    if model.history.isEmpty { Text("保存された計測はありません") }
                    ForEach(model.history) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.startedAt, format: .dateTime.year().month().day().hour().minute().second())
                            Text(String(format: "¥%.2f · %.3f秒 · 時給 ¥%.2f", record.amount, Double(record.elapsedMilliseconds) / 1000, record.hourlyRateAtStart))
                                .monospacedDigit()
                            Text(record.state == .interrupted ? "中断・要確認（最後に保存できた時間のみ）" : record.state == .running ? "計測中" : "保存済み")
                                .font(.caption)
                        }
                    }
                }
                .accessibilityIdentifier("pip-history")
                Section("診断") {
                    Button("履歴・フレーム時刻ログを書き出す") { model.exportDiagnostics() }
                    if let url = model.exportURL { ShareLink("診断JSONを共有", item: url) }
                    Text("新しい専用DBを使用します。旧Expo履歴は変更・移行しません。")
                        .font(.caption)
                }
            }
            .navigationTitle(model.delivery == "pip" ? "PiP実機検証" : "Live Activity実機検証")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.checkpointForLifecycle() }
        }
    }
}
