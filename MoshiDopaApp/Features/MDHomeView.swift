import SwiftUI

struct MDHomeView: View {
    @Binding var data: MDFixtureData
    let navigate: (MDRoute) -> Void
    let start: (MDMode) -> Void

    var body: some View {
        ScreenShell(id: "home", tab: .measurement, tabAction: tabAction) {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                HStack {
                    SampleModeBanner()
                    Spacer()
                }
                hero
                summary
                startButtons
                quickLinks
                recent
                footerLinks
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            Button { navigate(.whatif) } label: {
                Image(systemName: "bell")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .frame(width: 48, height: 48)
            }
            .accessibilityIdentifier("open-whatif")
            .accessibilityLabel("もしも便")
            Spacer()
            Wordmark()
        }
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            PaperCard(padding: 24) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("もし働いたら…")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.ink)
                    Text(MoshiDopaBrand.displayYen(data.spendAmount))
                        .font(.system(size: 61, weight: .black, design: .monospaced))
                        .foregroundStyle(MoshiDopaBrand.ink)
                        .minimumScaleFactor(0.58)
                        .lineLimit(1)
                        .overlay(alignment: .bottomLeading) {
                            Rectangle()
                                .fill(MoshiDopaBrand.lime)
                                .frame(width: 196, height: 7)
                                .rotationEffect(.degrees(-4))
                                .offset(x: 8, y: 6)
                        }
                        .padding(.vertical, 5)
                    Text("その時間、働いていたらこれくらい。")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 82)
            }
            VStack(alignment: .trailing, spacing: 4) {
                Text("じかんって\nこんなから、\nあるんだ。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .multilineTextAlignment(.trailing)
                    .padding(.top, 25)
                Mascot(asset: "home_mascot_coin", size: 114)
                    .offset(x: -4, y: 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("もし働いたら。今日の見込み額 \(MoshiDopaBrand.yen(data.spendAmount))")
    }

    private var summary: some View {
        PaperCard(padding: 15) {
            HStack(spacing: 0) {
                summaryValue(title: "想定時給", value: data.hourlyRate.map { MoshiDopaBrand.yen($0) + " / h" } ?? "時給未設定")
                Divider().frame(height: 42).overlay(MoshiDopaBrand.graphite.opacity(0.22))
                summaryValue(title: "今日の利用時間", value: MoshiDopaBrand.duration(data.todayActivities.filter { $0.mode == .spend }.reduce(0) { $0 + $1.duration }))
            }
        }
    }

    private func summaryValue(title: String, value: String) -> some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .monospaced))
                .foregroundStyle(MoshiDopaBrand.ink)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var startButtons: some View {
        HStack(spacing: 12) {
            LimeButton(action: { start(.spend) }) {
                VStack(spacing: 2) {
                    Label("START SPEND", systemImage: "play.fill")
                    Text("使う時間を記録")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
            }
            .accessibilityIdentifier("start-spend")
            PaperButton(action: { start(.invest) }) {
                VStack(spacing: 2) {
                    Label("START INVEST", systemImage: "chart.bar.fill")
                    Text("自分に投資する時間")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
            }
            .accessibilityIdentifier("start-invest")
        }
    }

    private var quickLinks: some View {
        VStack(spacing: 11) {
            Button { navigate(.settings) } label: {
                Label("計測方法・対象アプリを設定", systemImage: "gearshape")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("open-settings")
            HStack(spacing: 10) {
                PaperButton(action: { navigate(.counter) }) { Label("値札を試す", systemImage: "rectangle.on.rectangle") }
                    .accessibilityIdentifier("open-counter")
                PaperButton(action: { navigate(.onboarding) }) { Label("使い方を見る", systemImage: "book") }
                    .accessibilityIdentifier("open-onboarding")
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近の明細")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                Spacer()
                Button("すべて見る  ›") { navigate(.history) }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .accessibilityIdentifier("open-history")
            }
            if data.activities.isEmpty {
                PaperCard(padding: 21) {
                    Text("まだ明細はありません。\n計測した時間が、ここに紙の明細として届きます。")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                PaperCard(padding: 14) {
                    VStack(spacing: 0) {
                        ForEach(Array(data.activities.prefix(3))) { activity in
                            MDActivityRow(activity: activity, compact: true)
                            if activity.id != data.activities.prefix(3).last?.id {
                                Divider().overlay(MoshiDopaBrand.graphite.opacity(0.16))
                            }
                        }
                    }
                }
            }
        }
    }

    private var footerLinks: some View {
        HStack(spacing: 10) {
            PaperButton(action: { navigate(.receipt) }) { Label("明細を共有", systemImage: "square.and.arrow.up") }
                .accessibilityIdentifier("open-receipt")
            PaperButton(action: { navigate(.statement) }) { Label("通帳を作る", systemImage: "doc.text") }
                .accessibilityIdentifier("open-statement")
        }
    }

    private func tabAction(_ tab: MDTab) {
        switch tab {
        case .measurement: navigate(.measurement)
        case .history: navigate(.history)
        case .settings: navigate(.settings)
        }
    }
}

struct MDActivityRow: View {
    let activity: MDActivity
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.mode == .spend ? "play.circle.fill" : "chart.bar.fill")
                .font(.system(size: compact ? 21 : 25, weight: .bold))
                .foregroundStyle(activity.mode == .spend ? MoshiDopaBrand.limeInk : MoshiDopaBrand.ink)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.activityName)
                    .font(.system(size: compact ? 15 : 17, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .lineLimit(1)
                Text("\(activity.mode.shortTitle) · \(MoshiDopaBrand.duration(activity.duration))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
            }
            Spacer(minLength: 8)
            Text(MoshiDopaBrand.displayYen(activity.amount))
                .font(.system(size: compact ? 16 : 19, weight: .bold, design: .monospaced))
                .foregroundStyle(MoshiDopaBrand.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(.vertical, compact ? 11 : 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activity.activityName)、\(activity.mode.shortTitle)、\(MoshiDopaBrand.displayYen(activity.amount))")
    }
}
