import SwiftUI

struct AliceSplashView: View {
    var body: some View {
        SplashPartners()
        .frame(maxWidth: 360)
        .frame(height: 330)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            Text("The mobile partner for IBM Bob")
                .font(.plex(12))
                .foregroundStyle(Color(hex: "65718A"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(Color(hex: "F5F7FC").ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .combine)
    }
}

/// Splash-specific staging: Alice leads on the left, Bob sits a little farther
/// back. The decision-screen composition lives separately in AliceBobScene.
private struct SplashPartners: View {
    @AppStorage("alicePalette") private var paletteID = AlicePalette.violet.rawValue

    private var colors: AlicePalette.Colors { (AlicePalette(rawValue: paletteID) ?? .violet).colors }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 360, geometry.size.height / 330)
            ZStack(alignment: .topLeading) {
                BobMascot()
                    .frame(width: 152, height: 182)
                    .offset(x: 204, y: 48)

                AliceMascot(greeting: true, grounded: true)
                    .frame(width: 206, height: 246)
                    .offset(x: 2, y: 16)

                // Alice's phone stays in her left hand while her right hand waves.
                RoundedRectangle(cornerRadius: 7)
                    .fill(colors.accessory)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "182544"), lineWidth: 3))
                    .overlay(alignment: .top) {
                        Capsule().fill(Color(hex: "182544")).frame(width: 9, height: 2).padding(.top, 5)
                    }
                    .overlay(alignment: .bottom) {
                        Capsule().fill(colors.accent).frame(width: 7, height: 2).padding(.bottom, 5)
                    }
                    .frame(width: 28, height: 44)
                    .offset(x: 20, y: 206)

                Text("Alice")
                    .font(.plex(40, weight: .semibold)).tracking(-1.2)
                    .foregroundStyle(Color(hex: "15233F"))
                    .frame(width: 206)
                    .offset(x: 2, y: 282)
                Text("Bob")
                    .font(.plex(29, weight: .medium)).tracking(-0.6)
                    .foregroundStyle(Color(hex: "65718A"))
                    .frame(width: 152)
                    .offset(x: 204, y: 254)
            }
            .frame(width: 360, height: 330, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: 360 * scale, height: 330 * scale, alignment: .topLeading)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alice with her phone and Bob with his laptop")
    }
}
