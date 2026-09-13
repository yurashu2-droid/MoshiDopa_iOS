import Foundation
import SwiftUI

struct MDHistoryView: View {
    @Binding var data: MDFixtureData
    @Binding var period: MDPeriod
    @Binding var mode: MDMode
    @Binding var anchorDay: Int
    let navigate: (MDRoute) -> Void
    let openReceipt: (UUID?) -> Void
    let goBack: () -> Void
    @State private var showDetails = false

    private var filtered: [MDActivity] { data.activities(for: period, mode: mode, anchorDay: anchorDay) }
    private var amount: Double { filtered.reduce(0) { $0 + $1.amount } }
    private var duration: TimeInterval { filtered.reduce(0) { $0 + $1.duration } }

    var body: some View {
        ScreenShell(id: "history", tab: .history, tabAction: tabAction) {
            VStack(alignment: .leading, spacing: 17) {
                BackRow(title: "履歴", action: goBack)
                HStack { SampleModeBanner(); Spacer() }
                HeroPaper(title: "履歴", subtitle: "つかった時間を、ふりかえろう。", mascotAsset: "paper_mascot_history", titleSize: 36)
                periodPicker
                modePicker
                summaryCard
                Button { showDetails.toggle() } label: {
                    HStack {
                        Text("詳しい集計を見る")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        Spacer()
                    }
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .frame(minHeight: 42)
                }
                .accessibilityIdentifier("toggle-summary")
                if showDetails { detailSummary }
                recordsSection
                HStack(spacing: 10) {
                    PaperButton(action: { openReceipt(nil) }) { Label("明細を見る", systemImage: "doc.text") }
                        .accessibilityIdentifier("open-receipt")
                    PaperButton(action: { navigate(.statement) }) { Label("通帳を作る", systemImage: "book.closed") }
                        .accessibilityIdentifier("open-statement")
                }
            }
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(MDPeriod.allCases) { value in
                Button { period = value } label: {
                    Text(value.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(value == period ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background {
                            if value == period { TornPaperShape().fill(MoshiDopaBrand.lime) }
                        }
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("period-\(value.rawValue)")
            }
        }
        .padding(4)
        .background(TornPaperShape().fill(MoshiDopaBrand.paper))
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(MDMode.allCases) { value in
                Button { mode = value } label: {
                    Text(value.shortTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(value == mode ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background {
                            if value == mode { TornPaperShape().fill(MoshiDopaBrand.lime) }
                        }
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("history-mode-\(value.rawValue.lowercased())")
            }
        }
        .padding(4)
        .background(TornPaperShape().fill(MoshiDopaBrand.paper))
    }

    private var summaryCard: some View {
        PaperCard(padding: 22) {
            VStack(alignment: .leading, spacing: 13) {
                Text("この期間、もし働いたら…")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Text(MoshiDopaBrand.yen(amount, decimals: amount < 1000 ? 2 : 0))
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .overlay(alignment: .bottomLeading) {
                        Rectangle().fill(MoshiDopaBrand.lime).frame(width: 190, height: 6)
                            .rotationEffect(.degrees(-4)).offset(x: 6, y: 4)
                    }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Menu {
                            ForEach([13, 12, 11], id: \.self) { day in
                                Button("2026年9月\(day)日") { anchorDay = day }
                            }
                        } label: {
                            Label("2026年9月\(anchorDay)日", systemImage: "calendar")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(MoshiDopaBrand.ink)
                        }
                        .accessibilityIdentifier("history-date")
                        Text("合計時間")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(MoshiDopaBrand.mutedInk)
                    }
                    Spacer()
                    Text(MoshiDopaBrand.duration(duration))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                }
                chart
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var chart: some View {
        let buckets = chartBuckets
        let maxValue = max(1, buckets.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 9) {
            ForEach(Array(buckets.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(value > 0 ? MoshiDopaBrand.lime : MoshiDopaBrand.graphite.opacity(0.18))
                        .frame(height: max(5, CGFloat(value / maxValue) * 75))
                    Text(chartLabels[index])
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
            }
        }
        .frame(height: 104, alignment: .bottom)
        .padding(.top, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("時間帯グラフ")
    }

    private var chartBuckets: [Double] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        switch period {
        case .day:
            let hours = [0, 4, 8, 12, 16, 20]
            return hours.map { hour in
                filtered.filter { calendar.component(.hour, from: $0.startedAt) >= hour && calendar.component(.hour, from: $0.startedAt) < hour + 4 }
                    .reduce(0) { $0 + $1.amount }
            }
        case .week:
            let days = Array(max(1, anchorDay - 6)...anchorDay)
            return days.map { day in
                filtered.filter { calendar.component(.day, from: $0.startedAt) == day }
                    .reduce(0) { $0 + $1.amount }
            }
        case .month:
            let starts = [1, 5, 10, 15, 20, 25, 30]
            return starts.enumerated().map { index, start in
                let end = index + 1 < starts.count ? starts[index + 1] : 32
                return filtered.filter {
                    let day = calendar.component(.day, from: $0.startedAt)
                    return day >= start && day < end
                }.reduce(0) { $0 + $1.amount }
            }
        }
    }

    private var chartLabels: [String] {
        switch period {
        case .day: return ["0", "4", "8", "12", "16", "20"]
        case .week: return Array(max(1, anchorDay - 6)...anchorDay).map(String.init)
        case .month: return ["1", "5", "10", "15", "20", "25", "30"]
        }
    }

    private var detailSummary: some View {
        PaperCard(padding: 17) {
            VStack(alignment: .leading, spacing: 9) {
                Text("集計メモ")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                LabeledContent("記録数", value: "\(filtered.count)件")
                LabeledContent("平均単価", value: filtered.isEmpty ? "—" : MoshiDopaBrand.yen(filtered.reduce(0) { $0 + $1.hourlyRate } / Double(filtered.count)) + " / h")
                LabeledContent("集計の基準", value: "端末内の保存済みサンプル")
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(MoshiDopaBrand.mutedInk)
        }
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("この期間の記録")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                Spacer()
                Text("\(filtered.count)件")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
            }
            if filtered.isEmpty {
                PaperCard(padding: 19) {
                    Text("この期間の記録はありません。\n記録がないことは、使った時間がゼロという意味ではありません。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                PaperCard(padding: 13) {
                    VStack(spacing: 0) {
                        ForEach(filtered) { activity in
                            Button { openReceipt(activity.id) } label: {
                                MDActivityRow(activity: activity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("history-record-\(activity.id.uuidString)")
                            if activity.id != filtered.last?.id {
                                Divider().overlay(MoshiDopaBrand.graphite.opacity(0.16))
                            }
                        }
                    }
                }
            }
        }
    }

    private func tabAction(_ tab: MDTab) {
        switch tab {
        case .measurement: navigate(.home)
        case .history: break
        case .settings: navigate(.settings)
        }
    }
}
