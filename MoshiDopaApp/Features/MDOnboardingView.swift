import SwiftUI

struct MDOnboardingView: View {
    let goBack: () -> Void
    let finish: () -> Void
    @State private var step = 0
    @State private var rateText = "1,800"
    @State private var delivery: MDCounterDelivery = .pip
    @State private var apps = Set(["YouTube", "Instagram"])
    @State private var accessChecked = false

    private let steps = [
        ("そのスクロール、\nもし働いてたら？", "もしもドパがキミが働いたら。\n見るのは禁止しない。ただ、時間に値札を。", "金額の表示見本"),
        ("まずは、\nあなたの単価。", "時給または月給から、時間の値札を計算します。記録を始めた単価を明細に残します。", "時給を設定"),
        ("スマホの時間を、\nひとつの方法で。", "iOSではショートカットなど、利用できる計測方法を案内します。ここは準備状態の見本です。", "設定ガイドを見る"),
        ("対象を選んで、\n準備する。", "ショートカットで使うアプリを選ぶ見本です。手動で活動名をつけることもできます。", "対象アプリを選ぶ"),
        ("値札の見た目を、\n選ぼう。", "PiPやLive Activityの表示方法とデザインを選ぶ見本です。面ごとの制約は次の画面で確認します。", "値札を選ぶ"),
        ("準備できました。\n時間に値札を。", "STARTを押すと計測が始まります。STOPで保存して、紙の明細を振り返れます。", "はじめる")
    ]

    var body: some View {
        ScreenShell(id: "onboarding") {
            VStack(alignment: .leading, spacing: 17) {
                topBar
                progress
                HStack { SampleModeBanner(); Spacer() }
                Text("SETUP / \(String(format: "%02d", step + 1))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.graphite)
                Text(steps[step].0)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(-0.7)
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(steps[step].1)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                stepContent
                HStack(spacing: 10) {
                    if step > 0 {
                        PaperButton(action: previous) { Label("戻る", systemImage: "chevron.left") }
                            .accessibilityIdentifier("onboarding-back")
                    }
                    LimeButton(action: next) { Text(steps[step].2) }
                        .accessibilityIdentifier(step == steps.count - 1 ? "onboarding-finish" : "onboarding-next")
                }
                if step < steps.count - 1 {
                    Button("あとで設定する") { finish() }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .accessibilityIdentifier("onboarding-skip")
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { goBack() } label: {
                Label("閉じる", systemImage: "xmark")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .frame(minWidth: 48, minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("onboarding-close")
            Spacer()
            Button("最初から") { step = 0 }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .accessibilityIdentifier("onboarding-replay")
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? MoshiDopaBrand.ink : MoshiDopaBrand.paper)
                    .frame(height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("全6ステップ中、\(step + 1)ステップ")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: demoContent
        case 1: rateContent
        case 2: accessContent
        case 3: appsContent
        case 4: counterContent
        default: readyContent
        }
    }

    private var demoContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            PaperCard(padding: 21) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("DEMO / 金額の表示見本", systemImage: "circle.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("¥3.93")
                        .font(.system(size: 58, weight: .black, design: .monospaced))
                    Text("時給 ¥1,800.00で換算 · 記録されません")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                }
            }
            Text("ここで動く数字は見本です。実際の記録は、あなたがSTARTしたときだけ保存します。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
        }
    }

    private var rateContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("時給（円）", text: $rateText)
                .keyboardType(.decimalPad)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .textFieldStyle(PaperFieldStyle())
                .accessibilityIdentifier("onboarding-rate")
            Text("あとから変更できます。進行中の計測には、開始時の単価を使います。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
        }
    }

    private var accessContent: some View {
        PaperCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Label("利用状況アクセス", systemImage: "lock.shield")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("iOSの権限と表示方式を確認し、利用できる機能だけを案内します。未許可のまま完了とは表示しません。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                Button(accessChecked ? "確認しました（見本）" : "設定ガイドを確認する") { accessChecked.toggle() }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.limeInk)
                    .accessibilityIdentifier("onboarding-check-access")
                Text("このP2A画面ではiOSのシステム設定は開かず、選択を保存しません。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var appsContent: some View {
        VStack(spacing: 9) {
            ForEach(["YouTube", "Instagram", "TikTok"], id: \.self) { app in
                TogglePill(title: app, isOn: apps.contains(app)) {
                    if apps.contains(app) { apps.remove(app) } else { apps.insert(app) }
                }
            }
        }
    }

    private var counterContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(MDCounterDelivery.allCases) { candidate in
                    Button { delivery = candidate } label: {
                        Text(candidate.compactTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(delivery == candidate ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(TornPaperShape().fill(delivery == candidate ? MoshiDopaBrand.lime : MoshiDopaBrand.paper))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityIdentifier("onboarding-\(candidate.rawValue)")
                }
            }
            CounterPreview(style: .paper, delivery: delivery)
        }
    }

    private var readyContent: some View {
        PaperCard(padding: 21) {
            VStack(alignment: .leading, spacing: 11) {
                Label("READY / 準備完了", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("時給 \(rateText.isEmpty ? "未設定" : rateText) · \(apps.count)アプリ · \(delivery.compactTitle)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("データは端末内に保存。ログイン・広告なし。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func next() {
        if step < steps.count - 1 { withAnimation(.easeInOut(duration: 0.22)) { step += 1 } } else { finish() }
    }

    private func previous() {
        guard step > 0 else { return }
        withAnimation(.easeInOut(duration: 0.22)) { step -= 1 }
    }
}
