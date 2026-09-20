import SwiftUI

/// Colour for the TMPlay games only. The editorial palette in Color+Theme
/// stays monochrome plus navy, and the games are the one place the design
/// allows colour, so these live apart from it.
enum TMPlayPalette {
    // Wordle's existing values, named. WordleView still holds them as literals
    // in two places; it is left alone here and can adopt these whenever it is
    // next edited.
    static let correct = Color(hex: "#538d4e")
    static let present = Color(hex: "#b59f3b")
    static let absent  = Color(hex: "#3a3a3c")

    // Connections difficulty bands, easiest to hardest. Our own muted tones
    // rather than another paper's exact values.
    static let level1 = Color(hex: "#F2D16B")
    static let level2 = Color(hex: "#9FBF6E")
    static let level3 = Color(hex: "#7FA8D0")
    static let level4 = Color(hex: "#B49BD1")

    static let tileIdle = Color(hex: "#EFEFEA")

    /// All four fills are pale enough for near-black label text.
    static func level(_ level: Int) -> Color {
        switch min(max(level, 1), 4) {
        case 1:  return level1
        case 2:  return level2
        case 3:  return level3
        default: return level4
        }
    }
}
