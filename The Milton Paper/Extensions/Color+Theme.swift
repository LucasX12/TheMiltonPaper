import SwiftUI

extension Color {
    // Editorial palette: content is black-on-white, with Milton navy reserved
    // for navigation and interactive emphasis.
    static let miltonPrimary    = Color(hex: "#0B2341")
    static let miltonAccent     = Color(hex: "#0B2341")
    static let miltonBackground = Color(hex: "#FFFFFF")
    static let miltonSurface    = Color(hex: "#FFFFFF")
    static let miltonText       = Color(hex: "#121212")
    static let miltonSecondary  = Color(hex: "#666666")
    static let miltonRule       = Color(hex: "#E2E2E2")

    // Category labels stay monochrome; hierarchy comes from typography.
    static let categoryNews     = miltonText
    static let categoryOpinion  = miltonText
    static let categorySports   = miltonText
    static let categoryArts     = miltonText

    static func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "news":    return .categoryNews
        case "opinion": return .categoryOpinion
        case "sports":  return .categorySports
        case "arts", "a&e", "arts & entertainment": return .categoryArts
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
