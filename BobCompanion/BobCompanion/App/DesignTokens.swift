import SwiftUI

// MARK: - Design Tokens

extension Color {
    // Backgrounds
    static let bcBackground = Color(hex: "#0A0A0F")       // deep dark
    static let bcSurface = Color(hex: "#13131A")          // card surface
    static let bcSurfaceRaised = Color(hex: "#1C1C26")    // elevated card

    // Text
    static let bcPrimary = Color(hex: "#F0F0F5")
    static let bcSecondary = Color(hex: "#8888A0")
    static let bcMuted = Color(hex: "#55556A")

    // Accent
    static let bcAccent = Color(hex: "#7C5CD8")           // Bob purple
    static let bcRecommended = Color(hex: "#A78BFA")      // recommendation highlight

    // Risk
    static let bcRiskLow = Color(hex: "#34D399")          // green
    static let bcRiskMedium = Color(hex: "#FBBF24")       // amber
    static let bcRiskHigh = Color(hex: "#F87171")         // red

    // Status
    static let bcSuccess = Color(hex: "#34D399")
    static let bcError = Color(hex: "#F87171")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

extension DecisionCard.RiskLevel {
    var color: Color {
        switch self {
        case .low: return .bcRiskLow
        case .medium: return .bcRiskMedium
        case .high: return .bcRiskHigh
        }
    }

    var label: String {
        switch self {
        case .low: return "Low risk"
        case .medium: return "Medium risk"
        case .high: return "High risk"
        }
    }
}
