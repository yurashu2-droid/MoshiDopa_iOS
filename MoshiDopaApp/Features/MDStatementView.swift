import SwiftUI
import UIKit

/// Compose a day or month statement from the in-memory fixture. A statement is
/// a derived preview; selecting or sharing one never mutates saved activities.
struct MDStatementView: View {
    let data: MDFixtureData
    let goBack: () -> Void

    @State private var period: MDPeriod = .day
    @State private var mode: MDMode = .spend
    @State private var selectedProject = ""
    @State private var hideTime = true

    private var filtered: [MDActivity] {
        data.activities(for: period, mode: mode)
            .filter { selectedProject.isEmpty || $0.project == selectedProject }
    }

    private var lines: [MDStatementLine] {
        let grouped = Dictionary(grouping: filtered) { activity in
            if mode == .invest, !activity.project.isEmpty { return activity.project }
            return mode == .spend ? activity.appName : activity.activityName
        }
        return grouped.keys.sorted().compactMap { key in
            guard let values = grouped[key], !values.isEmpty else { return nil }
            return MDStatementLine(id: key, label: key, activities: values)
        }
    }

    private var amount: Double { filtered.reduce(0) { $0 + $1.amount } }
    private var duration: TimeInterval { filtered.reduce(0) { $0 + $1.duration } }
    private var projects: [String] {
        Array(Set(data.activities.filter { $0.mode == .invest && !$0.project.isEmpty }.map(\.project)))
            .sorted()
    }

    var body: some View {
        ScreenShell(id: "statement") {
            VStack(alignment: .leading, spacing: 17) {
                BackRow(title: "明細を作る", action: goBack)
                HStack { SampleModeBanner(); Spacer() }
                intro
                selectors
                if mode == .invest, !projects.isEmpty {
                    projectSelector
                }
                if lines.isEmpty {
                    emptyState
                } else {
                    statementPreview
                    statementActions
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("明細を作る")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
            Text("期間を選んで、通帳形式の明細を共有できます。")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectors: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("集計の条件")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.graphite)
            HStack(spacing: 8) {
                ForEach([MDPeriod.day, MDPeriod.month]) { value in
                    Button { period = value } label: {
                        Text(value == .day ? "日給明細" : "月給明細")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(value == period ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background {
                                if value == period { TornPaperShape().fill(MoshiDopaBrand.lime) }
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("statement-period-\(value.rawValue)")
                }
            }
            .padding(4)
            .background(TornPaperShape().fill(MoshiDopaBrand.paper))
            HStack(spacing: 8) {
                ForEach(MDMode.allCases) { value in
                    Button {
                        mode = value
                        if value == .spend { selectedProject = "" }
                    } label: {
                        Text(value.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(value == mode ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background {
                                if value == mode { TornPaperShape().fill(MoshiDopaBrand.lime) }
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("statement-mode-\(value.rawValue.lowercased())")
                }
            }
            .padding(4)
            .background(TornPaperShape().fill(MoshiDopaBrand.paper))
        }
    }

    private var projectSelector: some View {
        Menu {
            Button("すべて") { selectedProject = "" }
            ForEach(projects, id: \.self) { project in
                Button(project) { selectedProject = project }
            }
        } label: {
            HStack {
                Text("プロジェクト：\(selectedProject.isEmpty ? "すべて" : selectedProject)")
                Spacer()
                Image(systemName: "chevron.down")
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(MoshiDopaBrand.ink)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(TornPaperShape().fill(MoshiDopaBrand.paper))
        }
        .accessibilityIdentifier("statement-project")
    }

    private var statementPreview: some View {
        MDStatementPaper(period: period, mode: mode, lines: lines,
                         amount: amount, duration: duration, hideTime: hideTime)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(statementAccessibilityLabel)
            .accessibilityIdentifier("statement-preview")
    }

    private var statementActions: some View {
        VStack(alignment: .leading, spacing: 11) {
            TogglePill(title: "共有画像では時間を隠す", isOn: hideTime) {
                hideTime.toggle()
            }
            .accessibilityIdentifier("statement-hide-time")
            Text(hideTime
                 ? "時間と単価を隠した、金額中心の明細を共有します。"
                 : "合計時間と保存時の単価も明細に含めます。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            if let image = shareImage {
                ShareLink(item: image,
                          preview: SharePreview(statementTitle, image: image)) {
                    Label("通帳明細を画像で共有", systemImage: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.ink)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(TornPaperShape().fill(MoshiDopaBrand.lime))
                        .overlay(TornPaperShape().stroke(Color.white.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("share-statement")
            }
        }
    }

    private var emptyState: some View {
        PaperCard(padding: 21) {
            VStack(alignment: .leading, spacing: 10) {
                Text("この期間の記録はありません。")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.ink)
                Text("保存済みの記録だけを集計します。記録がないことは、使った時間がゼロという意味ではありません。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("statement-empty")
    }

    private var statementTitle: String {
        switch (mode, period) {
        case (.spend, .day): return "もしも日給明細"
        case (.spend, .month): return "もしも月給明細"
        case (.invest, .day): return "今日の自己投資明細"
        case (.invest, .month): return "今月の自己投資明細"
        case (.spend, .week): return "もしも給与明細"
        case (.invest, .week): return "自己投資明細"
        }
    }

    private var statementAccessibilityLabel: String {
        "\(statementTitle)。\(statementRange)。\(lines.count)項目。合計 \(MoshiDopaBrand.yen(amount))。\(hideTime ? "時間は非表示" : "合計時間 \(MoshiDopaBrand.duration(duration))")"
    }

    private var statementRange: String {
        switch period {
        case .day: return "2026年9月13日（途中集計）"
        case .month: return "2026年9月1日〜13日（途中集計）"
        case .week: return "2026年9月7日〜13日（途中集計）"
        }
    }

    private var shareImage: Image? {
        let content = MDStatementPaper(period: period, mode: mode, lines: lines,
                                       amount: amount, duration: duration, hideTime: hideTime)
            .frame(width: 430)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}

private struct MDStatementLine: Identifiable {
    let id: String
    let label: String
    let activities: [MDActivity]

    var amount: Double { activities.reduce(0) { $0 + $1.amount } }
    var duration: TimeInterval { activities.reduce(0) { $0 + $1.duration } }
    var notes: [String] { activities.map(\.note).filter { !$0.isEmpty } }
    var project: String { activities.map(\.project).first(where: { !$0.isEmpty }) ?? "" }
}

private struct MDStatementPaper: View {
    let period: MDPeriod
    let mode: MDMode
    let lines: [MDStatementLine]
    let amount: Double
    let duration: TimeInterval
    let hideTime: Bool

    private var title: String {
        switch (mode, period) {
        case (.spend, .day): return "もしも日給明細"
        case (.spend, .month): return "もしも月給明細"
        case (.invest, .day): return "今日の自己投資明細"
        case (.invest, .month): return "今月の自己投資明細"
        case (.spend, .week): return "もしも給与明細"
        case (.invest, .week): return "自己投資明細"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text("もしドパ")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                Spacer()
                Text("TIME COST / 明細")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
            }
            Text(title)
                .font(.system(size: 27, weight: .black, design: .rounded))
            Text(mode == .invest ? "自分の未来へ注いだ時間" : "働いていたら得られた金額")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
            Text(rangeLabel)
                .font(.system(size: 15, weight: .medium, design: .rounded))
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.36))
            tableHeader
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.24))
            lineRows
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.36))
            totalRow
            if !hideTime {
                HStack {
                    Text("合計時間")
                    Spacer()
                    Text(MoshiDopaBrand.duration(duration))
                }
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
            } else {
                Text("時間と単価は非表示")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
            }
            investDetails
            Spacer(minLength: 34)
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.2))
            Text(mode == .invest
                 ? "設定した単価と計測時間に基づく時間投資の目安です。売上や評価額ではありません。"
                 : "設定した時給と計測時間に基づく仮定の金額です。実際の支給額ではありません。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                TornPaperShape().fill(MoshiDopaBrand.paper)
                Image("session_receipt_paper_texture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.055)
                    .blendMode(.multiply)
                    .clipShape(TornPaperShape())
            }
        }
        .overlay(TornPaperShape().stroke(Color.white.opacity(0.7), lineWidth: 1))
        .shadow(color: MoshiDopaBrand.paperShadow, radius: 7, y: 4)
    }

    private var tableHeader: some View {
        HStack {
            Text(period == .month ? "月" : "日")
                .frame(width: 55, alignment: .leading)
            Text("摘要 / アプリ")
            Spacer()
            Text("金額")
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(MoshiDopaBrand.mutedInk)
    }

    private var lineRows: some View {
        VStack(spacing: 0) {
            ForEach(lines) { line in
                HStack(alignment: .top, spacing: 8) {
                    Text(period == .month ? "9月集計" : "9/13")
                        .frame(width: 55, alignment: .leading)
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.label)
                            .lineLimit(2)
                        if !hideTime {
                            Text(MoshiDopaBrand.duration(line.duration))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(MoshiDopaBrand.mutedInk)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(amountText(line.amount))
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
                .padding(.vertical, 9)
                if line.id != lines.last?.id {
                    Divider().overlay(MoshiDopaBrand.graphite.opacity(0.14))
                }
            }
        }
    }

    private var totalRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("合計")
                .font(.system(size: 18, weight: .black, design: .rounded))
            Spacer()
            Text(amountText(amount))
                .font(.system(size: 27, weight: .black, design: .monospaced))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .overlay(alignment: .center) {
                    if mode == .spend {
                        Rectangle()
                            .fill(MoshiDopaBrand.red)
                            .frame(height: 3)
                            .rotationEffect(.degrees(-1))
                    }
                }
        }
    }

    @ViewBuilder
    private var investDetails: some View {
        if mode == .invest {
            VStack(alignment: .leading, spacing: 6) {
                if let project = lines.compactMap(\.project).first, !project.isEmpty {
                    Text("プロジェクト：\(project)")
                }
                let notes = lines.flatMap(\.notes).uniqued()
                if !notes.isEmpty {
                    Text("メモ：\(notes.joined(separator: " / "))")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(MoshiDopaBrand.ink)
        }
    }

    private var rangeLabel: String {
        switch period {
        case .day: return "2026年9月13日（途中集計）"
        case .month: return "2026年9月1日〜13日（途中集計）"
        case .week: return "2026年9月7日〜13日（途中集計）"
        }
    }

    private func amountText(_ value: Double) -> String {
        let prefix = mode == .spend ? "− " : ""
        return prefix + MoshiDopaBrand.yen(value, decimals: value < 1_000 ? 2 : 0)
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var result: [String] = []
        for value in self where !result.contains(value) { result.append(value) }
        return result
    }
}
