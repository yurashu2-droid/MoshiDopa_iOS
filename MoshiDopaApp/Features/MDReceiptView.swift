import SwiftUI
import UIKit

/// A read-only sample session receipt. The view deliberately receives a value
/// copy of the fixture so browsing and sharing never writes to the repository.
struct MDReceiptView: View {
    let data: MDFixtureData
    let goBack: () -> Void
    let initialID: UUID?

    @State private var period: MDPeriod = .day
    @State private var mode: MDMode = .spend
    @State private var selectedIndex = 0
    @State private var hideTime = true

    init(data: MDFixtureData, goBack: @escaping () -> Void, initialID: UUID? = nil) {
        self.data = data
        self.goBack = goBack
        self.initialID = initialID
    }

    private var filtered: [MDActivity] {
        data.activities(for: period, mode: mode)
    }

    private var selectedActivity: MDActivity? {
        guard !filtered.isEmpty else { return nil }
        return filtered.indices.contains(selectedIndex) ? filtered[selectedIndex] : filtered[0]
    }

    var body: some View {
        ScreenShell(id: "receipt") {
            VStack(alignment: .leading, spacing: 17) {
                BackRow(title: "明細", action: goBack)
                HStack { SampleModeBanner(); Spacer() }
                header
                filters
                if let activity = selectedActivity {
                    recordPicker
                    receiptPreview(activity)
                    receiptActions(activity)
                } else {
                    emptyState
                }
            }
        }
        .onAppear { selectInitialActivityIfNeeded() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("セッションの明細")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
            Text("保存済みの時間を、紙の明細として確認・共有できます。")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("表示する記録")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.graphite)
            HStack(spacing: 7) {
                ForEach(MDPeriod.allCases) { value in
                    Button { period = value; selectedIndex = 0 } label: {
                        Text(value.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(value == period ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .background {
                                if value == period { TornPaperShape().fill(MoshiDopaBrand.lime) }
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("receipt-period-\(value.rawValue)")
                }
            }
            .padding(4)
            .background(TornPaperShape().fill(MoshiDopaBrand.paper))

            HStack(spacing: 7) {
                ForEach(MDMode.allCases) { value in
                    Button { mode = value; selectedIndex = 0 } label: {
                        Text(value.shortTitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(value == mode ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                            .frame(maxWidth: .infinity, minHeight: 45)
                            .background {
                                if value == mode { TornPaperShape().fill(MoshiDopaBrand.lime) }
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("receipt-mode-\(value.rawValue.lowercased())")
                }
            }
            .padding(4)
            .background(TornPaperShape().fill(MoshiDopaBrand.paper))
        }
    }

    private var recordPicker: some View {
        Picker("記録", selection: $selectedIndex) {
            ForEach(filtered.indices, id: \.self) { index in
                Text(filtered[index].activityName).tag(index)
            }
        }
        .pickerStyle(.menu)
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(MoshiDopaBrand.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(TornPaperShape().fill(MoshiDopaBrand.paper))
        .accessibilityIdentifier("receipt-record-picker")
    }

    private func receiptPreview(_ activity: MDActivity) -> some View {
        MDReceiptPaper(activity: activity, hideTime: hideTime)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(receiptAccessibilityLabel(activity))
            .accessibilityIdentifier("receipt-preview")
    }

    private func receiptActions(_ activity: MDActivity) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            TogglePill(title: "共有画像では時間を隠す", isOn: hideTime) {
                hideTime.toggle()
            }
            .accessibilityIdentifier("receipt-hide-time")
            Text(hideTime ? "時間と単価は共有画像に表示しません。" : "時間と保存時の単価を共有画像に表示します。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            if let image = shareImage(for: activity) {
                ShareLink(item: image,
                          preview: SharePreview("セッションの明細", image: image)) {
                    Label("明細を画像で共有", systemImage: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.ink)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(TornPaperShape().fill(MoshiDopaBrand.lime))
                        .overlay(TornPaperShape().stroke(Color.white.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("share-receipt")
            }
        }
    }

    private var emptyState: some View {
        PaperCard(padding: 21) {
            VStack(alignment: .leading, spacing: 10) {
                Label("この期間の記録はありません", systemImage: "doc.text.magnifyingglass")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.ink)
                Text("記録がないことは、使った時間がゼロという意味ではありません。期間またはモードを変えると、保存済みのサンプルを確認できます。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("receipt-empty")
    }

    private func shareImage(for activity: MDActivity) -> Image? {
        let content = MDReceiptPaper(activity: activity, hideTime: hideTime)
            .frame(width: 430)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    private func selectInitialActivityIfNeeded() {
        guard let initialID,
              let activity = data.activities.first(where: { $0.id == initialID }) else { return }
        mode = activity.mode
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let day = calendar.component(.day, from: activity.startedAt)
        period = day == 13 ? .day : (day >= 7 && day <= 13 ? .week : .month)
        selectedIndex = filtered.firstIndex(where: { $0.id == initialID }) ?? 0
    }

    private func receiptAccessibilityLabel(_ activity: MDActivity) -> String {
        let amount = MoshiDopaBrand.yen(activity.amount, decimals: activity.amount < 1_000 ? 2 : 0)
        let time = hideTime ? "時間と単価は非表示" : MoshiDopaBrand.duration(activity.duration)
        return "\(activity.activityName)。\(activity.mode.shortTitle)。\(amount)。\(time)"
    }
}

private struct MDReceiptPaper: View {
    let activity: MDActivity
    let hideTime: Bool

    private var amount: String {
        MoshiDopaBrand.yen(activity.amount, decimals: activity.amount < 1_000 ? 2 : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(activity.mode == .invest ? "今回の自己投資明細" : "今回の利用明細")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(MoshiDopaBrand.mutedInk)
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.25))
            Text(activity.activityName)
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(activity.mode == .invest ? "自分の未来への投資" : "働いていたら")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .frame(maxWidth: .infinity, alignment: .center)
            amountView
            if hideTime {
                Text("時間と単価は非表示")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack {
                    Text("利用時間")
                    Spacer()
                    Text(MoshiDopaBrand.duration(activity.duration))
                }
                HStack {
                    Text("保存時の単価")
                    Spacer()
                    Text("\(MoshiDopaBrand.yen(activity.hourlyRate)) / h")
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
            }
            if activity.mode == .invest {
                if !activity.project.isEmpty {
                    Text("PROJECT / \(activity.project)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                }
                if !activity.note.isEmpty {
                    Text(activity.note)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("自分の未来に、投資しました。")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.ink)
            } else {
                Text("今回は支給されませんでした")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.red)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoshiDopaBrand.red, lineWidth: 2))
                    .rotationEffect(.degrees(-2))
            }
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.22))
            Text(issuedLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
            HStack(alignment: .bottom) {
                Text("もしドパ")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                Spacer()
                Text("もしもドパガキが働いたら？")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
            }
            Text(activity.mode == .invest
                 ? "設定した単価と計測時間に基づく時間投資の目安です。売上や評価額ではありません。"
                 : "設定した時給と計測時間に基づく仮定の金額です。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background {
            ZStack {
                TornPaperShape().fill(MoshiDopaBrand.paper)
                Image("session_receipt_paper_texture")
                    .resizable(resizingMode: .tile)
                    .opacity(0.06)
                    .blendMode(.multiply)
                    .clipShape(TornPaperShape())
            }
        }
        .overlay(TornPaperShape().stroke(Color.white.opacity(0.7), lineWidth: 1))
        .shadow(color: MoshiDopaBrand.paperShadow, radius: 7, y: 4)
    }

    private var amountView: some View {
        VStack(spacing: 4) {
            Text(amount)
                .font(.system(size: 47, weight: .black, design: .monospaced))
                .foregroundStyle(MoshiDopaBrand.ink)
                .minimumScaleFactor(0.52)
                .lineLimit(1)
                .overlay(alignment: .bottom) {
                    if activity.mode == .spend {
                        Rectangle()
                            .fill(MoshiDopaBrand.red)
                            .frame(height: 3)
                            .rotationEffect(.degrees(-1))
                    }
                }
            Text(activity.mode == .invest ? "注いだ時間の換算額" : "もし働いていたら得られた仮定額")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
        }
        .frame(maxWidth: .infinity)
    }

    private var issuedLabel: String {
        let date = activity.startedAt.addingTimeInterval(activity.duration)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy年M月d日 HH:mm 発行"
        return formatter.string(from: date)
    }
}
