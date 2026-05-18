import SwiftUI

extension Color {
    // Brand colors
    static let miltonPrimary    = Color(hex: "#1A2744") // Deep navy
    static let miltonAccent     = Color(hex: "#C9A84C") // Warm gold
    static let miltonBackground = Color(hex: "#FAFAF7") // Off-white
    static let miltonSurface    = Color.white
    static let miltonText       = Color(hex: "#1C1C1E")
    static let miltonSecondary  = Color(hex: "#6E6E73")

    // Category colors
    static let categoryNews     = Color(hex: "#2563EB")
    static let categoryOpinion  = Color(hex: "#7C3AED")
    static let categorySports   = Color(hex: "#059669")
    static let categoryArts     = Color(hex: "#DB2777")

    static func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "news":    return .categoryNews
        case "opinion": return .categoryOpinion
        case "sports":  return .categorySports
        case "arts":    return .categoryArts
        default:        return .miltonPrimary
        }
    }

    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
