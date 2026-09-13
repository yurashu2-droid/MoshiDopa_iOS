import SwiftUI

struct MDCounterView: View {
    @Binding var data: MDFixtureData
    let navigate: (MDRoute) -> Void
    let goBack: () -> Void
    let onOpenPiP: () -> Void
    @State private var delivery: MDCounterDelivery = .pip
    @State private var style: MDCounterStyle = .paper
    @State private var testMessage: String?
    @State private var previewMode: MDMode = .spend
    @State private var amountPreset = 1

    private var previewAmount: Double {
        switch amountPreset {
        case 0: return 0.82
        case 2: return max(1_234_567.89, data.activities.map(\.amount).max() ?? 0)
        default: return 842.35
        }
    }
    private var compactAmount: String {
        previewAmount >= 10_000 ? "¥\(Int(previewAmount / 10_000))万" : MoshiDopaBrand.yen(floor(previewAmount))
    }

    private var availableStyles: [MDCounterStyle] {
        delivery == .pip ? MDCounterStyle.allCases : [.paper, .ink]
    }

    var body: some View {
        ScreenShell(id: "counter", tab: .settings, tabAction: tabAction) {
            VStack(alignment: .leading, spacing: 17) {
                BackRow(title: "値札の設定", action: goBack)
                HStack { SampleModeBanner(); Spacer() }
                Text("値札の設定")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                Text("方式を選び、対応する見た目と面別プレビューを確認します。選択はこの起動中の見本に反映されます。")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                deliveryPicker
                previewControls
                Text("この方法のデザイン")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                Text("選択中：\(style.label)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.limeInk)
                ForEach(availableStyles) { candidate in
                    styleCard(candidate)
                }
                testArea
                Text("数値は表示見本です。見本を記録へ保存することはありません。PiPはOSのウインドウ枠内に表示されます。Live Activityは更新時点の金額を表示します。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onAppear {
                amountPreset = data.fixture == .large ? 2 : 1
                delivery = data.selectedCounterDelivery
                style = delivery == .pip ? data.pipStyle : data.liveStyle
            }
        }
    }

    private var previewControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("表示見本").font(.system(size: 16, weight: .bold))
            HStack(spacing: 8) {
                ForEach(MDMode.allCases) { mode in
                    Button { previewMode = mode } label: {
                        Text((previewMode == mode ? "✓ " : "") + mode.shortTitle)
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(TornPaperShape().fill(previewMode == mode ? MoshiDopaBrand.lime : MoshiDopaBrand.paper))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("preview-mode-\(mode.rawValue.lowercased())")
                }
            }
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Button { amountPreset = index } label: {
                        Text((amountPreset == index ? "✓ " : "") + ["少額", "通常", "大きい金額"][index])
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(TornPaperShape().fill(amountPreset == index ? MoshiDopaBrand.lime : MoshiDopaBrand.paper))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("preview-amount-\(index)")
                }
            }
        }
        .foregroundStyle(MoshiDopaBrand.ink)
    }

    private var deliveryPicker: some View {
        VStack(spacing: 10) {
            ForEach(MDCounterDelivery.allCases) { candidate in
                Button {
                    delivery = candidate
                    style = candidate == .pip ? data.pipStyle : data.liveStyle
                    data.selectedCounterDelivery = candidate
                    testMessage = nil
                } label: {
                    HStack(alignment: .top, spacing: 13) {
                        Image(systemName: delivery == candidate ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(candidate.description)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(MoshiDopaBrand.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .foregroundStyle(delivery == candidate ? MoshiDopaBrand.ink : MoshiDopaBrand.graphite)
                    .padding(16)
                    .background(TornPaperShape().fill(delivery == candidate ? MoshiDopaBrand.lime : MoshiDopaBrand.paper))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("delivery-\(candidate.rawValue)")
            }
        }
    }

    private func styleCard(_ candidate: MDCounterStyle) -> some View {
        Button {
            style = candidate
            if delivery == .pip { data.pipStyle = candidate } else { data.liveStyle = candidate }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: style == candidate ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                    Text(candidate.label)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(style == candidate ? MoshiDopaBrand.limeInk : MoshiDopaBrand.ink)
                Text(candidate.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                CounterPreview(style: candidate, delivery: delivery, amount: previewAmount, mode: previewMode)
            }
            .padding(17)
            .background(TornPaperShape().fill(MoshiDopaBrand.paper))
            .overlay(TornPaperShape().stroke(style == candidate ? MoshiDopaBrand.limeInk : Color.white.opacity(0.7), lineWidth: style == candidate ? 2 : 1))
            .shadow(color: MoshiDopaBrand.paperShadow, radius: 5, y: 3)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityIdentifier("counter-style-\(candidate.rawValue)")
    }

    private var testArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("表示を試す")
                .font(.system(size: 21, weight: .black, design: .rounded))
            Text(delivery == .pip
                 ? "本体で試用を開始し、別のアプリへ移動して表示を確認します。"
                 : "ロック画面などのOS表示を使うため、更新や表示面は端末の状態に左右されます。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
            if delivery == .liveActivity {
                liveActivityFaces
            }
            LimeButton(action: tryDisplay) {
                Label(delivery == .pip ? "PiPを表示して試す" : "面別の見本を確認", systemImage: "arrow.up.right.square")
            }
            .accessibilityIdentifier("open-pip")
            if let testMessage {
                Text(testMessage)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.limeInk)
                    .padding(.top, 2)
            }
        }
    }

    private func tryDisplay() {
        if delivery == .pip {
            onOpenPiP()
        } else {
            testMessage = "これはLive Activityの面別見本です。実機ではOSの更新時点・表示寿命・表示面を確認します。"
        }
    }

    private func tabAction(_ tab: MDTab) {
        switch tab {
        case .measurement: navigate(.home)
        case .history: navigate(.history)
        case .settings: break
        }
    }

    private var liveActivityFaces: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Activityの面別プレビュー")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text("ロック画面")
            HStack {
                Image(systemName: "yensign.circle.fill")
                VStack(alignment: .leading, spacing: 4) {
                    Text("もしドパ · \(previewMode.shortTitle)").font(.caption)
                    Text(MoshiDopaBrand.yen(previewAmount, decimals: 2)).lineLimit(1).minimumScaleFactor(0.4).font(.system(size: 28, weight: .black, design: .monospaced))
                    Text("9:41更新 · 時給 \(MoshiDopaBrand.yen(data.hourlyRate ?? 1_800))/h")
                        .font(.caption2).foregroundStyle(MoshiDopaBrand.mutedInk)
                }
                Spacer()
            }
            .padding(16)
            .foregroundStyle(style == .ink ? MoshiDopaBrand.paper : MoshiDopaBrand.ink)
            .background(style == .ink ? MoshiDopaBrand.ink : MoshiDopaBrand.paper,
                        in: RoundedRectangle(cornerRadius: 22))
            .accessibilityIdentifier("live-preview-lock")
            Text("Dynamic Island · コンパクト")
            HStack {
                Image(systemName: "yensign.circle.fill").foregroundStyle(islandAccent)
                Spacer(minLength: 40)
                Text(compactAmount).lineLimit(1).minimumScaleFactor(0.6).monospacedDigit()
            }
            .padding(.horizontal, 16).frame(height: 42)
            .foregroundStyle(.white).background(.black, in: Capsule())
            .accessibilityIdentifier("live-preview-compact")
            Text("Dynamic Island · 最小")
            Text(compactAmount).lineLimit(1).minimumScaleFactor(0.6).font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(islandAccent).frame(width: 46, height: 46)
                .background(.black, in: Circle())
                .accessibilityIdentifier("live-preview-minimal")
            Text("Dynamic Island · 展開")
            VStack(alignment: .leading, spacing: 12) {
                Label("もしドパ · \(previewMode.shortTitle)", systemImage: "yensign.circle.fill").foregroundStyle(islandAccent)
                Text(MoshiDopaBrand.yen(previewAmount, decimals: 2)).lineLimit(1).minimumScaleFactor(0.4).font(.system(size: 30, weight: .black, design: .monospaced))
                Text("9:41更新 · 時給 \(MoshiDopaBrand.yen(data.hourlyRate ?? 1_800))/h")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .foregroundStyle(.white).background(.black, in: RoundedRectangle(cornerRadius: 32))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("live-preview-expanded")
            Text("すべて表示見本です。実寸・更新頻度は未検証です。最小面では大きな金額を万円単位に省略し、詳しい金額は展開面で確認する設計です。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
    }

    private var islandAccent: Color { style == .ink ? .white : MoshiDopaBrand.lime }
}

struct CounterPreview: View {
    let style: MDCounterStyle
    let delivery: MDCounterDelivery
    var amount: Double = 842.35
    var mode: MDMode = .spend
    private var activityTitle: String { mode == .invest ? "自己投資" : "アプリ名" }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(MoshiDopaBrand.bluePaper.opacity(0.68))
                .frame(height: delivery == .pip ? 132 : 108)
            previewSurface
            if delivery == .pip {
                VStack {
                    HStack {
                        Spacer()
                        Label("PiP", systemImage: "rectangle.inset.filled")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(MoshiDopaBrand.mutedInk)
                            .padding(7)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    Spacer()
                    HStack(spacing: 14) {
                        Image(systemName: "backward.fill")
                        Image(systemName: "pause.fill")
                        Image(systemName: "forward.fill")
                        Image(systemName: "xmark")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .padding(.vertical, 5)
                }
                .padding(8)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(style.label)の\(delivery.compactTitle)プレビュー、\(activityTitle)、\(MoshiDopaBrand.yen(amount, decimals: 2))")
    }

    @ViewBuilder
    private var previewSurface: some View {
        switch style {
        case .paper:
            PaperCard(padding: 11) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(activityTitle, systemImage: mode == .invest ? "chart.bar.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text(MoshiDopaBrand.yen(amount, decimals: 2)).lineLimit(1).minimumScaleFactor(0.4)
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                }
                .frame(width: delivery == .pip ? 180 : 155, alignment: .leading)
            }
        case .ink:
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Divider().frame(height: 30).overlay(Color.white.opacity(0.2))
                VStack(alignment: .leading, spacing: 1) {
                    Text(activityTitle).font(.system(size: 11, weight: .bold, design: .rounded))
                    Text(MoshiDopaBrand.yen(amount, decimals: 2)).lineLimit(1).minimumScaleFactor(0.4).font(.system(size: 24, weight: .black, design: .monospaced))
                }
            }
            .foregroundStyle(MoshiDopaBrand.paper)
            .padding(.horizontal, 17)
            .frame(height: 66)
            .background(RoundedRectangle(cornerRadius: 14).fill(MoshiDopaBrand.ink))
        case .frost:
            VStack(alignment: .leading, spacing: 1) {
                Label(activityTitle, systemImage: mode == .invest ? "chart.bar.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text(MoshiDopaBrand.yen(amount, decimals: 2)).lineLimit(1).minimumScaleFactor(0.4)
                    .font(.system(size: 27, weight: .black, design: .monospaced))
            }
            .foregroundStyle(MoshiDopaBrand.ink)
            .padding(.horizontal, 17)
            .frame(width: 170, height: 70, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        case .sticker:
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 1) {
                    Label(activityTitle, systemImage: mode == .invest ? "chart.bar.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Text(MoshiDopaBrand.yen(amount, decimals: 2)).lineLimit(1).minimumScaleFactor(0.4)
                        .font(.system(size: 27, weight: .black, design: .monospaced))
                }
                .foregroundStyle(MoshiDopaBrand.ink)
                .padding(.horizontal, 17)
                .frame(width: 178, height: 72, alignment: .leading)
                .background(MoshiDopaBrand.paper, in: RoundedRectangle(cornerRadius: 28))
                Mascot(asset: "home_mascot_coin", size: 47)
                    .offset(x: 4, y: -19)
            }
        }
    }
}
