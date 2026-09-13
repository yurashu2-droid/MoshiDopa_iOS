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
                header
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("もしも便")
                .font(.system(size: 35, weight: .black, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
            Text("昨日と先月の時間から、一つの会話が届きます。")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = currentElapsed(at: context.date, story: story)
            MDWhatIfStoryCard(story: story, elapsed: elapsed,
                              hideTime: hideTime,
                              showAll: showAll || reduceMotion)
                .contentShape(Rectangle())
                .onTapGesture { skipToEnd() }
                .accessibilityIdentifier("whatif-interview")
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
                if showAll { showAll = false }
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
        let content = MDWhatIfStoryCard(story: story, elapsed: story.animationDuration,
                                        hideTime: hideTime, showAll: true)
            .frame(width: 430)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

private enum MDWhatIfPeriod: String, CaseIterable, Identifiable {
    case day, month

    var id: String { rawValue }
    var title: String { self == .day ? "昨日" : "先月" }
}

private struct MDWhatIfStory {
    let period: MDWhatIfPeriod
    let date: Date
    let mode: MDMode
    let duration: TimeInterval
    let amount: Double
    let activities: [String]
    let itemName: String?
    let itemSymbol: String?
    let itemPrice: Int?

    static let animationDuration: TimeInterval = 17.9
    var animationDuration: TimeInterval { Self.animationDuration }
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

    private var completed: Bool { showAll || elapsed >= MDWhatIfStory.animationDuration }
    private var visibleDialogue: [String] {
        if completed { return story.dialogue(hideTime: hideTime) }
        let count: Int
        switch elapsed {
        case ..<3.6: count = 1
        case ..<6.0: count = 2
        case ..<10.4: count = 3
        case ..<12.6: count = 4
        default: count = 4
        }
        return Array(story.dialogue(hideTime: hideTime).prefix(count))
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
            dialogueBubbles
            MDWhatIfActorCanvas(story: story, elapsed: elapsed)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .accessibilityHidden(true)
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

private struct MDWhatIfActorCanvas: View {
    let story: MDWhatIfStory
    let elapsed: TimeInterval

    var body: some View {
        Canvas { context, size in
            let baseWidth: CGFloat = 1_080
            let baseHeight: CGFloat = 710
            let scale = min(size.width / baseWidth, size.height / baseHeight)
            context.scaleBy(x: scale, y: scale)
            let speaking = (elapsed >= 0.6 && elapsed < 3.6) || (elapsed >= 6.0 && elapsed < 8.2)
            let pointing = story.mode == .spend && elapsed >= 7.7 && elapsed < 10.4
            let bob = speaking ? CGFloat(sin(elapsed * 10.0) * 3.0) : 0
            let oldFace = context.resolve(Image(speaking ? "whatif_part_old_talk" : "whatif_part_old_normal"))
            let oldBody = context.resolve(Image("whatif_part_old_body"))
            let oldArm = context.resolve(Image(pointing ? "whatif_part_old_point" : "whatif_part_old_arm"))
            let youngBody = context.resolve(Image("whatif_part_young_body"))
            let youngArm = context.resolve(Image("whatif_part_young_arm"))
            let youngFace = context.resolve(Image((story.mode == .spend && elapsed >= 13.7) ? "whatif_part_young_shock" : (elapsed >= 10.4 ? "whatif_part_young_talk" : "whatif_part_young_normal")))
            context.draw(oldBody, in: CGRect(x: 210, y: 409 + bob, width: 267, height: 521))
            context.draw(oldArm, in: CGRect(x: pointing ? 362 : 359, y: (pointing ? 324 : 324) + bob,
                                            width: pointing ? 136 : 158, height: pointing ? 70 : 104))
            context.draw(oldFace, in: CGRect(x: 233, y: 224 + bob, width: 184, height: 169))
            context.draw(youngBody, in: CGRect(x: 585, y: 468, width: 168, height: 373))
            context.draw(youngArm, in: CGRect(x: 680, y: 322, width: 79, height: 179))
            context.draw(youngFace, in: CGRect(x: 554, y: 139, width: 190, height: 180))
        }
        .drawingGroup()
        .accessibilityLabel("もしも便のインタビュー。二人の会話")
    }
}

private extension CGFloat {
    static func sin(_ value: TimeInterval) -> CGFloat {
        CGFloat(Foundation.sin(value))
    }
}
