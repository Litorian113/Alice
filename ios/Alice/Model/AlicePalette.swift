import SwiftUI

/// Shared by every live Alice illustration. The launcher icon stays a bundled asset.
enum AlicePalette: String, CaseIterable, Identifiable {
    case violet, ocean, mint, sunset, rose, graphite

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    struct Colors {
        let start, end, accent, shell, accessory, highlight, blush: Color

        init(_ start: String, _ end: String, _ accent: String, _ shell: String,
             _ accessory: String, _ highlight: String, _ blush: String) {
            self.start = Color(hex: start)
            self.end = Color(hex: end)
            self.accent = Color(hex: accent)
            self.shell = Color(hex: shell)
            self.accessory = Color(hex: accessory)
            self.highlight = Color(hex: highlight)
            self.blush = Color(hex: blush)
        }
    }

    var colors: Colors {
        switch self {
        case .violet: return Colors("536EF0", "AA74F0", "7860E8", "6652C8", "85E3DB", "C4C3FF", "D5C8FA")
        case .ocean: return Colors("2476E8", "60CBE8", "327DC7", "275A9D", "B0E9F3", "B9ECFF", "C0DDF4")
        case .mint: return Colors("209A88", "8ADAA8", "2B9D83", "257664", "F3DE99", "C4F3DC", "B9E8D5")
        case .sunset: return Colors("E9894A", "EB7B9F", "D67754", "A85948", "FFE0A1", "FFE1C7", "F5D2CB")
        case .rose: return Colors("C96099", "EFA9D6", "BD6199", "924C7C", "B8DDF5", "FFD5EB", "F1D0E3")
        case .graphite: return Colors("596882", "9BA8BE", "64738C", "46546D", "A9E4DE", "D5DFED", "D2DCE9")
        }
    }
}
