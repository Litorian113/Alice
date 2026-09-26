import Foundation

enum UsagePeriod: String, CaseIterable, Identifiable {
    case today = "Today", week = "Week", month = "Month"
    var id: String { rawValue }
    var caption: String {
        switch self {
        case .today: return "Today, 26 September"
        case .week: return "21–27 September"
        case .month: return "September 2026"
        }
    }
    var samples: [UsageSample] {
        let labels: [String]
        let values: [Double]
        switch self {
        case .today:
            labels = ["08", "09", "10", "11", "12", "13", "14", "15"]
            values = [1.4, 2.8, 6.2, 10.5, 8.1, 12.3, 10.4, 6.8]
        case .week:
            labels = ["M", "T", "W", "T", "F", "S", "S"]
            values = [26.2, 38.4, 18.7, 47.1, 35.6, 58.5, 0]
        case .month:
            labels = ["1–7", "8–14", "15–21", "22–28", "29–30"]
            values = [112.4, 158.2, 194.6, 198.3, 0]
        }
        return labels.indices.map { UsageSample(id: $0, label: labels[$0], tokens: values[$0] * 1000) }
    }
    var total: Double { samples.reduce(0) { $0 + $1.tokens } }
}

struct UsageSample: Identifiable {
    let id: Int
    let label: String
    let tokens: Double
    var input: Double { tokens * 0.78 }
    var output: Double { tokens * 0.22 }
}

extension Double {
    var tokenLabel: String { String(format: "%.1fk", self / 1000) }
}
