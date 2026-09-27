import SwiftUI

extension Color {
    static let aliceBackground = adaptive(light: "F5F7FC", dark: "101521")
    static let aliceSurface = adaptive(light: "FFFFFF", dark: "1B2333")
    static let aliceSurfaceRaised = adaptive(light: "EDF1FA", dark: "252F43")
    static let alicePrimary = adaptive(light: "15233F", dark: "F0F3FB")
    static let aliceSecondary = adaptive(light: "65718A", dark: "B1BCD1")
    static let aliceMuted = adaptive(light: "768197", dark: "98A6BF")
    static let aliceAccent = Color(hex: "0F62FE")
    static let aliceRecommended = adaptive(light: "7154D8", dark: "BAA4FF")
    static let aliceBorder = adaptive(light: "E3E8F2", dark: "344057")
    static let aliceRiskLow = adaptive(light: "198061", dark: "6AD8B1")
    static let aliceRiskMedium = adaptive(light: "AD6800", dark: "F2BE67")
    static let aliceRiskHigh = adaptive(light: "C13C4B", dark: "FF96A3")
    static let aliceVioletSurface = adaptive(light: "EDE8FC", dark: "302845")
    static let aliceRedSurface = adaptive(light: "FBECEE", dark: "3A2530")
    // These panels always carry light text, independently of the app theme.
    static let aliceInk = Color(hex: "15233F")
    static let aliceSuccess = aliceRiskLow
    static let aliceError = aliceRiskHigh

    private static func adaptive(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #else
        // The macOS app-icon renderer always exports the light artwork.
        Color(hex: light)
        #endif
    }

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
