import SwiftUI
import AVKit
import AVFAudio

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
    let layer = AVSampleBufferDisplayLayer()
    // Retain the real source view as well as its layer when the diagnostics sheet closes.
    lazy var inlineHost = MoneyLayerHostView(layer: layer)
    private var service: SessionService?
    private var events: PiPEventStore?
    private var controller: AVPictureInPictureController?
    private var observation: NSKeyValueObservation?
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
        if AVPictureInPictureController.isPictureInPictureSupported() {
            controller = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: layer, playbackDelegate: self))
            controller?.delegate = self
            controller?.canStartPictureInPictureAutomaticallyFromInline = false
            controller?.requiresLinearPlayback = true
            observation = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] _, change in
                let value = change.newValue ?? false
                Task { @MainActor [weak self] in self?.possible = value }
            }
        } else { pipStatus = "この端末ではPiP非対応" }
    }

    func attach() {
        attached = true
        guard timer == nil else { return }
        render()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func startMeasurement() {
        perform {
            guard let service else { throw SessionError.missingSession }
            guard let rate = Double(hourlyRateText) else { throw SessionError.invalidRate }
            snapshot = try service.start(hourlyRate: rate)
            presentationPaused = false
            history = try service.history()
            try log("measurement_started")
            render()
            controller?.invalidatePlaybackState()
        }
    }

    func startPiP() {
        perform {
            guard snapshot != nil, attached, let controller else { throw SessionError.missingSession }
            presentationPaused = false
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audio.setActive(true)
            audioActive = true
            var requested = false
            defer {
                if !requested { deactivateAudio() }
            }
            render()
            controller.invalidatePlaybackState()
            guard controller.isPictureInPicturePossible else {
                deactivateAudio()
                pipStatus = "PiP準備待ち。インライン表示を確認して再試行してください。"
                try log("pip_not_possible")
                return
            }
            try log("pip_user_requested")
            pipStatus = "PiP開始要求中"
            requested = true
            controller.startPictureInPicture()
        }
    }

    func stopAndSave() {
        perform {
            guard let id = snapshot?.id, let service else { throw SessionError.missingSession }
            let finished = try service.stop(sessionID: id)
            // Stop the external presentation only after the result is durable.
            controller?.stopPictureInPicture()
            snapshot = nil
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
                let validation: String
                let records: [SessionRecord]
                let eventJSONLines: String
            }
            let data = Export(schema: 1, generatedAt: Date(), operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                model: UIDevice.current.model, validation: "Device PiP acceptance is unverified until recorded manual test", records: try service.history(),
                eventJSONLines: String(decoding: try Data(contentsOf: events.url), as: UTF8.self))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("MoshiDopa-PiP-\(UUID().uuidString).json")
            try encoder.encode(data).write(to: url, options: .atomic)
            exportURL = url
        }
    }

    private func tick(forceCheckpoint: Bool = false) {
        snapshot = service?.snapshot()
        let now = ProcessInfo.processInfo.systemUptime
        if snapshot?.state == .running, forceCheckpoint || now - lastCheckpoint >= 5 {
            perform {
                try service?.checkpoint()
                lastCheckpoint = now
            }
        }
        if snapshot != nil || controller?.isPictureInPictureActive == true { render() }
    }

    private func render() {
        guard !presentationPaused else { return }
        do {
            if layer.status == .failed {
                try log("layer_failed", detail: layer.error?.localizedDescription ?? "unknown")
                layer.flush()
            }
            guard layer.isReadyForMoreMediaData else {
                if snapshot != nil { try log("frame_backpressure") }
                return
            }
            let frame = try renderer.sample(record: snapshot, presentationSeconds: ProcessInfo.processInfo.systemUptime)
            layer.enqueue(frame)
            if snapshot != nil { try log("frame_enqueued", detail: "pipActive=\(controller?.isPictureInPictureActive ?? false); appState=\(UIApplication.shared.applicationState.rawValue)") }
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
    let sampleLayer: AVSampleBufferDisplayLayer
    init(layer: AVSampleBufferDisplayLayer) {
        sampleLayer = layer
        super.init(frame: .zero)
        self.layer.addSublayer(layer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func layoutSubviews() { super.layoutSubviews(); sampleLayer.frame = bounds }
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
                Section("P2B · 実金額PiP検証") {
                    MoneyInlinePlayer(model: model).aspectRatio(16 / 9, contentMode: .fit)
                    Text(model.snapshot.map { String(format: "%@ ¥%.2f · 開始時給 ¥%.2f", $0.state == .finished ? "保存待ち" : "計測中", $0.amount, $0.hourlyRateAtStart) } ?? "計測していません")
                        .monospacedDigit().accessibilityIdentifier("pip-current-amount")
                    TextField("次回の時給（円）", text: $model.hourlyRateText).keyboardType(.decimalPad)
                        .accessibilityIdentifier("pip.hourlyRate")
                    Text("時給変更は次回の計測から適用します。")
                        .font(.caption)
                    Button("1. 計測開始") { model.startMeasurement() }.disabled(model.snapshot != nil)
                        .accessibilityIdentifier("pip-start-session")
                    Button("2. PiP開始") { model.startPiP() }.disabled(model.snapshot == nil)
                        .accessibilityIdentifier("pip-start-window")
                    Button("3. 停止・保存") { model.stopAndSave() }.disabled(model.snapshot == nil)
                        .accessibilityIdentifier("pip-stop-session")
                    Text(model.pipStatus)
                    Text("PiP開始可否: \(model.possible ? "準備完了" : "準備待ち/利用不可")")
                        .font(.caption)
                    Text("他アプリ中の1秒更新・音声共存は未検証です。表示を閉じても計測は終了しません。")
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
            .navigationTitle("PiP実機検証")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.checkpointForLifecycle() }
        }
    }
}
