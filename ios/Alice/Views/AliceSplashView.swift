import SwiftUI

struct AliceSplashView: View {
    var body: some View {
        VStack(spacing: 18) {
            AliceBobScene(greeting: true)
                .frame(maxWidth: 340)
                .frame(height: 230)
                .padding(.horizontal, 20)
                .accessibilityHidden(true)
            Text("Alice")
                .font(.plex(52, weight: .semibold)).tracking(-1.8)
                .foregroundStyle(Color(hex: "15233F"))
        }
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
