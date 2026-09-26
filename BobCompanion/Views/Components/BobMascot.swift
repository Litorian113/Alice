import SwiftUI

/// Native vector artwork: face, helmet and body remain crisp at every size.
struct BobMascot: View {
    var faceOnly = false
    var happy = false
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("companionMotion") private var companionMotion = true

    private var shouldAnimate: Bool { animated && !reduceMotion && companionMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: !shouldAnimate)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let blink = shouldAnimate && time.truncatingRemainder(dividingBy: 5.4) < 0.16
            Canvas { context, size in
                let base = CGSize(width: 240, height: faceOnly ? 184 : 286)
                let scale = min(size.width / base.width, size.height / base.height)
                context.translateBy(x: (size.width - base.width * scale) / 2,
                                    y: (size.height - base.height * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                drawBob(context: context, blink: blink)
            }
            .offset(y: shouldAnimate && !faceOnly ? sin(time * 1.8) * 3 : 0)
        }
        .accessibilityLabel(happy ? "Bob is happy" : "Bob, your coding companion")
        .accessibilityAddTraits(.isImage)
    }

    private func drawBob(context: GraphicsContext, blink: Bool) {
        let ink = Color(hex: "182544")
        let white = Color(hex: "F8FAFF")
        let shade = Color(hex: "D8E2F0")
        let line = StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)

        func shape(_ path: Path, _ color: Color) {
            context.fill(path, with: .color(color))
            context.stroke(path, with: .color(ink), style: line)
        }
        func round(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: Color) {
            shape(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r), color)
        }
        func stroke(_ points: [CGPoint], color: Color = Color(hex: "182544"), width: CGFloat = 6) {
            var path = Path()
            path.addLines(points)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }

        if !faceOnly {
            // Arms and little boots.
            round(47, 198, 26, 57, 13, shade)
            round(168, 198, 26, 57, 13, shade)
            var leftHand = Path()
            leftHand.move(to: CGPoint(x: 33, y: 257))
            leftHand.addQuadCurve(to: CGPoint(x: 81, y: 257), control: CGPoint(x: 54, y: 211))
            leftHand.closeSubpath()
            shape(leftHand, white)
            var rightHand = Path()
            rightHand.move(to: CGPoint(x: 158, y: 257))
            rightHand.addQuadCurve(to: CGPoint(x: 208, y: 257), control: CGPoint(x: 183, y: 211))
            rightHand.closeSubpath()
            shape(rightHand, white)
            var body = Path()
            body.move(to: CGPoint(x: 84, y: 199))
            body.addLine(to: CGPoint(x: 156, y: 199))
            body.addLine(to: CGPoint(x: 156, y: 228))
            body.addCurve(to: CGPoint(x: 84, y: 228), control1: CGPoint(x: 153, y: 266), control2: CGPoint(x: 88, y: 266))
            body.closeSubpath()
            shape(body, white)
            stroke([CGPoint(x: 105,y: 216), CGPoint(x: 96,y: 225), CGPoint(x: 105,y: 233)], color: .bcAccent, width: 4)
            stroke([CGPoint(x: 126,y: 212), CGPoint(x: 115,y: 237)], color: .bcAccent, width: 4)
            stroke([CGPoint(x: 136,y: 216), CGPoint(x: 145,y: 225), CGPoint(x: 136,y: 233)], color: .bcAccent, width: 4)
            for x: CGFloat in [54, 131] {
                var foot = Path()
                foot.move(to: CGPoint(x: x, y: 282))
                foot.addCurve(to: CGPoint(x: x + 56, y: 282), control1: CGPoint(x: x + 4, y: 242), control2: CGPoint(x: x + 51, y: 242))
                foot.closeSubpath()
                shape(foot, .bcAccent)
            }
        }

        round(25, 113, 18, 34, 6, shade)
        round(196, 113, 18, 34, 6, shade)
        round(39, 80, 161, 102, 32, shade)
        context.fill(Path(roundedRect: CGRect(x: 50, y: 86, width: 141, height: 92), cornerRadius: 27), with: .color(white))

        // The blue-to-violet hard hat from Bob's reference artwork.
        var hat = Path()
        hat.move(to: CGPoint(x: 21, y: 99))
        hat.addQuadCurve(to: CGPoint(x: 36, y: 88), control: CGPoint(x: 18, y: 92))
        hat.addCurve(to: CGPoint(x: 203, y: 88), control1: CGPoint(x: 40, y: -9), control2: CGPoint(x: 192, y: -9))
        hat.addQuadCurve(to: CGPoint(x: 221, y: 99), control: CGPoint(x: 222, y: 93))
        hat.addQuadCurve(to: CGPoint(x: 213, y: 107), control: CGPoint(x: 224, y: 107))
        hat.addLine(to: CGPoint(x: 28, y: 107))
        hat.addQuadCurve(to: CGPoint(x: 21, y: 99), control: CGPoint(x: 20, y: 106))
        context.fill(hat, with: .linearGradient(Gradient(colors: [.bcAccent, Color(hex: "8052F3")]), startPoint: .zero, endPoint: CGPoint(x: 220, y: 95)))
        context.stroke(hat, with: .color(ink), style: line)
        var ridge = Path()
        ridge.move(to: CGPoint(x: 97, y: 59))
        ridge.addLine(to: CGPoint(x: 97, y: 13))
        ridge.addQuadCurve(to: CGPoint(x: 105, y: 6), control: CGPoint(x: 97, y: 6))
        ridge.addLine(to: CGPoint(x: 134, y: 6))
        ridge.addQuadCurve(to: CGPoint(x: 142, y: 13), control: CGPoint(x: 142, y: 6))
        ridge.addLine(to: CGPoint(x: 142, y: 59))
        context.fill(ridge, with: .color(Color(hex: "367BFF")))
        context.stroke(ridge, with: .color(ink), style: line)
        var brim = Path()
        brim.move(to: CGPoint(x: 58, y: 85))
        brim.addQuadCurve(to: CGPoint(x: 182, y: 85), control: CGPoint(x: 120, y: 74))
        context.stroke(brim, with: .color(ink), style: line)

        for x: CGFloat in [83, 157] {
            if blink || happy {
                var eye = Path()
                eye.move(to: CGPoint(x: x - 11, y: 137))
                eye.addQuadCurve(to: CGPoint(x: x + 11, y: 137), control: CGPoint(x: x, y: happy ? 119 : 137))
                context.stroke(eye, with: .color(ink), style: line)
            } else {
                context.fill(Path(ellipseIn: CGRect(x: x - 15, y: 119, width: 30, height: 33)), with: .color(ink))
                context.fill(Path(ellipseIn: CGRect(x: x + 1, y: 124, width: 8, height: 8)), with: .color(.white))
            }
        }
        var smile = Path()
        smile.move(to: CGPoint(x: 102, y: 161))
        smile.addQuadCurve(to: CGPoint(x: 137, y: 161), control: CGPoint(x: 120, y: happy ? 177 : 170))
        context.stroke(smile, with: .color(ink), style: line)
        for x: CGFloat in [58, 171] {
            context.fill(Path(ellipseIn: CGRect(x: x, y: 150, width: 14, height: 7)), with: .color(Color(hex: "D5C8FA")))
        }
    }
}
