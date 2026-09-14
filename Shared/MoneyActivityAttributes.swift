import ActivityKit
import Foundation

/// Shared wire model. The extension deliberately has no dependency on the app session domain.
struct MoneyActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var amount: Double
        var hourlyRate: Double
        var elapsedMilliseconds: Int64
        var isCounting: Bool
        var updatedAt: Date
    }
    var sessionID: UUID
    var startedAt: Date
    var style: String
}

enum MoneyActivityFormat {
    static func yen(_ value: Double, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return "¥" + (formatter.string(from: NSNumber(value: value.isFinite ? max(0, value) : 0)) ?? "0")
    }
    /// Matches the app's compact counter preview: whole yen, then whole ten-thousand yen.
    static func compactYen(_ value: Double) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        if safe >= 10_000 { return "¥\(Int(min(safe / 10_000, Double(Int.max / 2))))万" }
        return yen(floor(safe), decimals: 0)
    }
}
