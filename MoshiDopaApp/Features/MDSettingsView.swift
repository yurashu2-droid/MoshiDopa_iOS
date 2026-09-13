import SwiftUI

struct MDSettingsView: View {
    @Binding var data: MDFixtureData
    let navigate: (MDRoute) -> Void
    let goBack: () -> Void
    let onOpenPiP: () -> Void
    @State private var detail: SettingsDetail?
    @State private var showDisplaySheet = false
    @State private var showAboutSheet = false

    private enum SettingsDetail: String, Identifiable {
        case wage, apps, invest
        var id: String { rawValue }
    }

    var body: some View {
        ScreenShell(id: "settings", tab: .settings, tabAction: tabAction) {
            VStack(alignment: .leading, spacing: 17) {
                Text("サンプル表示・記録されません")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                HeroPaper(title: "設定", subtitle: "あなたらしい使い方に。", mascotAsset: "paper_mascot_settings", titleSize: 36)
                settingsList
                supportLinks
            }
        }
        .sheet(item: $detail) { value in
            switch value {
            case .wage: MDWageEditorSheet(data: $data)
            case .apps: MDAppsSheet()
            case .invest: MDInvestSheet(data: $data)
            }
        }
        .sheet(isPresented: $showDisplaySheet) {
            MDDisplaySheet(onOpenPiP: onOpenPiP)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAboutSheet) {
            MDAboutSheet()
                .presentationDetents([.medium])
        }
    }

    private var settingsList: some View {
        VStack(spacing: 11) {
            settingRow(icon: "yensign.circle", title: "時給の設定",
                       subtitle: data.hourlyRate.map { MoshiDopaBrand.yen($0) + " / h" } ?? "まだ設定されていません") {
                detail = .wage
            }
            .accessibilityIdentifier("open-wage")
            settingRow(icon: "square.grid.2x2", title: "対象アプリ", subtitle: "YouTube、Instagram、TikTok") {
                detail = .apps
            }
            .accessibilityIdentifier("open-apps")
            settingRow(icon: "yensign.circle", title: "値札の設定",
                       subtitle: counterSubtitle) {
                navigate(.counter)
            }
            .accessibilityIdentifier("open-counter")
            settingRow(icon: "bell", title: "表示と通知", subtitle: "値札・終了時の明細・アニメーション") {
                showDisplaySheet = true
            }
            .accessibilityIdentifier("open-display")
            settingRow(icon: "chart.bar.fill", title: "自己投資の記録", subtitle: "活動・プロジェクト・制作メモ") {
                detail = .invest
            }
            .accessibilityIdentifier("open-invest-settings")
            settingRow(icon: "doc.text", title: "日給・月給明細", subtitle: "通帳形式でまとめて共有") {
                navigate(.statement)
            }
            .accessibilityIdentifier("open-statement")
            settingRow(icon: "info.circle", title: "このアプリについて",
                       subtitle: "使い方・プライバシー・保存データ") {
                showAboutSheet = true
            }
            .accessibilityIdentifier("open-about")
        }
    }

    private var counterSubtitle: String {
        let style = data.selectedCounterDelivery == .pip ? data.pipStyle : data.liveStyle
        return "\(data.selectedCounterDelivery.compactTitle) · \(style.label)"
    }

    private func settingRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .frame(width: 26)
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(PaperMaterial())
            .shadow(color: MoshiDopaBrand.paperShadow, radius: 4, y: 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var supportLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("サポート")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.graphite)
            HStack(spacing: 10) {
                PaperButton(action: { navigate(.onboarding) }) { Label("使い方・ガイド", systemImage: "book") }
                    .accessibilityIdentifier("open-onboarding")
            }
            PaperButton(action: onOpenPiP) { Label("値札の表示を試す", systemImage: "rectangle.inset.filled") }
                .accessibilityIdentifier("open-pip")
        }
    }

    private func tabAction(_ tab: MDTab) {
        switch tab {
        case .measurement: navigate(.home)
        case .history: navigate(.history)
        case .settings: break
        }
    }
}

struct MDWageEditorSheet: View {
    @Binding var data: MDFixtureData
    @Environment(\.dismiss) private var dismiss
    @State private var rateText = ""
    @State private var monthly = false
    @State private var monthlyText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                MoshiDopaBrand.world.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    SampleModeBanner()
                    Text("時給の設定")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Text("記録を始めた時点の単価を明細に保存します。後から変更しても過去の記録は変わりません。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                    TogglePill(title: "月給から換算する", isOn: monthly) { monthly.toggle() }
                    if monthly {
                        TextField("月給（円）", text: $monthlyText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(PaperFieldStyle())
                    }
                    TextField("時給（円）", text: $rateText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(PaperFieldStyle())
                        .accessibilityIdentifier("wage-input")
                    Spacer()
                    LimeButton(action: save) { Text("この単価を保存") }
                        .accessibilityIdentifier("save-wage")
                }
                .padding(22)
            }
            .navigationTitle("時給")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
        }
        .onAppear {
            rateText = data.hourlyRate.map { String(Int($0)) } ?? ""
        }
    }

    private func save() {
        if let value = Double(rateText), value > 0 { data.hourlyRate = value }
        dismiss()
    }
}

struct MDAppsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = ["YouTube": true, "Instagram": true, "TikTok": true]

    var body: some View {
        NavigationStack {
            ZStack {
                MoshiDopaBrand.world.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 15) {
                    Text("対象アプリ")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Text("計測方法の準備状態を確認します。選んだアプリはサンプル表示です。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                    ForEach(["YouTube", "Instagram", "TikTok"], id: \.self) { app in
                        TogglePill(title: app, isOn: enabled[app] ?? false) {
                            enabled[app] = !(enabled[app] ?? false)
                        }
                    }
                    Spacer()
                }
                .padding(22)
            }
            .navigationTitle("対象アプリ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } } }
        }
    }
}

struct MDInvestSheet: View {
    @Binding var data: MDFixtureData
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = true

    var body: some View {
        NavigationStack {
            ZStack {
                MoshiDopaBrand.world.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("自己投資の記録")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    Text("INVESTは収益ではなく、自分に使った時間として記録します。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                    TogglePill(title: "プロジェクト名を明細に表示", isOn: enabled) { enabled.toggle() }
                    PaperCard(padding: 18) {
                        Label("例：個人開発 / 学習 / 創作", systemImage: "chart.bar.fill")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(MoshiDopaBrand.ink)
                    }
                    Spacer()
                }
                .padding(22)
            }
            .navigationTitle("自己投資")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } } }
        }
    }
}

struct MDDisplaySheet: View {
    let onOpenPiP: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hideTime = true
    @State private var receiptAfterStop = true

    var body: some View {
        NavigationStack {
            ZStack {
                MoshiDopaBrand.world.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    Text("表示と通知")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                    TogglePill(title: "共有では時間を隠す", isOn: hideTime) { hideTime.toggle() }
                    TogglePill(title: "終了時に明細を表示", isOn: receiptAfterStop) { receiptAfterStop.toggle() }
                    PaperCard(padding: 17) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("外部表示の境界")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("PiPはフレーム表示、Live Activityは更新時点の金額です。連続更新を約束しません。")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(MoshiDopaBrand.mutedInk)
                        }
                    }
                    LimeButton(action: onOpenPiP) { Label("PiPを試す", systemImage: "rectangle.inset.filled") }
                        .accessibilityIdentifier("open-pip")
                    Spacer()
                }
                .padding(22)
            }
            .navigationTitle("表示と通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } } }
        }
    }
}

struct MDAboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                MoshiDopaBrand.world.ignoresSafeArea()
                VStack(spacing: 14) {
                    Mascot(asset: "home_mascot_rest", size: 110)
                    Text("もしドパ")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                    Text("時間に値札を。\nデータは端末内に保存されます。")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                        .multilineTextAlignment(.center)
                    Text("Version P2A sample")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(MoshiDopaBrand.graphite)
                    Spacer()
                }
                .padding(22)
            }
            .navigationTitle("このアプリについて")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}
