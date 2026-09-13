import SwiftUI

struct MDMeasurementView: View {
    @Binding var data: MDFixtureData
    @Binding var mode: MDMode
    let navigate: (MDRoute) -> Void
    let goBack: () -> Void
    let onOpenPiP: () -> Void
    @State private var activityName = ""
    @State private var project = ""
    @State private var note = ""
    @State private var category = "個人開発"
    @State private var startedAt: Date?
    @State private var showApps = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case activity, project, note }

    var body: some View {
        ScreenShell(id: "measurement", tab: .measurement, tabAction: tabAction) {
            VStack(alignment: .leading, spacing: 18) {
                BackRow(title: "計測", action: goBack)
                HStack { SampleModeBanner(); Spacer() }
                HeroPaper(title: "計測", subtitle: "スマホでも、スマホの外でも。", mascotAsset: "home_mascot_coin", titleSize: 36)
                if let startedAt {
                    runningCard(startedAt: startedAt)
                } else {
                    sourceSection
                    manualSection
                }
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("スマホの時間は自動で。\nスマホの外の活動は、名前をつけて手動で。")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.18))
            Text("01 / スマホの時間を自動で計測")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.graphite)
            Text("アプリを開くと、今回のセッション額と今日のトータルが増えていきます。")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.mutedInk)
            Button { showApps.toggle() } label: {
                HStack {
                    Label("対象アプリを選ぶ · 3件", systemImage: "square.grid.2x2")
                    Spacer()
                    Image(systemName: showApps ? "chevron.up" : "chevron.down")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
                .padding(.horizontal, 18)
                .frame(minHeight: 54)
                .background(TornPaperShape().fill(MoshiDopaBrand.paper))
            }
            .accessibilityIdentifier("choose-apps")
            if showApps {
                PaperCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("計測対象")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        ForEach(["YouTube", "Instagram", "TikTok"], id: \.self) { app in
                            Label(app, systemImage: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(MoshiDopaBrand.limeInk)
                        }
                        Text("iOSでは利用状況の取得方法がAndroidと異なります。利用可能な導線を確認してから開始します。")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(MoshiDopaBrand.mutedInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            LimeButton(action: { begin(named: "アプリの時間") }) {
                Label("自動計測をはじめる ↗", systemImage: "play.fill")
            }
            .accessibilityIdentifier("start-automatic")
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(MoshiDopaBrand.graphite.opacity(0.18))
            Text("02 / スマホの外の時間を手動で計測")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.graphite)
            modePicker
            TextField(mode == .invest ? "例：個人開発" : "例：ぼーっとする", text: $activityName)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .textFieldStyle(PaperFieldStyle())
                .focused($focusedField, equals: .activity)
                .accessibilityIdentifier("activity-name")
            if mode == .invest {
                Text("CATEGORY / 分類")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.graphite)
                categoryPicker
                TextField("プロジェクト名（任意）", text: $project)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .textFieldStyle(PaperFieldStyle())
                    .focused($focusedField, equals: .project)
                TextField("今日やったこと（任意）", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .textFieldStyle(PaperFieldStyle())
                    .focused($focusedField, equals: .note)
            }
            LimeButton(action: { begin(named: activityName.isEmpty ? (mode == .invest ? "サンプル活動" : "手動記録") : activityName) }) {
                Label("START \(mode.shortTitle)", systemImage: mode == .spend ? "play.fill" : "chart.bar.fill")
            }
            .accessibilityIdentifier(mode == .spend ? "start-spend" : "start-invest")
        }
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(MDMode.allCases) { value in
                Button { mode = value } label: {
                    Text(value.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(value == mode ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(TornPaperShape().fill(value == mode ? MoshiDopaBrand.lime : MoshiDopaBrand.paper))
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier("mode-\(value.rawValue.lowercased())")
            }
        }
    }

    private var categoryPicker: some View {
        HStack(spacing: 6) {
            ForEach(["個人開発", "学習", "創作"], id: \.self) { value in
                Button { category = value } label: {
                    HStack(spacing: 4) {
                        Image(systemName: category == value ? "circle.inset.filled" : "circle")
                        Text(value)
                    }
                    .font(.system(size: 13, weight: category == value ? .bold : .medium, design: .rounded))
                    .foregroundStyle(category == value ? MoshiDopaBrand.limeInk : MoshiDopaBrand.mutedInk)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func runningCard(startedAt: Date) -> some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let rate = data.hourlyRate ?? 1_800
            let amount = elapsed / 3600 * rate
            PaperCard(padding: 22, background: mode == .spend ? MoshiDopaBrand.paper : MoshiDopaBrand.lime.opacity(0.55)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("計測中 · \(mode.shortTitle)", systemImage: "record.circle.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(mode == .spend ? MoshiDopaBrand.red : MoshiDopaBrand.limeInk)
                        Spacer()
                        Text("保存は停止時")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(MoshiDopaBrand.mutedInk)
                    }
                    Text(MoshiDopaBrand.yen(amount, decimals: 2))
                        .font(.system(size: 52, weight: .black, design: .monospaced))
                        .foregroundStyle(MoshiDopaBrand.ink)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                    Text(activityName.isEmpty ? "アプリの時間" : activityName)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    HStack {
                        Label(MoshiDopaBrand.duration(elapsed), systemImage: "clock")
                        Spacer()
                        Text("時給 \(MoshiDopaBrand.yen(rate))")
                    }
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(MoshiDopaBrand.mutedInk)
                    HStack(spacing: 10) {
                        LimeButton(action: stop) { Label("STOP & SAVE", systemImage: "stop.fill") }
                            .accessibilityIdentifier("stop-measurement")
                        PaperButton(action: onOpenPiP) { Label("値札を表示", systemImage: "rectangle.inset.filled") }
                            .accessibilityIdentifier("open-pip")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(mode.shortTitle)を計測中。\(MoshiDopaBrand.yen(amount))")
        }
    }

    private func begin(named name: String) {
        activityName = name
        startedAt = Date()
        focusedField = nil
    }

    private func stop() {
        guard let startedAt else { return }
        let duration = max(1, Date().timeIntervalSince(startedAt))
        data.activities.insert(MDActivity(id: UUID(), appName: mode == .spend ? "iPhone" : "手動記録",
                                          activityName: activityName.isEmpty ? "手動記録" : activityName,
                                          mode: mode, startedAt: MDFixtureData.referenceDate,
                                          duration: duration, hourlyRate: data.hourlyRate ?? 1_800,
                                          project: project, note: note), at: 0)
        self.startedAt = nil
    }

    private func tabAction(_ tab: MDTab) {
        switch tab {
        case .measurement: break
        case .history: navigate(.history)
        case .settings: navigate(.settings)
        }
    }
}

struct PaperFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 18)
            .frame(minHeight: 55)
            .background(TornPaperShape().fill(MoshiDopaBrand.paper))
            .overlay(TornPaperShape().stroke(Color.white.opacity(0.7), lineWidth: 1))
    }
}
