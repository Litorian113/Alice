import SwiftUI

/// Bob's hard hat and laptop complement Alice's headset and phone.
struct BobMascot: View {
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("companionMotion") private var companionMotion = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !animated || reduceMotion || !companionMotion)) { timeline in
            let blink = animated && !reduceMotion && companionMotion
                && timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5.8) < 0.18
            Canvas { context, size in
                let scale = min(size.width / 240, size.height / 286)
                context.translateBy(x: (size.width - 240 * scale) / 2, y: (size.height - 286 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                drawBob(context: context, blink: blink)
            }
        }
        .accessibilityLabel("Bob holding his laptop")
        .accessibilityAddTraits(.isImage)
    }

    private func drawBob(context: GraphicsContext, blink: Bool) {
        let ink = Color(hex: "182544")
        let white = Color(hex: "F8FAFF")
        let shade = Color(hex: "D8E2F0")
        let blue = Color(hex: "2864F5")
        let outline = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)

        func shape(_ path: Path, _ color: Color) {
            context.fill(path, with: .color(color))
            context.stroke(path, with: .color(ink), style: outline)
        }
        func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: Color) {
            shape(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r), color)
        }
        func stroke(_ points: [CGPoint], color: Color = Color(hex: "182544"), width: CGFloat = 6) {
            var path = Path()
            path.addLines(points)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }

        // Small boots and sleeves retain the friendly silhouette from the reference.
        for x: CGFloat in [54, 132] {
            var boot = Path()
            boot.move(to: CGPoint(x: x, y: 281))
            boot.addCurve(to: CGPoint(x: x + 55, y: 281), control1: CGPoint(x: x + 3, y: 241), control2: CGPoint(x: x + 51, y: 241))
            boot.closeSubpath()
            shape(boot, blue)
        }
        rounded(44, 196, 29, 57, 14, shade)
        rounded(169, 196, 29, 57, 14, shade)
        rounded(79, 196, 83, 64, 24, white)

        // Face and ears, tucked under the hard hat.
        rounded(24, 118, 22, 35, 8, shade)
        rounded(194, 118, 22, 35, 8, shade)
        rounded(39, 86, 161, 97, 32, shade)
        context.fill(Path(roundedRect: CGRect(x: 49, y: 89, width: 143, height: 90), cornerRadius: 28), with: .color(white))

        var hat = Path()
        hat.move(to: CGPoint(x: 20, y: 98))
        hat.addCurve(to: CGPoint(x: 119, y: 15), control1: CGPoint(x: 24, y: 46), control2: CGPoint(x: 65, y: 14))
        hat.addCurve(to: CGPoint(x: 220, y: 98), control1: CGPoint(x: 176, y: 14), control2: CGPoint(x: 215, y: 45))
        hat.addCurve(to: CGPoint(x: 226, y: 119), control1: CGPoint(x: 240, y: 99), control2: CGPoint(x: 240, y: 117))
        hat.addLine(to: CGPoint(x: 14, y: 119))
        hat.addCurve(to: CGPoint(x: 20, y: 98), control1: CGPoint(x: 0, y: 117), control2: CGPoint(x: 0, y: 101))
        hat.closeSubpath()
        context.fill(hat, with: .linearGradient(Gradient(colors: [blue, Color(hex: "7549ED")]),
                                               startPoint: CGPoint(x: 45, y: 28), endPoint: CGPoint(x: 208, y: 120)))
        context.stroke(hat, with: .color(ink), style: outline)
        var ridge = Path()
        ridge.move(to: CGPoint(x: 96, y: 70))
        ridge.addLine(to: CGPoint(x: 96, y: 13))
        ridge.addQuadCurve(to: CGPoint(x: 104, y: 5), control: CGPoint(x: 96, y: 5))
        ridge.addLine(to: CGPoint(x: 139, y: 5))
        ridge.addQuadCurve(to: CGPoint(x: 147, y: 13), control: CGPoint(x: 147, y: 5))
        ridge.addLine(to: CGPoint(x: 147, y: 70))
        context.fill(ridge, with: .linearGradient(Gradient(colors: [blue, Color(hex: "5450F3")]),
                                                 startPoint: CGPoint(x: 100, y: 5), endPoint: CGPoint(x: 147, y: 73)))
        context.stroke(ridge, with: .color(ink), style: outline)
        var brim = Path()
        brim.move(to: CGPoint(x: 42, y: 95))
        brim.addQuadCurve(to: CGPoint(x: 198, y: 95), control: CGPoint(x: 120, y: 83))
        context.stroke(brim, with: .color(ink), style: outline)

        for x: CGFloat in [83, 157] {
            if blink {
                stroke([CGPoint(x: x - 10, y: 142), CGPoint(x: x + 10, y: 142)], width: 5)
            } else {
                context.fill(Path(ellipseIn: CGRect(x: x - 13, y: 129, width: 29, height: 30)), with: .color(ink))
                context.fill(Path(ellipseIn: CGRect(x: x + 3, y: 134, width: 8, height: 8)), with: .color(.white))
            }
        }
        var smile = Path()
        smile.move(to: CGPoint(x: 102, y: 167))
        smile.addQuadCurve(to: CGPoint(x: 138, y: 167), control: CGPoint(x: 120, y: 181))
        context.stroke(smile, with: .color(ink), style: outline)

        // Laptop lid faces the viewer; his hands grip its lower corners.
        rounded(60, 204, 130, 49, 7, Color(hex: "293C61"))
        stroke([CGPoint(x: 110, y: 219), CGPoint(x: 102, y: 226), CGPoint(x: 110, y: 233)], color: Color(hex: "85B6FF"), width: 4)
        stroke([CGPoint(x: 136, y: 219), CGPoint(x: 144, y: 226), CGPoint(x: 136, y: 233)], color: Color(hex: "85B6FF"), width: 4)
        stroke([CGPoint(x: 127, y: 216), CGPoint(x: 119, y: 236)], color: Color(hex: "85B6FF"), width: 4)
        rounded(53, 250, 144, 10, 5, shade)
        rounded(38, 237, 30, 20, 10, white)
        rounded(183, 237, 25, 20, 10, white)
    }
}

/// A shared illustration, not a connection-status indicator. Bob works on the
/// laptop; Alice receives his question on her phone. No extra image assets.
struct AliceBobScene: View {
    var asking = false
    var greeting = false
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("companionMotion") private var companionMotion = true
    @State private var started = Date()

    private var moves: Bool { animated && !reduceMotion && companionMotion }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 360, geometry.size.height / 240)
            ZStack(alignment: .topLeading) {
                BobMascot(animated: animated)
                    .frame(width: 164, height: 196)
                    .offset(x: 9, y: 22)
                AliceMascot(animated: animated, greeting: greeting, grounded: true)
                    .frame(width: 164, height: 196)
                    .offset(x: 188, y: 22)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moves)) { timeline in
                    Canvas { context, _ in
                        var cable = Path()
                        cable.move(to: CGPoint(x: 140, y: 190))
                        cable.addCurve(to: CGPoint(x: 214, y: 190), control1: CGPoint(x: 157, y: 229), control2: CGPoint(x: 200, y: 229))
                        context.stroke(cable, with: .color(Color(hex: "7860E8")), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        if moves {
                            let t = CGFloat(max(0, timeline.date.timeIntervalSince(started)).truncatingRemainder(dividingBy: 2.4) / 2.4)
                            let u = 1 - t
                            let x = u*u*u*140 + 3*u*u*t*157 + 3*u*t*t*200 + t*t*t*214
                            let y = u*u*u*190 + 3*u*u*t*229 + 3*u*t*t*229 + t*t*t*190
                            context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(Color(hex: "85E3DB")))
                        }
                        // Alice holds the phone in her left hand, connected to Bob's laptop.
                        let phone = Path(roundedRect: CGRect(x: 204, y: 162, width: 24, height: 38), cornerRadius: 6)
                        context.fill(phone, with: .color(Color(hex: "C8F4EE")))
                        context.stroke(phone, with: .color(Color(hex: "182544")), lineWidth: 3)
                        let speaker = Path(roundedRect: CGRect(x: 212, y: 166, width: 8, height: 2), cornerRadius: 1)
                        context.fill(speaker, with: .color(Color(hex: "182544")))
                        let home = Path(roundedRect: CGRect(x: 213, y: 194, width: 6, height: 2), cornerRadius: 1)
                        context.fill(home, with: .color(Color(hex: "7860E8")))
                    }
                }
                if asking {
                    ZStack {
                        UnevenRoundedRectangle(topLeadingRadius: 15, bottomLeadingRadius: 3, bottomTrailingRadius: 15, topTrailingRadius: 15)
                            .fill(Color.aliceSurface)
                            .overlay {
                                UnevenRoundedRectangle(topLeadingRadius: 15, bottomLeadingRadius: 3, bottomTrailingRadius: 15, topTrailingRadius: 15)
                                    .strokeBorder(Color(hex: "7860E8").opacity(0.25), lineWidth: 1.5)
                            }
                        Text("?").font(.system(size: 25, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "7860E8"))
                    }
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(8))
                    .offset(x: 163, y: 62)
                }
            }
            .frame(width: 360, height: 240)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: 360 * scale, height: 240 * scale, alignment: .topLeading)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .onAppear { started = Date() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(asking ? "Bob asks Alice for your decision" : "Bob and Alice, connected from laptop to phone")
        .accessibilityAddTraits(.isImage)
    }
}
