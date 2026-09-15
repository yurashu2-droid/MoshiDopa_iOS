import SwiftUI
import UIKit

/// Progress records the user's place in the guide, never the system's automation state.
struct AutomationSetupView: View {
    @ObservedObject private var model = PiPDiagnosticsModel.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("native.automationGuide.target") private var target = "Instagram"
    @AppStorage("native.automationGuide.step") private var savedStep = 0
    @State private var launchFailed = false
    let onFinish: () -> Void

    private var step: Int { min(7, max(0, savedStep)) }
    private var name: String { target.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSetMode: Bool { model.snapshot == nil && !model.finishingExternal }
    private var isOpening: Bool { step < 4 }
    private var actionName: String {
        isOpening ? "対象アプリの計測を再開" : "対象アプリの計測を一時停止"
    }
    private var title: String {
        switch step {
        case 0: return "計測したいアプリを選ぶ"
        case 1, 4: return "オートメーションを作る"
        case 2: return "開いたときの条件を選ぶ"
        case 5: return "閉じたときの条件を選ぶ"
        case 3, 6: return "もしドパのアクションを追加"
        default: return "実際に動くか試す"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("ステップ \(step + 1) / 8")
                            .font(.subheadline.bold()).foregroundStyle(.secondary)
                        ProgressView(value: Double(step + 1), total: 8)
                        Text(title).font(.title2.bold())
                            .accessibilityIdentifier("automation-step-title")
                        if step == 0 {
                            Text("アプリごとに「開いたとき」と「閉じたとき」の2つを設定します。")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading) {
                                ForEach(["Instagram", "TikTok", "YouTube"], id: \.self) { app in
                                    Button(app) { target = app }.buttonStyle(.bordered)
                                }
                            }
                            TextField("対象アプリ名", text: $target)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled().textInputAutocapitalization(.never)
                                .accessibilityIdentifier("automation-target")
                            Text("一覧にないアプリも入力できます。この名前を、開閉両方のアクションに使います。ショートカット側でも対象アプリを選んでください。")
                                .font(.callout).foregroundStyle(.secondary)
                            if !canSetMode {
                                Text("先に計測画面で停止・保存してください。計測中の方法は変更できません。")
                            }
                        } else if step == 7 {
                            instruction(1, "計測画面で「対象アプリの開閉（Shortcuts）」になっていることを確認し、「待機開始」を押します。")
                            instruction(2, "選んだ値札を開始し、\(name)を開きます。金額が増えるか確認します。")
                            instruction(3, "\(name)を閉じ、もしドパに戻ります。金額が止まるか確認し、「停止・保存」を押します。")
                            Text("ここまで進めても、設定の成功はまだ確認できていません。実際の開閉で確かめてください。強制終了後は再び待機開始が必要です。")
                                .font(.callout).foregroundStyle(.secondary)
                            if model.trackingMode != "shortcuts" && !canSetMode {
                                Text("別の計測方法で計測中です。先に計測画面で停止・保存してください。")
                            }
                            Button("計測画面で試す") {
                                if canSetMode { model.trackingMode = "shortcuts" }
                                dismiss()
                                onFinish()
                            }.buttonStyle(.borderedProminent)
                                .disabled(model.trackingMode != "shortcuts" && !canSetMode)
                                .accessibilityIdentifier("automation-try")
                        } else {
                            Text("対象：\(name) · \(isOpening ? "開いたとき" : "閉じたとき")")
                                .font(.headline)
                            externalInstructions
                            Button {
                                UIApplication.shared.open(URL(string: "shortcuts://")!) { opened in
                                    Task { @MainActor in launchFailed = !opened }
                                }
                            } label: {
                                Label("ショートカットを開く", systemImage: "arrow.up.right.square")
                            }.buttonStyle(.borderedProminent)
                            Text("設定したら、アプリ切り替えでここへ戻り「次へ」を押してください。戻るだけでは手順は進みません。")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        if step < 7 {
                            Button(step == 0 ? "このアプリで設定を始める" : "確認したので次へ") {
                                if step == 0 { model.trackingMode = "shortcuts" }
                                savedStep = step + 1
                            }.buttonStyle(.borderedProminent)
                                .disabled(step == 0 && (name.isEmpty || !canSetMode))
                                .accessibilityIdentifier("automation-next")
                        }
                        if step > 0 {
                            Button("前の手順へ") { savedStep = step - 1 }
                                .accessibilityIdentifier("automation-back")
                            Button("別のアプリを設定／最初から見直す") { savedStep = 0 }
                            Text("ガイドを戻しても、作成済みのオートメーションは削除されません。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("進み具合は保存されます。もしドパからオートメーションを自動登録したり、登録内容を読み取ったりすることはできません。iOSによって項目の名前や位置が少し異なります。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(20).frame(maxWidth: 600, alignment: .leading)
                    .id("automation-guide-top")
                }
                .onChange(of: savedStep) { _, _ in
                    proxy.scrollTo("automation-guide-top", anchor: .top)
                }
            }
            .navigationTitle("対象アプリの設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
            .alert("ショートカットを開けませんでした", isPresented: $launchFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("ショートカットアプリがインストールされているか確認し、ホーム画面から開いてください。")
            }
        }
    }

    @ViewBuilder private var externalInstructions: some View {
        switch step {
        case 1, 4:
            instruction(1, "ショートカットを開き、下の「オートメーション」をタップします。")
            instruction(2, "「＋」または「新規オートメーション」をタップし、作動条件の「アプリ」を選びます。個人用オートメーションの選択が出たら、それを選んでください。")
        case 2, 5:
            instruction(1, "「選択」で \(name) だけを選びます。")
            instruction(2, "「\(isOpening ? "開いている" : "閉じている")」だけにチェックを付けます。もう一方は外します。")
            instruction(3, "「すぐに実行」を選び、「次へ」をタップします。")
        default:
            instruction(1, "空のオートメーションを選び、アクションの検索で「もしドパ」を探します。")
            instruction(2, "「\(actionName)」を追加します。")
            HStack {
                Text(actionName).font(.headline)
                Spacer()
                Button("名前をコピー") { UIPasteboard.general.string = actionName }
            }
            instruction(3, "アクション内の「対象アプリ名」を \(name) にします。開閉両方で、一文字も変えず同じ名前を使ってください。")
            Button("対象アプリ名をコピー") { UIPasteboard.general.string = name }
            instruction(4, "「完了」で保存します。ここでは再生ボタンで試さず、最後にもしドパで待機開始してから試します。")
        }
    }

    private func instruction(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.headline).frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
