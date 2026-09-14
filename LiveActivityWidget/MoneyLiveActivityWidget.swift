import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MoneyLiveActivityBundle: WidgetBundle {
    var body: some Widget { MoneyLiveActivityWidget() }
}

struct MoneyLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MoneyActivityAttributes.self) { context in
            MoneyLockScreenView(context: context)
                .activityBackgroundTint(context.attributes.style == "ink" ? MoneyPalette.ink : context.attributes.style == "frost" ? MoneyPalette.frost : MoneyPalette.paper)
                .activitySystemActionForegroundColor(context.attributes.style == "ink" ? MoneyPalette.paper : MoneyPalette.ink)
                .widgetURL(URL(string: "moshidopa://counter"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("もしドパ").font(.caption.bold()).foregroundStyle(MoneyPalette.lime)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(MoneyActivityFormat.yen(context.state.hourlyRate, decimals: 0) + "/時")
                        .font(.caption).foregroundStyle(MoneyPalette.paper)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(MoneyActivityFormat.yen(context.state.amount))
                            .font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.4)
                        MoneySampleLabel(context: context)
                    }
                    .foregroundStyle(MoneyPalette.paper)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Text(MoneyActivityFormat.compactYen(context.state.amount))
                    .font(.system(size: 12, weight: .bold, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.4).foregroundStyle(MoneyPalette.paper)
                    .accessibilityLabel("更新時点の金額 " + MoneyActivityFormat.yen(context.state.amount))
            } compactTrailing: {
                Text(context.isStale ? "前回" : context.state.isCounting ? "計測" : "停止")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(MoneyPalette.lime)
            } minimal: {
                Text(MoneyActivityFormat.compactYen(context.state.amount))
                    .font(.system(size: 9, weight: .bold, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.3).foregroundStyle(MoneyPalette.paper)
                    .accessibilityLabel("更新時点の金額 " + MoneyActivityFormat.yen(context.state.amount))
            }
            .keylineTint(MoneyPalette.lime)
            .widgetURL(URL(string: "moshidopa://counter"))
        }
    }
}

private enum MoneyPalette {
    static let paper = Color(red: 0.980, green: 0.976, blue: 0.953)
    static let ink = Color(red: 0.090, green: 0.098, blue: 0.106)
    static let lime = Color(red: 0.824, green: 0.929, blue: 0.439)
    static let frost = Color(red: 0.87, green: 0.92, blue: 0.95)
}

private struct MoneyLockScreenView: View {
    let context: ActivityViewContext<MoneyActivityAttributes>
    private var foreground: Color { context.attributes.style == "ink" ? MoneyPalette.paper : MoneyPalette.ink }
    @ViewBuilder var body: some View {
        switch context.attributes.style {
        case "ink":
            HStack(spacing: 12) {
                Image(systemName: "play.fill").foregroundStyle(MoneyPalette.lime)
                Rectangle().fill(MoneyPalette.paper.opacity(0.25)).frame(width: 1, height: 60)
                content
            }
            .padding(16).background(MoneyPalette.ink, in: RoundedRectangle(cornerRadius: 18))
        case "frost":
            content.padding(16)
                .background(LinearGradient(colors: [.white, MoneyPalette.frost], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.8), lineWidth: 1))
        case "sticker":
            content.padding(16)
                .background(MoneyPalette.paper, in: RoundedRectangle(cornerRadius: 28))
                .overlay(alignment: .topTrailing) {
                    Image("home_mascot_coin").resizable().scaledToFit().frame(width: 46, height: 46)
                        .padding(.trailing, 12).accessibilityHidden(true)
                }
        default:
            content.padding(16).background(MoneyPalette.paper, in: MoneyTornTag())
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("もしドパ · 値札").font(.caption.bold())
                Spacer()
                Text(MoneyActivityFormat.yen(context.state.hourlyRate, decimals: 0) + "/時").font(.caption)
                    .padding(.trailing, context.attributes.style == "sticker" ? 46 : 0)
            }
            Text(MoneyActivityFormat.yen(context.state.amount))
                .font(.system(size: 37, weight: .black, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.4)
            MoneySampleLabel(context: context)
        }
        .foregroundStyle(foreground)
    }
}

private struct MoneyTornTag: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        for index in 0...36 {
            path.addLine(to: CGPoint(x: rect.minX + CGFloat(index) * rect.width / 36, y: rect.minY + (index % 2 == 0 ? 0 : 3)))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        for index in stride(from: 36, through: 0, by: -1) {
            path.addLine(to: CGPoint(x: rect.minX + CGFloat(index) * rect.width / 36, y: rect.maxY - (index % 2 == 0 ? 0 : 3)))
        }
        path.closeSubpath()
        return path
    }
}

private struct MoneySampleLabel: View {
    let context: ActivityViewContext<MoneyActivityAttributes>
    var body: some View {
        HStack(spacing: 4) {
            Text(context.isStale ? "前回の金額" : context.state.isCounting ? "計測中 · 更新時点" : "停止 · 更新時点")
            Text(context.state.updatedAt, style: .time)
        }
        .font(.caption2)
        .opacity(0.8)
        .accessibilityElement(children: .combine)
    }
}
