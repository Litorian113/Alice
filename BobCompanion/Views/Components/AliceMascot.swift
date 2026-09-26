import SwiftUI

/// Alice shares Bob's robot design language, with a swept violet shell and a headset.
/// Native vector artwork stays crisp in the conversation, navigation and app icon.
struct AliceMascot: View {
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
                drawAlice(context: context, blink: blink)
            }
            .offset(y: shouldAnimate && !faceOnly ? sin(time * 1.8) * 3 : 0)
        }
        .accessibilityLabel(happy ? "Alice is happy" : "Alice, your companion for Bob")
        .accessibilityAddTraits(.isImage)
    }

    private func drawAlice(context: GraphicsContext, blink: Bool) {
        let ink = Color(hex: "182544")
        let white = Color(hex: "F8FAFF")
        let shade = Color(hex: "D8E2F0")
        let violet = Color(hex: "7860E8")
        let mint = Color(hex: "85E3DB")
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
            round(47, 198, 26, 57, 13, violet)
            round(168, 198, 26, 57, 13, violet)
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
            // A small geometric A badge, so her full-body silhouette has its own identity.
            stroke([CGPoint(x: 107,y: 235), CGPoint(x: 120,y: 211), CGPoint(x: 133,y: 235)], color: violet, width: 5)
            stroke([CGPoint(x: 112,y: 227), CGPoint(x: 128,y: 227)], color: violet, width: 4)
            for x: CGFloat in [54, 131] {
                var foot = Path()
                foot.move(to: CGPoint(x: x, y: 282))
                foot.addCurve(to: CGPoint(x: x + 56, y: 282), control1: CGPoint(x: x + 4, y: 242), control2: CGPoint(x: x + 51, y: 242))
                foot.closeSubpath()
                shape(foot, violet)
            }
        }

        // The rounded shell forms a bob haircut behind the face.
        var shell = Path()
        shell.move(to: CGPoint(x: 32, y: 145))
        shell.addLine(to: CGPoint(x: 31, y: 80))
        shell.addCurve(to: CGPoint(x: 117, y: 9), control1: CGPoint(x: 30, y: 29), control2: CGPoint(x: 64, y: 5))
        shell.addCurve(to: CGPoint(x: 208, y: 80), control1: CGPoint(x: 173, y: 2), control2: CGPoint(x: 209, y: 31))
        shell.addLine(to: CGPoint(x: 210, y: 151))
        shell.addQuadCurve(to: CGPoint(x: 180, y: 169), control: CGPoint(x: 211, y: 174))
        shell.addLine(to: CGPoint(x: 62, y: 169))
        shell.addQuadCurve(to: CGPoint(x: 32, y: 145), control: CGPoint(x: 29, y: 173))
        shape(shell, Color(hex: "6652C8"))

        round(39, 80, 161, 102, 32, shade)
        context.fill(Path(roundedRect: CGRect(x: 50, y: 86, width: 141, height: 92), cornerRadius: 27), with: .color(white))

        // Swept fringe: a different silhouette from Bob's hard hat, using the same bold outlines.
        var fringe = Path()
        fringe.move(to: CGPoint(x: 31, y: 110))
        fringe.addLine(to: CGPoint(x: 31, y: 79))
        fringe.addCurve(to: CGPoint(x: 114, y: 9), control1: CGPoint(x: 30, y: 28), control2: CGPoint(x: 66, y: 5))
        fringe.addCurve(to: CGPoint(x: 207, y: 77), control1: CGPoint(x: 170, y: 1), control2: CGPoint(x: 205, y: 30))
        fringe.addLine(to: CGPoint(x: 209, y: 113))
        fringe.addQuadCurve(to: CGPoint(x: 170, y: 64), control: CGPoint(x: 179, y: 102))
        fringe.addCurve(to: CGPoint(x: 31, y: 110), control1: CGPoint(x: 140, y: 98), control2: CGPoint(x: 78, y: 113))
        fringe.closeSubpath()
        context.fill(fringe, with: .linearGradient(
            Gradient(colors: [Color(hex: "536EF0"), Color(hex: "AA74F0")]),
            startPoint: CGPoint(x: 38, y: 18), endPoint: CGPoint(x: 207, y: 120)))
        context.stroke(fringe, with: .color(ink), style: line)

        var sweep = Path()
        sweep.move(to: CGPoint(x: 56, y: 80))
        sweep.addQuadCurve(to: CGPoint(x: 147, y: 43), control: CGPoint(x: 112, y: 78))
        context.stroke(sweep, with: .color(Color(hex: "C4C3FF")),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // A // hair clip nods to code; the headset makes her role as the companion visible.
        for x: CGFloat in [170, 183] {
            stroke([CGPoint(x: x, y: 42), CGPoint(x: x - 7, y: 57)], color: ink, width: 10)
            stroke([CGPoint(x: x, y: 42), CGPoint(x: x - 7, y: 57)], color: mint, width: 5)
        }
        round(23, 118, 22, 32, 9, mint)
        round(195, 118, 22, 32, 9, mint)
        var microphone = Path()
        microphone.move(to: CGPoint(x: 208, y: 148))
        microphone.addQuadCurve(to: CGPoint(x: 177, y: 164), control: CGPoint(x: 208, y: 166))
        context.stroke(microphone, with: .color(ink), style: line)
        round(166, 159, 17, 10, 5, mint)

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
