import SwiftUI
import UIKit

/// The what-if mail is a read-only story built from the two previous periods.
/// It is intentionally calculated from the injected fixture and never creates
/// a saved activity when it is replayed or shared.
struct MDWhatIfView: View {
    let data: MDFixtureData
    let goBack: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var period: MDWhatIfPeriod = .day
    @State private var mode: MDMode = .spend
    @State private var hideTime = false
    @State private var showAll = false
    @State private var isPlaying = false
    @State private var playbackStartedAt: Date?

    private var story: MDWhatIfStory? {
        MDWhatIfStory.make(data: data, period: period, mode: mode)
    }

    var body: some View {
        ScreenShell(id: "whatif") {
            VStack(alignment: .leading, spacing: 17) {
                BackRow(title: "もしも便", action: close)
                HStack { SampleModeBanner(); Spacer() }
                selectors
                if let story {
                    interview(story)
                    storyActions(story)
                } else {
                    emptyState
                }
            }
        }
        .onAppear {
            if story != nil { replay() }
        }
        .onDisappear { stopPlayback() }
    }

    private var selectors: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(MDWhatIfPeriod.allCases) { value in
                    Button {
                        period = value
                        stopPlayback()
                        showAll = false
                        replay()
                    } label: {
                        Text(value.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(value == period ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background {
                                if value == period { TornPaperShape().fill(MoshiDopaBrand.lime) }
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("whatif-period-\(value.rawValue)")
                }
            }
            .padding(4)
            .background(TornPaperShape().fill(MoshiDopaBrand.paper))
            HStack(spacing: 8) {
                ForEach(MDMode.allCases) { value in
                    Button {
                        mode = value
                        stopPlayback()
                        showAll = false
                        replay()
                    } label: {
                        Text(value == .spend ? "SPEND" : "自己投資")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(value == mode ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background {
                                if value == mode { TornPaperShape().fill(MoshiDopaBrand.lime) }
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("whatif-mode-\(value.rawValue.lowercased())")
                }
            }
            .padding(4)
            .background(TornPaperShape().fill(MoshiDopaBrand.paper))
        }
    }

    private func interview(_ story: MDWhatIfStory) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying || showAll || reduceMotion)) { context in
            let elapsed = currentElapsed(at: context.date, story: story)
            MDWhatIfStoryCard(story: story, elapsed: elapsed,
                              hideTime: hideTime,
                              showAll: showAll || reduceMotion)
                .contentShape(Rectangle())
                .onTapGesture { skipToEnd() }
                .accessibilityElement(children: .contain)
                .accessibilityValue("\(story.mode.rawValue)・\(showAll || reduceMotion || elapsed >= story.animationDuration ? "全文表示" : "再生中")")
                .accessibilityIdentifier("whatif-interview")
                .onChange(of: elapsed >= story.animationDuration) { _, finished in
                    if finished && isPlaying { skipToEnd() }
                }
        }
    }

    private func storyActions(_ story: MDWhatIfStory) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                PaperButton(action: skipToEnd) {
                    Label("全文を見る", systemImage: "text.justify")
                }
                .accessibilityIdentifier("whatif-skip")
                PaperButton(action: replay) {
                    Label("もう一度再生", systemImage: "arrow.counterclockwise")
                }
                .accessibilityIdentifier("whatif-replay")
            }
            .frame(maxWidth: .infinity)
            TogglePill(title: "会話では時間を伏せる", isOn: hideTime) {
                hideTime.toggle()
            }
            .accessibilityIdentifier("whatif-hide-time")
            Text(hideTime ? "返答を「時間は、ひみつです。」として表示します。" : "保存済み記録の時間を会話に表示します。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Text("集計対象：\(story.activities.joined(separator: "、"))。保存済み記録のみ。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            if let image = shareImage(story) {
                ShareLink(item: image,
                          preview: SharePreview("\(story.title) / \(mode.shortTitle)", image: image)) {
                    Label("この会話を画像で共有", systemImage: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.ink)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(TornPaperShape().fill(MoshiDopaBrand.lime))
                        .overlay(TornPaperShape().stroke(Color.white.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("share-whatif")
            }
        }
    }

    private var emptyState: some View {
        PaperCard(padding: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text("まだ、届いていません。")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.ink)
                Text("\(period.title)の\(mode == .invest ? "自己投資" : "SPEND")記録があると、ここに一つの会話が届きます。")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("記録がないことは、使った時間がゼロという意味ではありません。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("whatif-empty")
    }

    private func currentElapsed(at date: Date, story: MDWhatIfStory) -> TimeInterval {
        if showAll || reduceMotion { return story.animationDuration }
        guard isPlaying, let start = playbackStartedAt else { return 0 }
        return min(story.animationDuration, max(0, date.timeIntervalSince(start)))
    }

    private func replay() {
        guard story != nil else {
            stopPlayback()
            return
        }
        playbackStartedAt = Date()
        isPlaying = true
        showAll = false
    }

    private func skipToEnd() {
        showAll = true
        stopPlayback()
    }

    private func stopPlayback() {
        isPlaying = false
        playbackStartedAt = nil
    }

    private func close() {
        stopPlayback()
        goBack()
    }

    private func shareImage(_ story: MDWhatIfStory) -> Image? {
        Self.shareUIImage(story, hideTime: hideTime).map { Image(uiImage: $0) }
    }

    @MainActor static func shareUIImage(_ story: MDWhatIfStory, hideTime: Bool) -> UIImage? {
        previewUIImage(story, elapsed: story.animationDuration, hideTime: hideTime, showAll: true)
    }

    @MainActor static func previewUIImage(_ story: MDWhatIfStory, elapsed: TimeInterval,
                                           hideTime: Bool, showAll: Bool = false) -> UIImage? {
        MDShareImageRenderer.render(MDWhatIfStoryCard(story: story, elapsed: elapsed,
                                                     hideTime: hideTime, showAll: showAll))
    }
}

enum MDWhatIfPeriod: String, CaseIterable, Identifiable {
    case day, month

    var id: String { rawValue }
    var title: String { self == .day ? "昨日" : "先月" }
}

struct MDWhatIfStory {
    let period: MDWhatIfPeriod
    let date: Date
    let mode: MDMode
    let duration: TimeInterval
    let amount: Double
    let activities: [String]
    let itemName: String?
    let itemSymbol: String?
    let itemPrice: Int?

    static let animationLength: TimeInterval = 18.7
    var animationDuration: TimeInterval { Self.animationLength }
    var title: String { period == .day ? "昨日のもしも" : "先月のもしも" }
    var periodLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = period == .day ? "yyyy-MM-dd" : "yyyy-MM"
        return formatter.string(from: date)
    }
    var money: String {
        MoshiDopaBrand.yen(amount.rounded(.down), decimals: 0)
    }
    var timeText: String {
        let total = max(0, Int(duration.rounded(.down)))
        let hours = total / 3_600
        let minutes = total / 60 % 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)時間\(minutes)分" }
        if minutes > 0 { return "\(minutes)分\(seconds)秒" }
        return "\(seconds)秒"
    }

    func dialogue(hideTime: Bool) -> [String] {
        let when = period == .day ? "昨日" : "先月"
        if mode == .invest {
            return [
                "\(when)、自分のために使った時間は？",
                hideTime ? "時間は、ひみつです。" : "\(timeText)です。",
                "なるほど。未来の自分に、ですね。",
                "ええ、少しずつ。"
            ]
        }
        return [
            "\(when)、記録したアプリ・活動の時間は？",
            hideTime ? "時間は、ひみつです。" : "\(timeText)です。",
            itemName.map { "なるほど。あそこに\($0)がありますね。" } ?? "なるほど。まだ、小さな金額ですね。",
            itemName == nil ? "そうですね。" : "ありますね。"
        ]
    }

    var punchline: String {
        if mode == .invest { return "未来の自分に、\nこれだけ時間を投資しました。" }
        if itemName != nil { return "働いていたら、\nあれくらい買えましたね。" }
        return "この時間にも、\n値段がついていました。"
    }

    static func make(data: MDFixtureData, period: MDWhatIfPeriod, mode: MDMode) -> MDWhatIfStory? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let referenceDay = calendar.startOfDay(for: data.today)
        let start: Date
        let end: Date
        let storyDate: Date
        if period == .day {
            start = calendar.date(byAdding: .day, value: -1, to: referenceDay) ?? referenceDay
            end = referenceDay
            storyDate = start
        } else {
            let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDay)) ?? referenceDay
            end = currentMonth
            start = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
            storyDate = start
        }
        let slices = data.activities.compactMap { activity -> (MDActivity, TimeInterval)? in
            guard activity.mode == mode, activity.duration > 0 else { return nil }
            let activityEnd = activity.startedAt.addingTimeInterval(activity.duration)
            let overlap = min(end, activityEnd).timeIntervalSince(max(start, activity.startedAt))
            guard overlap > 0 else { return nil }
            return (activity, overlap)
        }
        guard !slices.isEmpty else { return nil }
        let duration = slices.reduce(0) { $0 + $1.1 }
        let amount = slices.reduce(0) { $0 + $1.0.hourlyRate * $1.1 / 3_600 }
        guard amount.isFinite, duration.isFinite else { return nil }
        let names = Dictionary(grouping: slices) { pair in
            if mode == .invest, !pair.0.project.isEmpty { return pair.0.project }
            return pair.0.activityName.isEmpty ? pair.0.appName : pair.0.activityName
        }
        let activities = names.sorted {
            let left = $0.value.reduce(0) { $0 + $1.1 }
            let right = $1.value.reduce(0) { $0 + $1.1 }
            return left == right ? $0.key < $1.key : left > right
        }.map(\.key)
        let catalog: [(String, Int, String)] = [
            ("駄菓子", 30, "🍬"), ("チョコレート", 150, "🍫"), ("コーヒー", 300, "☕"),
            ("ランチ", 1_000, "🍝"), ("ピザ", 2_500, "🍕"), ("本のセット", 5_000, "📚"),
            ("ヘッドホン", 10_000, "🎧"), ("椅子", 30_000, "🪑"), ("ゲーム機", 50_000, "🎮"),
            ("ノートPC", 150_000, "💻")
        ]
        let item = mode == .spend ? catalog.last(where: { Double($0.1) <= amount }) : nil
        return MDWhatIfStory(period: period, date: storyDate, mode: mode,
                             duration: duration, amount: amount, activities: activities,
                             itemName: item?.0, itemSymbol: item?.2, itemPrice: item?.1)
    }
}

private struct MDWhatIfStoryCard: View {
    let story: MDWhatIfStory
    let elapsed: TimeInterval
    let hideTime: Bool
    let showAll: Bool

    private var completed: Bool { showAll || elapsed >= MDWhatIfStory.animationLength }
    private var visibleDialogue: [String] {
        if completed { return story.dialogue(hideTime: hideTime) }
        let line = MDInterviewMotion.shot(elapsed).line
        return Array(story.dialogue(hideTime: hideTime).prefix(max(0,min(4,line+1))))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MOSHIDOPA  /  THE WHAT-IF INTERVIEW")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .tracking(0.5)
            Text(story.title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
            Text("\(story.periodLabel)  ·  \(story.mode.shortTitle)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.22))
            if completed { dialogueBubbles }
            MDWhatIfActorCanvas(story: story, elapsed: elapsed)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .accessibilityHidden(true)
            if !completed { currentDialogue; playbackResult }
            if completed {
                completedResult
            } else {
                Text("タップで全文を見る")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.22))
            footer
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                TornPaperShape().fill(MoshiDopaBrand.paper)
                Rectangle().fill(MoshiDopaBrand.lime).frame(height: 5).frame(maxHeight: .infinity, alignment: .top)
                Image("session_receipt_paper_texture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.045)
                    .blendMode(.multiply)
                    .clipShape(TornPaperShape())
            }
        }
        .overlay(TornPaperShape().stroke(Color.white.opacity(0.7), lineWidth: 1))
        .shadow(color: MoshiDopaBrand.paperShadow, radius: 7, y: 4)
    }

    // Keep the stage fixed during playback; the complete transcript belongs to the final card.
    private var currentDialogue: some View {
        let line = MDInterviewMotion.shot(elapsed).line
        return VStack(alignment: .leading, spacing: 8) {
            if line >= 1 && line <= 3 {
                Text(story.dialogue(hideTime: hideTime)[line-1])
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .lineLimit(2)
            }
            if line < 0 {
                Text(story.period == .day ? "昨日の自分に、聞いてみよう。" : "先月の自分に、聞いてみよう。")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
            } else {
                bubble(line == 4 ? story.punchline : (line == 5 ? (story.mode == .spend ? "…" : story.punchline) : story.dialogue(hideTime: hideTime)[line]),
                       reply: line == 1 || line == 3 || (line == 5 && story.mode == .spend))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    }

    // Reserve the amount's space from the opening frame so the camera stage never shifts.
    private var playbackResult: some View {
        VStack(alignment: .leading, spacing: 5) {
            if elapsed >= 13.5 {
                Text(story.money)
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .minimumScaleFactor(0.52)
                    .lineLimit(1)
                Text(story.mode == .invest ? "成果や売上ではなく、注いだ時間の換算額です。" : (story.itemName != nil ? "品物は価格目安のイメージです。" : "この時間にも、値段がついていました。"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 85, alignment: .topLeading)
    }
    private var dialogueBubbles: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(visibleDialogue.enumerated()), id: \.offset) { index, line in
                HStack {
                    if index.isMultiple(of: 2) { bubble(line, reply: false) }
                    else {
                        Spacer(minLength: 24)
                        bubble(line, reply: true)
                    }
                }
            }
        }
    }

    private func bubble(_ text: String, reply: Bool) -> some View {
        Text(text)
            .font(.system(size: 16, weight: reply ? .bold : .medium, design: .rounded))
            .foregroundStyle(MoshiDopaBrand.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: reply ? .infinity : nil, alignment: .leading)
            .background(TornPaperShape().fill(reply ? MoshiDopaBrand.lime : MoshiDopaBrand.bluePaper.opacity(0.42)))
            .accessibilityLabel(reply ? "若者の返答。\(text)" : "おじさんの質問。\(text)")
    }

    private var completedResult: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(story.mode == .invest ? "取り組んだこと" : "記録")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                    Text(story.activities.joined(separator: "、"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(3)
                }
                Spacer(minLength: 8)
                VStack(spacing: 3) {
                    Text(story.mode == .invest ? "↗" : (story.itemSymbol ?? "…"))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(story.mode == .invest ? "未来の自分へ" : (story.itemName ?? "小さな一歩"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                }
                .frame(width: 90, height: 78)
                .background(RoundedRectangle(cornerRadius: 18).fill(MoshiDopaBrand.bluePaper.opacity(0.48)))
            }
            Text(story.punchline)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(story.money)
                .font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundStyle(MoshiDopaBrand.ink)
                .minimumScaleFactor(0.52)
                .lineLimit(1)
                .overlay(alignment: .bottomLeading) {
                    if story.mode == .spend {
                        Rectangle().fill(MoshiDopaBrand.red).frame(width: 92, height: 4).offset(y: 5)
                    }
                }
            Text(story.mode == .spend
                 ? story.itemPrice.map { "イラストの品物：価格目安 \(MoshiDopaBrand.yen(Double($0)))" } ?? "買い物に例えられる金額になる、その前に。"
                 : "成果や売上ではなく、注いだ時間の換算額です。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("もしドパ")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Spacer()
                Text("もしもドパガキが働いたら？")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            Text("記録した時間 × 設定単価による仮定。実際の収益・損失ではありません。")
            Text("品物は価格目安のイメージです。未計測の時間は含みません。")
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(MoshiDopaBrand.mutedInk)
        .fixedSize(horizontal: false, vertical: true)
    }
}


// Android's interview uses one seekable clock for the camera, captions and actors.
// Coordinates below are its 1080-wide paper world, not independent sprite rectangles.
private enum MDInterviewMotion {
    struct Camera { var x: CGFloat; var y: CGFloat; var zoom: CGFloat }
    struct Shot { let at: Double; let focus: Int; let line: Int }
    static let shots = [Shot(at: 0, focus: 0, line: -1), Shot(at: 0.65, focus: 1, line: 0),
                        Shot(at: 3.6, focus: 2, line: 1), Shot(at: 6, focus: 1, line: 2),
                        Shot(at: 8.2, focus: 3, line: 2), Shot(at: 10.4, focus: 2, line: 3),
                        Shot(at: 12.6, focus: 1, line: 4), Shot(at: 15, focus: 2, line: 5),
                        Shot(at: 17.3, focus: 0, line: 5)]
    static let speech: [(Double, Double, Bool)] = [(0.65,3.2,false),(3.6,5.5,true),
        (6,9.8,false),(10.4,12,true),(12.6,15,false)]
    static func ease(_ value: Double) -> Double { let p = min(1,max(0,value)); return p*p*(3-2*p) }
    static func shot(_ t: Double) -> Shot { shots.last(where: { $0.at <= t }) ?? shots[0] }
    static func pose(_ focus: Int, investment: Bool) -> Camera {
        switch focus {
        case 1: return Camera(x:310,y:365,zoom:2.05*0.952)
        case 2: return Camera(x:650,y:250,zoom:2.2*0.952)
        case 3: return Camera(x:970,y:240,zoom:1.82*0.952)
        // The generated INVEST atlas is taller than the articulated SPEND rig.
        // Preserve headroom in this native 800-high viewport, including the proud pose.
        default: return investment
            ? Camera(x:480,y:320,zoom:1.38*0.952)
            : Camera(x:480,y:350,zoom:1.5*0.952)
        }
    }
    static func travel(_ age: Double) -> Double {
        if age < 0.43 { return 1.07*ease(age/0.43) }
        if age < 0.65 { return 1.07-0.07*ease((age-0.43)/0.22) }
        return 1
    }
    static func camera(_ t: Double, hasItem: Bool, investment: Bool) -> Camera {
        let index = shots.lastIndex(where: { $0.at <= t }) ?? 0
        func focus(_ s: Shot) -> Int { s.focus == 3 && !hasItem ? 1 : s.focus }
        let from = pose(focus(shots[max(0,index-1)]), investment: investment)
        let to = pose(focus(shots[index]), investment: investment)
        let p = CGFloat(travel(t-shots[index].at))
        let gain = ease(t/0.8)*ease((18.7-t)/0.9)
        return Camera(x:from.x+(to.x-from.x)*p+CGFloat((2.8*sin(t*1.7)+0.7*sin(t*7.1))*gain),
                      y:from.y+(to.y-from.y)*p+CGFloat((1.8*sin(t*2.3+0.4)+0.45*sin(t*8.3))*gain),
                      zoom:from.zoom+(to.zoom-from.zoom)*p)
    }
    static func speaking(_ t: Double, young: Bool) -> Bool {
        speech.contains { $0.2 == young && t >= $0.0 && t < $0.1 }
    }
    static func faceStart(_ t: Double, young: Bool) -> Double {
        if young { return t >= 10.4 ? 11.05 : 4.25 }
        return t >= 12.6 ? 13.25 : (t >= 6 ? 6.65 : 1.3)
    }
    static func pop(_ t: Double, _ start: Double) -> Double { ease((t-start)/0.32) }
    static func squash(_ t: Double, _ start: Double) -> (CGFloat,CGFloat) {
        let p = pop(t,start)
        if p < 0.25 { return (CGFloat(1-0.04*ease(p/0.25)),CGFloat(1+0.05*ease(p/0.25))) }
        if p < 0.55 { return (CGFloat(0.96+0.09*ease((p-0.25)/0.3)),CGFloat(1.05-0.08*ease((p-0.25)/0.3))) }
        return (CGFloat(1.05-0.05*ease((p-0.55)/0.45)),CGFloat(0.97+0.03*ease((p-0.55)/0.45)))
    }
    static func spring(_ age: Double) -> Double {
        if age < 0 || age >= 0.9 { return 0 }
        if age < 0.09 { return -0.65*ease(age/0.09) }
        let u = (age-0.09)/0.81
        return (-0.65*cos(u*Double.pi*5)+2.1*sin(u*Double.pi*5))*exp(-4*u)*(1-ease((u-0.75)/0.25))
    }
    static func beats(_ t: Double, young: Bool) -> [Double] {
        var starts: [Double] = []
        for line in speech where line.2 == young {
            starts += [line.0,line.0+0.65]
            var beat = line.0+1.5
            while beat < line.1-0.5 { starts.append(beat); beat += 1.2 }
        }
        return starts
    }
    static func bounce(_ t: Double, young: Bool, shocked: Bool = false) -> CGFloat {
        if shocked { return 0 }
        var value = 0.0
        for line in speech where line.2 == young {
            value += 0.12*spring(t-line.0)+0.16*spring(t-line.0-0.65)
            var beat = line.0+1.5
            while beat < line.1-0.5 { value += 0.055*spring(t-beat); beat += 1.2 }
        }
        if young { value += 0.16*spring(t-16.3) }
        return CGFloat(min(0.3,max(-0.18,value))*0.3)
    }
    static func hand(_ t: Double, _ start: Double, young: Bool) -> Double {
        let age = t-start
        if age <= 0 || (young && t >= 15.65) { return 0 }
        let gate = beats(t,young:young).map { beat -> Double in
            let a = t-beat
            if a < 0 { return 0 }
            if a < 0.9 { return min(1,abs(spring(a))) }
            if a < 1.9 { let p = a-0.9; return 2.2*p*(1-p)*(1-p) }
            return 0
        }.max() ?? 0
        return (1.45*sin(age/0.41*2*Double.pi)+0.48*sin(age/0.235*2*Double.pi))*(1-exp(-age/0.26))*gate
    }
    static func nod(_ t: Double, _ start: Double) -> Double {
        let p = min(1,max(0,(t-start)/0.78)); return -3*sin(p*Double.pi)
    }
}

private enum MDInterviewSprites {
    // Crop only at load time; keep the sheet's original alpha and RGB pixels.
    static let shortHeads: [UIImage] = {
        guard let sheet = UIImage(named:"whatif_old_short_sheet_v2")?.cgImage else { return [] }
        return [CGRect(x:298,y:133,width:233,height:200), CGRect(x:301,y:353,width:233,height:200),
                CGRect(x:158,y:567,width:273,height:417)].compactMap { sheet.cropping(to:$0).map { UIImage(cgImage:$0) } }
    }()
}

private struct MDWhatIfActorCanvas: View {
    let story: MDWhatIfStory
    let elapsed: TimeInterval

    var body: some View {
        Canvas { canvas, size in
            let t = min(18.7,max(0,elapsed))
            let scale = min(size.width/1080,size.height/800)
            var context = canvas
            context.translateBy(x:(size.width-1080*scale)/2,y:0)
            context.scaleBy(x:scale,y:scale)
            context.clip(to:Path(CGRect(x:0,y:0,width:1080,height:800)))
            let camera = MDInterviewMotion.camera(t,hasItem:story.itemName != nil,investment:story.mode == .invest)
            let gain = MDInterviewMotion.ease(t/0.8)*MDInterviewMotion.ease((18.7-t)/0.9)
            context.translateBy(x:540,y:315)
            context.rotate(by:.degrees((0.18*sin(t*1.3)+0.04*sin(t*6.7))*gain))
            context.scaleBy(x:camera.zoom,y:camera.zoom)
            context.translateBy(x:-camera.x,y:-camera.y)
            drawActors(context,t:t)
            if let symbol = story.itemSymbol, let name = story.itemName {
                var prop = context
                prop.translateBy(x:970,y:310)
                prop.scaleBy(x:0.7,y:0.7)
                prop.translateBy(x:-1190,y:-440)
                let shot = MDInterviewMotion.shot(t)
                let age = t-shot.at-0.65
                let landing = shot.focus == 3 && age >= 0 && age <= 0.54
                    ? 0.16*sin(age/0.54*2*Double.pi)*(1-age/0.54) : 0
                prop.translateBy(x:1190,y:530)
                prop.scaleBy(x:1-CGFloat(landing)*0.65,y:1+CGFloat(landing))
                prop.translateBy(x:-1190,y:-530)
                prop.fill(Path(ellipseIn:CGRect(x:1045,y:545,width:290,height:35)),with:.color(MoshiDopaBrand.lime.opacity(0.35)))
                prop.draw(Text(symbol).font(.system(size:230)),at:CGPoint(x:1190,y:440))
                prop.draw(Text(name).font(.system(size:34,weight:.bold,design:.rounded)).foregroundColor(MoshiDopaBrand.ink),at:CGPoint(x:1190,y:610))
            }
            // Android fades only the bottom silhouette; captions are outside the camera.
            var paper = canvas
            paper.translateBy(x:(size.width-1080*scale)/2,y:0)
            paper.scaleBy(x:scale,y:scale)
            paper.fill(Path(CGRect(x:0,y:560,width:1080,height:240)),with:.linearGradient(
                Gradient(colors:[MoshiDopaBrand.paper.opacity(0),MoshiDopaBrand.paper.opacity(0.53),MoshiDopaBrand.paper]),
                startPoint:CGPoint(x:0,y:560),endPoint:CGPoint(x:0,y:800)))
        }
        .accessibilityLabel("もしも便のインタビュー。二人の会話")
    }

    private func drawActors(_ context: GraphicsContext, t: Double) {
        func image(_ name: String) -> UIImage? { UIImage(named:name) }
        func part(_ c: GraphicsContext, _ ui: UIImage?, x:CGFloat, y:CGFloat, scale:CGFloat,
                  ax:CGFloat = 0, ay:CGFloat = 0, angle:Double = 0, scaleY:CGFloat? = nil) {
            guard let ui else { return }
            var c = c; c.translateBy(x:x,y:y); c.rotate(by:.degrees(angle))
            c.scaleBy(x:scale,y:scaleY ?? scale)
            c.draw(Image(uiImage:ui),in:CGRect(x:-ax,y:-ay,width:ui.size.width,height:ui.size.height))
        }
        if story.mode == .invest {
            drawInvestment(context,t:t)
            return
        }
        let speaking = MDInterviewMotion.speaking(t,young:false)
        let start = MDInterviewMotion.faceStart(t,young:false)
        let pointing = story.itemName != nil && t >= 7.7 && t < 10.4
        let armStart = pointing ? 7.7 : start
        let p = MDInterviewMotion.pop(t,armStart)
        let wobble = MDInterviewMotion.hand(t,armStart,young:false)
        let armScale = CGFloat(0.97+0.03*p+0.012*sin(p*Double.pi))
        let settle = CGFloat(sin(p*Double.pi)*4)
        let bounce = MDInterviewMotion.bounce(t,young:false)
        var old = context; old.translateBy(x:310,y:609); old.scaleBy(x:1/(1+bounce),y:1+bounce)
        if speaking && !pointing {
            part(old,image("whatif_part_old_self_mic_v3"),x:15+CGFloat(12*(1-p))-settle,y:-266,scale:0.42*armScale,ax:240,ay:475,angle:12+2*(1-p)+wobble)
        } else if pointing {
            part(old,image("whatif_part_old_point"),x:55-CGFloat(25*(1-p))+settle,y:-212,scale:0.4*armScale,ax:15,ay:65,angle:-25-3*sin(p*Double.pi)+wobble)
        } else { part(old,image("whatif_part_old_arm"),x:55,y:-245,scale:0.4,ax:15,ay:100,angle:-12+wobble) }
        let sprites = MDInterviewSprites.shortHeads
        part(old,sprites.count == 3 ? sprites[2] : image("whatif_part_old_body"),x:-100,y:-266.25,scale:0.75)
        let squash = speaking ? MDInterviewMotion.squash(t,start) : (CGFloat(1),CGFloat(1))
        let headIndex = speaking && MDInterviewMotion.pop(t,start) >= 0.55 ? 1 : 0
        part(old,sprites.count == 3 ? sprites[headIndex] : image("whatif_part_old_normal"),x:18,y:-256,scale:0.76*squash.0,ax:125,ay:170,angle:speaking ? MDInterviewMotion.nod(t,start) : 0,scaleY:0.76*squash.1)

        let shocked = story.mode == .spend && t >= 15.65
        let youngBounce = MDInterviewMotion.bounce(t,young:true,shocked:shocked)
        let sink = shocked ? CGFloat(1-0.16*MDInterviewMotion.ease((t-15.65)/(18.7-15.65))) : 1
        var young = context; young.translateBy(x:660,y:655)
        young.scaleBy(x:1/(1+youngBounce),y:sink*(1+youngBounce))
        part(young,image("whatif_part_young_body"),x:-75,y:-373,scale:0.5)
        let youngStart = MDInterviewMotion.faceStart(t,young:true)
        part(young,image("whatif_part_young_arm"),x:63,y:-315,scale:0.51,ax:85,ay:35,angle:MDInterviewMotion.hand(t,youngStart,young:true))
        young.translateBy(x:19,y:-350)
        if shocked {
            let reaction = MDInterviewMotion.ease((t-15.65)/0.3)
            young.translateBy(x:CGFloat(6*reaction),y:CGFloat(-2.5*reaction))
            young.translateBy(x:124.8,y:168); young.rotate(by:.degrees(-4.5*reaction)); young.translateBy(x:-124.8,y:-168)
            let s = MDInterviewMotion.squash(t,15.65); young.scaleBy(x:s.0,y:s.1); young.translateBy(x:-0.5,y:-1)
            face(young,name:MDInterviewMotion.pop(t,15.65) >= 0.55 ? "whatif_part_young_shock" : "whatif_part_young_normal")
        } else if MDInterviewMotion.speaking(t,young:true) {
            let s = MDInterviewMotion.squash(t,youngStart)
            let name = MDInterviewMotion.pop(t,youngStart) >= 0.55 ? "whatif_part_young_talk" : "whatif_part_young_normal"
            part(young,image(name),x:0.6*104*(1-s.0),y:0.6*23*(1-s.1),scale:0.6*s.0,ax:208,ay:280,angle:MDInterviewMotion.nod(t,youngStart),scaleY:0.6*s.1)
        } else { face(young,name:"whatif_part_young_normal") }
    }

    private func drawInvestment(_ context: GraphicsContext, t: Double) {
        var world = context; world.translateBy(x:125,y:33); world.scaleBy(x:0.65,y:0.65)
        for young in [false,true] {
            let cells = young ? MDInvestmentSprites.young : MDInvestmentSprites.old
            guard cells.count == 12 else { continue }
            let final = story.amount >= 10_000 ? 11 : 10
            let index: Int
            if young && t >= 15.65 { index = final }
            else if MDInterviewMotion.speaking(t,young:young) { index = 1 }
            else if t >= 16.2 { index = final }
            else { index = 0 }
            let cell = cells[index]
            let scale: CGFloat = (young ? 865 : 737)/cells[0].image.size.height
            let x: CGFloat = young ? 720 : 285
            let bounce = MDInterviewMotion.bounce(t,young:young)
            var actor = world; actor.translateBy(x:x,y:957); actor.scaleBy(x:1/(1+bounce),y:1+bounce)
            actor.draw(Image(uiImage:cell.image),in:CGRect(x:-cell.foot.x*scale,y:-cell.foot.y*scale,
                       width:cell.image.size.width*scale,height:cell.image.size.height*scale))
        }
    }
    private func face(_ context: GraphicsContext, name: String) {
        let resolved = context.resolve(Image(name))
        let k = min(317/resolved.size.width,305/resolved.size.height)
        let w = resolved.size.width*k, h = resolved.size.height*k
        var c = context; c.scaleBy(x:0.6,y:0.6)
        c.draw(resolved,in:CGRect(x:-208+(317-w)/2,y:-280+(305-h)/2,width:w,height:h))
    }
}


// Investment keeps Android's positive generated poses, including feet registration
// and native magenta removal. Catalog source PNGs are never modified.
private enum MDInvestmentSprites {
    struct Cell { let image: UIImage; let foot: CGPoint }
    static let old = load("whatif_interviewer_poses")
    static let young = load("whatif_young_poses")
    static func load(_ name: String) -> [Cell] {
        guard let source = UIImage(named:name)?.cgImage else { return [] }
        let width = source.width, height = source.height
        var pixels = [UInt8](repeating:0,count:width*height*4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let c = CGContext(data:buffer.baseAddress,width:width,height:height,bitsPerComponent:8,
                                    bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.draw(source,in:CGRect(x:0,y:0,width:CGFloat(width),height:CGFloat(height))); return true
        }
        guard rendered else { return [] }
        for i in stride(from:0,to:pixels.count,by:4) {
            let r = Int(pixels[i]), g = Int(pixels[i+1]), b = Int(pixels[i+2])
            let key = max(0,min(r,b)-g)
            if key > 12 {
                let alpha = 255-key
                if alpha < 64 { pixels[i+3] = 0 }
                else {
                    pixels[i] = UInt8(min(255,max(0,(r-key)*255/alpha)))
                    pixels[i+1] = UInt8(min(255,max(0,g*255/alpha)))
                    pixels[i+2] = UInt8(min(255,max(0,(b-key)*255/alpha)))
                    pixels[i+3] = UInt8(alpha)
                }
            }
        }
        guard let provider = CGDataProvider(data:Data(pixels) as CFData),
              let sheet = CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
                                  space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),
                                  provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else { return [] }
        return (0..<12).compactMap { index in
            let left = index%3*width/3, right = (index%3+1)*width/3
            let top = index/3*height/4, bottom = (index/3+1)*height/4
            var x0 = right, x1 = left, y0 = bottom, y1 = top
            for y in top..<bottom {
                for x in left..<right where pixels[(y*width+x)*4+3] > 64 {
                    x0 = min(x0,x); x1 = max(x1,x+1); y0 = min(y0,y); y1 = max(y1,y+1)
                }
            }
            guard x1 > x0, y1 > y0 else { return nil }
            var footLeft = x1, footRight = x0
            for y in (y1-(y1-y0)/8)..<y1 {
                for x in x0..<x1 where pixels[(y*width+x)*4+3] > 64 {
                    footLeft = min(footLeft,x); footRight = max(footRight,x)
                }
            }
            let bounds = CGRect(x:CGFloat(max(left,x0-2)),y:CGFloat(max(top,y0-2)),
                                width:CGFloat(min(right,x1+2)-max(left,x0-2)),height:CGFloat(min(bottom,y1+2)-max(top,y0-2)))
            guard let crop = sheet.cropping(to:bounds) else { return nil }
            return Cell(image:UIImage(cgImage:crop),foot:CGPoint(x:CGFloat(footLeft+footRight)/2-bounds.minX,y:CGFloat(y1)-bounds.minY))
        }
    }
}
