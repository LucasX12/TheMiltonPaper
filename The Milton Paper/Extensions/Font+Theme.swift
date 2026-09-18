import SwiftUI

extension Font {
    static let miltonDisplay      = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let miltonHeadline     = Font.system(.title, design: .serif, weight: .bold)
    static let miltonSectionTitle = Font.system(.title2, design: .serif, weight: .bold)
    static let miltonTitle        = Font.system(.title3, design: .serif, weight: .semibold)
    static let miltonStoryTitle   = Font.system(.headline, design: .serif, weight: .semibold)
    static let miltonBody         = Font.system(.body, design: .serif)
    static let miltonCaption      = Font.system(.caption, design: .default)
    static let miltonLabel        = Font.system(.caption2, design: .default, weight: .semibold).smallCaps()

    // Editorial surfaces (Today, Sections, Search, Saved, reader) set every
    // piece of text in serif. The sans faces above stay for app chrome:
    // the tab bar, settings, authentication, and TMPlay.
    static let miltonEyebrow      = Font.system(.caption2, design: .serif, weight: .semibold).smallCaps()
    static let miltonMeta         = Font.system(.caption, design: .serif)
}
