import SwiftUI

extension Color {
    static let aliceBackground = Color(hex: "F5F7FC")
    static let aliceSurface = Color.white
    static let aliceSurfaceRaised = Color(hex: "EDF1FA")
    static let alicePrimary = Color(hex: "15233F")
    static let aliceSecondary = Color(hex: "65718A")
    static let aliceMuted = Color(hex: "768197")
    static let aliceAccent = Color(hex: "0F62FE")
    static let aliceRecommended = Color(hex: "7154D8")
    static let aliceBorder = Color(hex: "E3E8F2")
    static let aliceRiskLow = Color(hex: "198061")
    static let aliceRiskMedium = Color(hex: "AD6800")
    static let aliceRiskHigh = Color(hex: "C13C4B")
    static let aliceSuccess = aliceRiskLow
    static let aliceError = aliceRiskHigh

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255, opacity: 1)
    }
}

extension Font {
    static func plex(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let face: String
        switch weight {
        case .bold, .semibold: face = "IBMPlexSans-SemiBold"
        case .medium: face = "IBMPlexSans-Medium"
        default: face = "IBMPlexSans-Regular"
        }
        return .custom(face, size: size, relativeTo: style)
    }
}

extension DecisionCard.RiskLevel {
    var color: Color {
        switch self {
        case .low: return .aliceRiskLow
        case .medium: return .aliceRiskMedium
        case .high: return .aliceRiskHigh
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

struct AliceSurfaceModifier: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .background(Color.aliceSurface, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.aliceBorder.opacity(0.7), lineWidth: 1))
    }
}

extension View {
    func aliceSurface(radius: CGFloat = 24) -> some View {
        modifier(AliceSurfaceModifier(radius: radius))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.plex(10, weight: .semibold, relativeTo: .caption2))
            .tracking(1.8)
            .foregroundStyle(Color.aliceSecondary)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon = "arrow.right"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: icon)
            }
            .font(.plex(16, weight: .medium))
            .foregroundStyle(.white)
            .padding(18)
            .background(Color.aliceAccent, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
