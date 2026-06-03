import SwiftUI
import UIKit

extension Color {
    // Brand colors — all adaptive for light / dark mode
    static let miltonPrimary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.294, green: 0.506, blue: 0.800, alpha: 1) // #4B81CC lighter navy
            : UIColor(red: 0.102, green: 0.153, blue: 0.267, alpha: 1) // #1A2744 deep navy
    })
    static let miltonAccent     = Color(hex: "#C9A84C") // Warm gold — works on both backgrounds
    static let miltonBackground = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1) // #1C1C1E
            : UIColor(red: 0.980, green: 0.980, blue: 0.969, alpha: 1) // #FAFAF7
    })
    static let miltonSurface = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1) // #2C2C2E
            : UIColor.white
    })
    static let miltonText = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1) // #F2F2F7
            : UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1) // #1C1C1E
    })
    static let miltonSecondary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1) // #8E8E93
            : UIColor(red: 0.431, green: 0.431, blue: 0.451, alpha: 1) // #6E6E73
    })

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
