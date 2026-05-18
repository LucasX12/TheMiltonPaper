import SwiftUI

extension Font {
    static let miltonHeadline = Font.custom("Georgia", size: 28).weight(.bold)
    static let miltonTitle    = Font.custom("Georgia", size: 20).weight(.semibold)
    static let miltonBody     = Font.system(size: 16, weight: .regular, design: .serif)
    static let miltonCaption  = Font.system(size: 13, weight: .regular, design: .default)
    static let miltonLabel    = Font.system(size: 11, weight: .medium, design: .default).smallCaps()
}
