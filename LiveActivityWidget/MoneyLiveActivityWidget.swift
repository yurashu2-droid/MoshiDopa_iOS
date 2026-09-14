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
                .activityBackgroundTint(context.attributes.style == "ink" ? MoneyPalette.ink : MoneyPalette.paper)
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
}

private struct MoneyLockScreenView: View {
    let context: ActivityViewContext<MoneyActivityAttributes>
    private var foreground: Color { context.attributes.style == "ink" ? MoneyPalette.paper : MoneyPalette.ink }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("もしドパ · 値札").font(.caption.bold())
                Spacer()
                Text(MoneyActivityFormat.yen(context.state.hourlyRate, decimals: 0) + "/時").font(.caption)
            }
            Text(MoneyActivityFormat.yen(context.state.amount))
                .font(.system(size: 37, weight: .black, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.4)
            MoneySampleLabel(context: context)
        }
        .padding(16)
        .foregroundStyle(foreground)
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
