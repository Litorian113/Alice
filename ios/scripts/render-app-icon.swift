import AppKit
import SwiftUI

// Compile alongside AliceMascot.swift, AliceTheme.swift and DecisionCard.swift.
// Uses the exact face from the instruction sheet, with animation disabled.
@main
struct RenderAppIcon {
    @MainActor
    static func main() throws {
        let artwork = ZStack {
            Color.aliceBackground
            AliceMascot(faceOnly: true, animated: false)
                .frame(width: 920, height: 920 * 184 / 240)
        }
        .frame(width: 1024, height: 1024)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: artwork)
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.cgImage else {
            throw NSError(domain: "RenderAppIcon", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't render Alice's face."])
        }

        // Flatten to RGB so the app icon has no alpha channel.
        let context = CGContext(data: nil, width: 1024, height: 1024,
                                bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)

        let destination = CommandLine.arguments.dropFirst().first
            ?? "Alice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "RenderAppIcon", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't encode the icon."])
        }
        try png.write(to: URL(fileURLWithPath: destination))
        print("Saved \(destination)")
    }
}
