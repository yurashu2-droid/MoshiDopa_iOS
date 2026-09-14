import ActivityKit
import Foundation
import UIKit

@MainActor
final class MoneyLiveActivityController {
    private var activity: Activity<MoneyActivityAttributes>?
    private(set) var status = "未開始"

    /// ActivityKit acceptance is not confirmation that the OS rendered the extension.
    var diagnostics: [String: String] {
        let extensionURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent("MoneyLiveActivityWidget.appex")
        let extensionBundle = extensionURL.flatMap { Bundle(url: $0) }
        return [
            "authorizationEnabled": String(ActivityAuthorizationInfo().areActivitiesEnabled),
            "status": status,
            "appBundleID": Bundle.main.bundleIdentifier ?? "missing",
            "extensionBundleID": extensionBundle?.bundleIdentifier ?? "missing",
            "extensionExecutableExists": String(extensionBundle?.executableURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false),
            "activities": Activity<MoneyActivityAttributes>.activities.map { "\($0.id):\(String(describing: $0.activityState)):session=\($0.attributes.sessionID)" }.joined(separator: ";"),
            "osRendering": "unverified; ActivityKit does not report visible widget pixels"
        ]
    }

    enum RequestError: LocalizedError {
        case disabled, foregroundRequired, alreadyActive
        var errorDescription: String? {
            switch self {
            case .disabled: return "Live Activityが許可されていません。設定を確認してください。"
            case .foregroundRequired: return "Live Activityはアプリを開いている間に開始してください。"
            case .alreadyActive: return "Live Activityがすでにあります。終了してから再試行してください。"
            }
        }
    }

    /// Request stays synchronous so a user foreground action starts the activity before yielding.
    func start(record: SessionRecord, style: String, isCounting: Bool = false) throws {
        guard UIApplication.shared.applicationState == .active else {
            status = "開始不可：アプリが前面にありません"
            throw RequestError.foregroundRequired
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "開始不可：Live Activityが無効です"
            throw RequestError.disabled
        }
        guard Activity<MoneyActivityAttributes>.activities.isEmpty else {
            status = "開始不可：既存のLive Activityを終了してください"
            throw RequestError.alreadyActive
        }
        do {
            activity = try Activity.request(
                attributes: MoneyActivityAttributes(sessionID: record.id, startedAt: record.startedAt,
                                                    style: ["paper", "ink", "frost", "sticker"].contains(style) ? style : "paper"),
                content: content(record, isCounting: isCounting), pushType: nil)
            status = "開始受付済み（OS表示は別途確認）"
        } catch {
            status = "開始失敗：\(error.localizedDescription)"
            throw error
        }
    }

    func update(record: SessionRecord, isCounting: Bool) async {
        guard let target = matching(record.id) else { status = "Live Activityは終了または非表示です"; return }
        guard target.activityState == .active || target.activityState == .stale else {
            activity = nil
            status = "Live Activityは終了または非表示です"
            return
        }
        await target.update(content(record, isCounting: isCounting))
        status = isCounting ? "開始受付済み・更新送信済み（OS表示は別途確認）" : "開始受付済み・計測一時停止（OS表示は別途確認）"
    }

    func end(record: SessionRecord) async {
        for target in Activity<MoneyActivityAttributes>.activities where target.attributes.sessionID == record.id {
            await target.end(content(record, isCounting: false), dismissalPolicy: .immediate)
        }
        if activity?.attributes.sessionID == record.id { activity = nil }
        status = "終了"
    }

    /// Relaunch interrupts durable sessions; never leave their old counting label visible.
    func endOrphans() async {
        for target in Activity<MoneyActivityAttributes>.activities {
            if target.id == activity?.id { continue }
            var state = target.content.state
            state.isCounting = false
            // Preserve the last real sample timestamp rather than suggesting a fresh money sample.
            await target.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
        if activity == nil { status = "終了" }
    }

    private func matching(_ id: UUID) -> Activity<MoneyActivityAttributes>? {
        if let activity, activity.attributes.sessionID == id { return activity }
        return Activity<MoneyActivityAttributes>.activities.first { $0.attributes.sessionID == id }
    }

    private func content(_ record: SessionRecord, isCounting: Bool) -> ActivityContent<MoneyActivityAttributes.ContentState> {
        let now = Date()
        let counting = isCounting && record.state == .running
        return ActivityContent(state: .init(amount: record.amount, hourlyRate: record.hourlyRateAtStart,
            elapsedMilliseconds: record.elapsedMilliseconds, isCounting: counting, updatedAt: now),
            staleDate: counting ? now.addingTimeInterval(15) : nil)
    }
}
