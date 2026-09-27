import Foundation

// Prototype only: Bobcoin values copied from Franz's Bobalytics screenshot.
// Token samples are invented independently, not converted from Bobcoins.
enum UsageData {
    static let bobcoinLimit = 40
    static let bobcoinsUsed = 14
    static var bobcoinsRemaining: Int { bobcoinLimit - bobcoinsUsed }
    static var bobcoinFraction: Double { Double(bobcoinsUsed) / Double(bobcoinLimit) }

    static let days: [UsageSample] = [
        UsageSample(id: 0, label: "25 Sep", input: 38_200, output: 9_800),
        UsageSample(id: 1, label: "26 Sep", input: 67_400, output: 17_600),
        UsageSample(id: 2, label: "27 Sep", input: 91_300, output: 24_700)
    ]
}

enum UsagePeriod: String, CaseIterable, Identifiable {
    case today = "Today", threeDays = "3 days"
    var id: String { rawValue }
    var caption: String {
        switch self {
        case .today: return "27 September 2026"
        case .threeDays: return "25–27 September 2026"
        }
    }
    var samples: [UsageSample] {
        switch self {
        case .today:
            let input: [Double] = [4_200, 7_600, 11_800, 16_200, 13_400, 18_700, 12_100, 7_300]
            let output: [Double] = [1_100, 2_000, 3_200, 4_400, 3_600, 5_100, 3_200, 2_100]
            return input.indices.map {
                UsageSample(id: $0, label: String(format: "%02d", $0 + 8), input: input[$0], output: output[$0])
            }
        case .threeDays: return UsageData.days
        }
    }
    var inputTotal: Double { samples.reduce(0) { $0 + $1.input } }
    var outputTotal: Double { samples.reduce(0) { $0 + $1.output } }
    var total: Double { inputTotal + outputTotal }
}

struct UsageSample: Identifiable {
    let id: Int
    let label: String
    let input: Double
    let output: Double
    var tokens: Double { input + output }
}

extension Double {
    var tokenLabel: String { String(format: "%.1fk", self / 1000) }
}
