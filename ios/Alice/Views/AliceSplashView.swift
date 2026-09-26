import SwiftUI

struct AliceSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.alicePrimary
                // Precise grid and blue bands echo the IBM design language.
                Path { path in
                    stride(from: CGFloat(0), through: geometry.size.width, by: 36).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    stride(from: CGFloat(0), through: geometry.size.height, by: 36).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }.stroke(.white.opacity(0.035), lineWidth: 1)
                VStack(spacing: 26) {
                    Spacer()
                    ZStack {
                        Circle().fill(Color.aliceAccent.opacity(0.3)).frame(width: 248, height: 248).blur(radius: 35)
                        Circle().stroke(Color(hex: "78A9FF").opacity(0.2), lineWidth: 1).frame(width: 260, height: 260)
                        AliceMascot(happy: true, animated: false).frame(width: 156, height: 188)
                            .offset(y: appeared || reduceMotion ? 0 : 12)
                    }
                    VStack(spacing: 10) {
                        Text("Alice").font(.plex(58, weight: .semibold)).tracking(-2)
                        Text("A LITTLE CLOSER TO BOB.").font(.plex(11, weight: .medium)).tracking(2.6)
                            .foregroundStyle(Color(hex: "A6C8FF"))
                    }
                    Spacer()
                    VStack(spacing: 14) {
                        HStack(spacing: 5) {
                            ForEach(0..<8) { index in
                                Rectangle().fill(Color(hex: "78A9FF").opacity(Double(index + 1) / 8))
                                    .frame(width: 5, height: 18)
                            }
                        }
                        Text("The mobile partner for IBM Bob").font(.plex(12)).foregroundStyle(.white.opacity(0.65))
                    }.padding(.bottom, 40)
                }.padding(24).frame(maxWidth: .infinity)
            }.foregroundStyle(.white)
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.55)) { appeared = true } }
        .accessibilityElement(children: .combine)
    }
}
