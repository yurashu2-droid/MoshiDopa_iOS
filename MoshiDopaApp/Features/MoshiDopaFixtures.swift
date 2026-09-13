import Foundation

enum MDFixture: String, CaseIterable {
    case empty, populated, large
}

enum MDMode: String, CaseIterable, Identifiable {
    case spend = "SPEND"
    case invest = "INVEST"

    var id: String { rawValue }
    var title: String { self == .spend ? "SPEND / 消費" : "INVEST / 自己投資" }
    var shortTitle: String { self == .spend ? "SPEND" : "INVEST" }
    var accentTitle: String { self == .spend ? "使う時間" : "自分に投資する時間" }
}

enum MDPeriod: String, CaseIterable, Identifiable {
    case day, week, month

    var id: String { rawValue }
    var title: String {
        switch self {
        case .day: return "日"
        case .week: return "週"
        case .month: return "月"
        }
    }
    var explanatoryTitle: String {
        switch self {
        case .day: return "今日"
        case .week: return "今週"
        case .month: return "今月"
        }
    }
}

enum MDRoute: String, CaseIterable {
    case home, history, settings, measurement, counter, receipt, statement, onboarding, whatif

    static func parse(_ value: String?) -> MDRoute {
        guard let value else { return .home }
        return MDRoute(rawValue: value.lowercased()) ?? .home
    }
}

enum MDCounterDelivery: String, CaseIterable, Identifiable {
    case pip, liveActivity

    var id: String { rawValue }
    var title: String { self == .pip ? "PiP / 小さなウインドウ" : "Live Activity / ロック画面など" }
    var compactTitle: String { self == .pip ? "PiP" : "Live Activity" }
    var description: String {
        self == .pip
            ? "他のアプリの上に表示。iPhone本体で開始してから移動します。"
            : "ロック画面やDynamic Islandに更新時点の金額を表示します。"
    }
}

enum MDCounterStyle: String, CaseIterable, Identifiable {
    case paper, ink, frost, sticker

    var id: String { rawValue }
    var label: String {
        switch self {
        case .paper: return "A ちぎり値札"
        case .ink: return "B インクメーター"
        case .frost: return "C フロストラベル"
        case .sticker: return "D 相棒シール"
        }
    }
    var subtitle: String {
        switch self {
        case .paper: return "動画に、小さな紙の値札を。"
        case .ink: return "細い黒のラベルで、すっきり。"
        case .frost: return "乳白色の、やわらかな奥行き。"
        case .sticker: return "もしドパの相棒を、そばに。"
        }
    }
}

struct MDActivity: Identifiable, Hashable {
    let id: UUID
    var appName: String
    var activityName: String
    var mode: MDMode
    var startedAt: Date
    var duration: TimeInterval
    var hourlyRate: Double
    var project: String
    var note: String

    var amount: Double { duration / 3600 * hourlyRate }
    var modeColorName: String { mode == .spend ? "spend" : "invest" }
}

struct MDLaunchConfiguration {
    let route: MDRoute
    let fixture: MDFixture

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        func value(after key: String) -> String? {
            guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        route = MDRoute.parse(value(after: "--screen"))
        fixture = MDFixture(rawValue: value(after: "--fixture")?.lowercased() ?? "populated") ?? .populated
    }
}

struct MDFixtureData {
    var fixture: MDFixture
    var hourlyRate: Double?
    var activities: [MDActivity]
    var selectedCounterDelivery: MDCounterDelivery
    var pipStyle: MDCounterStyle
    var liveStyle: MDCounterStyle

    var spendActivities: [MDActivity] { activities.filter { $0.mode == .spend } }
    var investActivities: [MDActivity] { activities.filter { $0.mode == .invest } }
    var today: Date { Self.referenceDate }
    var todayActivities: [MDActivity] { activities(for: .day, anchorDay: 13) }
    var spendAmount: Double { todayActivities.filter { $0.mode == .spend }.reduce(0) { $0 + $1.amount } }
    var investAmount: Double { todayActivities.filter { $0.mode == .invest }.reduce(0) { $0 + $1.amount } }
    var totalDuration: TimeInterval { activities.reduce(0) { $0 + $1.duration } }

    static let referenceDate = date(13, 0)

    func activities(for period: MDPeriod, mode: MDMode? = nil, anchorDay: Int = 13) -> [MDActivity] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        var anchorComponents = DateComponents()
        anchorComponents.calendar = calendar
        anchorComponents.timeZone = calendar.timeZone
        anchorComponents.year = 2026
        anchorComponents.month = 9
        anchorComponents.day = anchorDay
        let anchorDate = calendar.date(from: anchorComponents) ?? Self.referenceDate
        let start: Date
        let end: Date
        switch period {
        case .day:
            start = calendar.startOfDay(for: anchorDate)
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: anchorDate)) ?? anchorDate
            end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: anchorDate)) ?? anchorDate
        case .month:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorDate)) ?? anchorDate
            start = monthStart
            end = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        }
        let selected = activities.filter { activity in
            activity.startedAt >= start && activity.startedAt < end
        }
        guard let mode else { return selected }
        return selected.filter { $0.mode == mode }
    }

    static func make(_ fixture: MDFixture) -> MDFixtureData {
        let data = fixture == .empty ? [] : (fixture == .large ? makeLargeActivities() : makePopulatedActivities())
        return MDFixtureData(fixture: fixture, hourlyRate: fixture == .empty ? nil : 1_800,
                             activities: data, selectedCounterDelivery: .pip,
                             pipStyle: .paper, liveStyle: .paper)
    }

    private static func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 9) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        components.year = 2026
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    private static func makePopulatedActivities() -> [MDActivity] {
        [
            MDActivity(id: UUID(), appName: "YouTube", activityName: "YouTubeを見る", mode: .spend,
                       startedAt: date(13, 9, 10), duration: 2_580, hourlyRate: 1_800, project: "", note: ""),
            MDActivity(id: UUID(), appName: "Instagram", activityName: "Instagram", mode: .spend,
                       startedAt: date(13, 14, 20), duration: 1_410, hourlyRate: 1_800, project: "", note: ""),
            MDActivity(id: UUID(), appName: "手動記録", activityName: "個人開発", mode: .invest,
                       startedAt: date(13, 19, 0), duration: 5_400, hourlyRate: 1_800,
                       project: "MoshiDopa iOS", note: "紙の画面を整えた"),
            MDActivity(id: UUID(), appName: "手動記録", activityName: "読書", mode: .invest,
                       startedAt: date(12, 7, 30), duration: 2_400, hourlyRate: 1_800,
                       project: "学び", note: ""),
            MDActivity(id: UUID(), appName: "YouTube", activityName: "音楽を聴く", mode: .spend,
                       startedAt: date(11, 21, 0), duration: 3_180, hourlyRate: 1_800, project: "", note: ""),
            MDActivity(id: UUID(), appName: "TikTok", activityName: "TikTok", mode: .spend,
                       startedAt: date(12, 8, 0), duration: 2_100, hourlyRate: 1_800, project: "", note: ""),
            MDActivity(id: UUID(), appName: "Instagram", activityName: "先月の写真を見る", mode: .spend,
                       startedAt: date(20, 13, 0, month: 8), duration: 3_000, hourlyRate: 1_800, project: "", note: ""),
            MDActivity(id: UUID(), appName: "手動記録", activityName: "先月の個人開発", mode: .invest,
                       startedAt: date(18, 19, 0, month: 8), duration: 5_400, hourlyRate: 1_800,
                       project: "先月の制作", note: "積み上げた時間")
        ]
    }

    private static func makeLargeActivities() -> [MDActivity] {
        let titles = ["YouTubeを見る", "Instagram", "TikTok", "ニュースを読む", "メッセージ", "デザイン調査",
                      "個人開発", "プロトタイプを磨く", "読書", "運動", "長いINVEST活動名でも紙からこぼれないか確認", "大きな金額の表示確認"]
        let generated = titles.enumerated().map { index, title in
            let mode: MDMode = index % 3 == 0 ? .spend : (index % 2 == 0 ? .invest : .spend)
            let day = index >= 10 ? 13 : 1 + (index % 13)
            let isLargeValue = index == titles.count - 1
            let duration = isLargeValue ? 360_000 : TimeInterval(780 + index * 477)
            let rate = isLargeValue ? 12_345.6789 : 2_200
            return MDActivity(id: UUID(), appName: mode == .invest ? "手動記録" : title,
                              activityName: title, mode: mode, startedAt: date(day, 7 + (index % 13)),
                              duration: duration, hourlyRate: rate,
                              project: mode == .invest ? "生活のアップデート計画" : "",
                              note: mode == .invest ? "毎日少しずつ進める" : "")
        }
        return generated + [
            MDActivity(id: UUID(), appName: "YouTube", activityName: "昨日の動画", mode: .spend,
                       startedAt: date(12, 8), duration: 1_800, hourlyRate: 2_200, project: "", note: ""),
            MDActivity(id: UUID(), appName: "手動記録", activityName: "昨日の自己投資", mode: .invest,
                       startedAt: date(12, 20), duration: 4_200, hourlyRate: 2_200,
                       project: "昨日の制作", note: "サンプルの制作メモ"),
            MDActivity(id: UUID(), appName: "Instagram", activityName: "先月の写真", mode: .spend,
                       startedAt: date(20, 13, month: 8), duration: 2_400, hourlyRate: 2_200, project: "", note: ""),
            MDActivity(id: UUID(), appName: "手動記録", activityName: "先月の長いINVEST記録", mode: .invest,
                       startedAt: date(18, 19, month: 8), duration: 7_200, hourlyRate: 2_200,
                       project: "大きな計画", note: "サンプルの制作メモ")
        ]
    }
}

extension MDActivity {
    static func sample(mode: MDMode = .spend) -> MDActivity {
        MDActivity(id: UUID(), appName: mode == .spend ? "YouTube" : "手動記録",
                   activityName: mode == .spend ? "YouTubeを見る" : "サンプル活動", mode: mode,
                   startedAt: MDFixtureData.referenceDate, duration: 0, hourlyRate: 1_800,
                   project: mode == .invest ? "サンプルプロジェクト" : "", note: "")
    }
}
