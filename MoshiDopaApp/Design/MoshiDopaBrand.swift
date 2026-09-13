import SwiftUI

/// The small visual system shared by every native SwiftUI screen.
/// Values intentionally mirror the Android paper UI so screenshot comparisons remain useful.
enum MoshiDopaBrand {
    static let world = Color(red: 0.933, green: 0.929, blue: 0.902) // #EEEDE6
    static let paper = Color(red: 0.980, green: 0.976, blue: 0.953) // #FAF9F3
    static let ink = Color(red: 0.090, green: 0.098, blue: 0.106) // #17191B
    static let mutedInk = Color(red: 0.310, green: 0.314, blue: 0.290)
    static let graphite = Color(red: 0.415, green: 0.420, blue: 0.392)
    static let lime = Color(red: 0.824, green: 0.929, blue: 0.439) // #D2ED70
    static let limeInk = Color(red: 0.340, green: 0.390, blue: 0.120)
    static let red = Color(red: 0.722, green: 0.275, blue: 0.220) // #B84638
    static let bluePaper = Color(red: 0.845, green: 0.895, blue: 0.895)

    static let contentWidth: CGFloat = 640
    static let corner: CGFloat = 16
    static let paperShadow = Color.black.opacity(0.13)

    static func yen(_ value: Double, decimals: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        let text = formatter.string(from: NSNumber(value: max(0, value))) ?? "0"
        return "¥\(text)"
    }

    static func displayYen(_ value: Double) -> String {
        yen(value, decimals: value >= 1_000_000 || value < 1_000 ? 2 : 0)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let safe = max(0, Int(seconds.rounded()))
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let secs = safe % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

struct TornPaperShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: 0.5, dy: 0.5)
        // Fine irregular fibres, with slower undulations between tears.
        // Deterministic geometry keeps fixtures stable between captures.
        func edge(_ phase: Double) -> [CGFloat] {
            var points: [CGFloat] = []
            for index in 0...128 {
                let t = Double(index)
                let broad: Double = 0.19 * sin(t * 0.37 + phase)
                let medium: Double = 0.13 * sin(t * 1.91 + phase)
                let fine: Double = 0.09 * sin(t * 4.17 + phase)
                points.append(CGFloat(0.44 + broad + medium + fine))
            }
            return points
        }
        let top = edge(0.2)
        let bottom = edge(1.7)
        let left = edge(3.1)
        let right = edge(4.3)
        let edgeDepth: CGFloat = 2.4
        let width = max(1, inset.width)
        let height = max(1, inset.height)
        let count = top.count - 1
        var p = Path()
        p.move(to: CGPoint(x: inset.minX, y: inset.minY + top[0] * edgeDepth))
        for index in 1...count {
            let x = inset.minX + width * CGFloat(index) / CGFloat(count)
            p.addLine(to: CGPoint(x: x, y: inset.minY + top[index] * edgeDepth))
        }
        for index in 1...count {
            let y = inset.minY + height * CGFloat(index) / CGFloat(count)
            p.addLine(to: CGPoint(x: inset.maxX - right[index] * edgeDepth, y: y))
        }
        for index in stride(from: count - 1, through: 0, by: -1) {
            let x = inset.minX + width * CGFloat(index) / CGFloat(count)
            p.addLine(to: CGPoint(x: x, y: inset.maxY - bottom[index] * edgeDepth))
        }
        for index in stride(from: count - 1, through: 0, by: -1) {
            let y = inset.minY + height * CGFloat(index) / CGFloat(count)
            p.addLine(to: CGPoint(x: inset.minX + left[index] * edgeDepth, y: y))
        }
        p.closeSubpath()
        return p
    }
}

struct PaperCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    private let background: Color

    init(padding: CGFloat = 20, background: Color = MoshiDopaBrand.paper,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.background = background
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(TornPaperShape().fill(background))
            .overlay {
                Image("home_receipt_fiber")
                    .resizable(resizingMode: .tile)
                    .scaledToFill()
                    .opacity(0.28)
                    .blendMode(.multiply)
                    .clipShape(TornPaperShape())
                    .allowsHitTesting(false)
            }
            .overlay(TornPaperShape().stroke(Color.white.opacity(0.7), lineWidth: 1))
            .shadow(color: MoshiDopaBrand.paperShadow, radius: 7, x: 0, y: 4)
    }
}

struct Tape: View {
    var angle: Double = -8
    var width: CGFloat = 112

    var body: some View {
        Rectangle()
            .fill(Color(red: 0.84, green: 0.82, blue: 0.76).opacity(0.48))
            .frame(width: width, height: 28)
            .rotationEffect(.degrees(angle))
            .blendMode(.multiply)
            .accessibilityHidden(true)
    }
}

struct LimeScribble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.65))
        path.addLine(to: CGPoint(x: rect.width * 0.69, y: rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.width * 0.48, y: rect.height * 0.85))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.48))
        return path
    }
}

struct LimeButton<Content: View>: View {
    private let action: () -> Void
    private let content: Content

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 14)
                .background(TornPaperShape().fill(MoshiDopaBrand.lime))
                .overlay(TornPaperShape().stroke(Color.white.opacity(0.45), lineWidth: 1))
                .shadow(color: MoshiDopaBrand.paperShadow, radius: 4, y: 3)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

struct PaperButton<Content: View>: View {
    private let action: () -> Void
    private let content: Content

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 14)
                .background(TornPaperShape().fill(MoshiDopaBrand.paper))
                .overlay(TornPaperShape().stroke(Color.white.opacity(0.7), lineWidth: 1))
                .shadow(color: MoshiDopaBrand.paperShadow, radius: 4, y: 3)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.87 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SampleModeBanner: View {
    var body: some View {
        Label("サンプル表示 ・ 記録されません", systemImage: "sparkles")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(MoshiDopaBrand.limeInk)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Capsule().fill(MoshiDopaBrand.lime.opacity(0.76)))
            .accessibilityLabel("サンプル表示。記録されません")
    }
}

struct Mascot: View {
    let asset: String
    var size: CGFloat = 112

    var body: some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct Wordmark: View {
    var body: some View {
        Image("home_wordmark")
            .resizable()
            .scaledToFit()
            .frame(width: 210, height: 84)
            .accessibilityLabel("もしドパ")
    }
}

struct HeroPaper: View {
    let title: String
    let subtitle: String
    let mascotAsset: String
    var titleSize: CGFloat = 34

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PaperCard(padding: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .tracking(-0.8)
                        .foregroundStyle(MoshiDopaBrand.ink)
                    Rectangle()
                        .fill(MoshiDopaBrand.lime)
                        .frame(width: min(208, titleSize * 5.7), height: 6)
                        .rotationEffect(.degrees(-4))
                    Text(subtitle)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(MoshiDopaBrand.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 80)
            }
            Mascot(asset: mascotAsset, size: 116)
                .offset(x: -8, y: 12)
        }
    }
}

enum MDTab: String, CaseIterable, Hashable {
    case measurement, history, settings

    var title: String {
        switch self {
        case .measurement: return "計測"
        case .history: return "履歴"
        case .settings: return "設定"
        }
    }

    var icon: String {
        switch self {
        case .measurement: return "timer"
        case .history: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }

    var accessibilityID: String {
        switch self {
        case .measurement: return "tab-home"
        case .history: return "tab-history"
        case .settings: return "tab-settings"
        }
    }
}

struct MoshiDopaTabBar: View {
    let selected: MDTab
    let action: (MDTab) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(MDTab.allCases, id: \.self) { tab in
                Button {
                    action(tab)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: .bold))
                        Text(tab.title)
                            .font(.system(size: 14, weight: tab == selected ? .bold : .medium, design: .rounded))
                    }
                    .foregroundStyle(tab == selected ? MoshiDopaBrand.ink : MoshiDopaBrand.graphite)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        if tab == selected {
                            TornPaperShape().fill(MoshiDopaBrand.lime)
                        }
                    }
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityIdentifier(tab.accessibilityID)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(TornPaperShape().fill(MoshiDopaBrand.paper))
        .overlay(TornPaperShape().stroke(Color.white.opacity(0.7), lineWidth: 1))
        .shadow(color: MoshiDopaBrand.paperShadow, radius: 8, y: -2)
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
        .accessibilityElement(children: .contain)
    }
}

struct ScreenShell<Content: View>: View {
    let id: String
    let tab: MDTab?
    let tabAction: (MDTab) -> Void
    private let content: Content

    init(id: String, tab: MDTab? = nil, tabAction: @escaping (MDTab) -> Void = { _ in },
         @ViewBuilder content: () -> Content) {
        self.id = id
        self.tab = tab
        self.tabAction = tabAction
        self.content = content()
    }

    var body: some View {
        ZStack {
            MoshiDopaBrand.world.ignoresSafeArea()
            Image("home_receipt_fiber")
                .resizable(resizingMode: .tile)
                .opacity(0.18)
                .blendMode(.multiply)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            ScrollView(showsIndicators: false) {
                content
                    .frame(maxWidth: MoshiDopaBrand.contentWidth)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, tab == nil ? 36 : 108)
                    .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let tab {
                MoshiDopaTabBar(selected: tab, action: tabAction)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen-\(id)")
    }
}

struct BackRow: View {
    let title: String
    let action: () -> Void
    var body: some View {
        HStack {
            Button(action: action) {
                Label("戻る", systemImage: "chevron.left")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(MoshiDopaBrand.ink)
                    .frame(minWidth: 48, minHeight: 48, alignment: .leading)
            }
            .accessibilityIdentifier("back")
            Spacer()
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(MoshiDopaBrand.ink)
            Spacer()
            Color.clear.frame(width: 48, height: 48)
                .accessibilityHidden(true)
        }
    }
}

struct TogglePill: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
            }
            .foregroundStyle(isOn ? MoshiDopaBrand.ink : MoshiDopaBrand.mutedInk)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(TornPaperShape().fill(isOn ? MoshiDopaBrand.lime : MoshiDopaBrand.paper))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
