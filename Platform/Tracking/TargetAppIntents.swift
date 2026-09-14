import AppIntents
import Foundation

enum TrackingIntentError: LocalizedError {
    case wrongMode, notArmed, emptyTarget, operationFailed(String)
    var errorDescription: String? {
        switch self {
        case .wrongMode: return "もしドパの計測方法を「対象アプリの開閉（Shortcuts）」にしてください。"
        case .notArmed: return "もしドパで先に「待機開始」を押してください。終了・強制終了後は再度待機開始が必要です。"
        case .emptyTarget: return "対象アプリ名を入力してください。"
        case .operationFailed(let message): return message
        }
    }
}

/// LiveActivityIntent executes in the host app process, sharing its session owner.
/// No extension/process opens the app's SQLite database concurrently.
struct TargetAppOpenedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "対象アプリの計測を再開"
    static var description = IntentDescription("対象アプリを開いたShortcutsオートメーションから実行します。先にもしドパで待機開始してください。")
    static var openAppWhenRun = false
    @Parameter(title: "対象アプリ名", default: "Instagram") var appName: String

    @MainActor func perform() async throws -> some IntentResult {
        try PiPDiagnosticsModel.shared.targetAppChanged(name: appName, opened: true)
        return .result()
    }
}

struct TargetAppClosedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "対象アプリの計測を一時停止"
    static var description = IntentDescription("対象アプリを閉じたShortcutsオートメーションから実行します。開閉で同じ対象アプリ名を指定します。")
    static var openAppWhenRun = false
    @Parameter(title: "対象アプリ名", default: "Instagram") var appName: String

    @MainActor func perform() async throws -> some IntentResult {
        try PiPDiagnosticsModel.shared.targetAppChanged(name: appName, opened: false)
        return .result()
    }
}

struct MoshiDopaTrackingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TargetAppOpenedIntent(), phrases: ["\(.applicationName)で対象アプリの計測を再開"],
                    shortTitle: "対象アプリの計測を再開", systemImageName: "play.fill")
        AppShortcut(intent: TargetAppClosedIntent(), phrases: ["\(.applicationName)で対象アプリの計測を一時停止"],
                    shortTitle: "対象アプリの計測を一時停止", systemImageName: "pause.fill")
    }
}
