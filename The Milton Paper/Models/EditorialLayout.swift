import Foundation

enum AppTab: Hashable {
    case today
    case sections
    case tmplay
    case saved
    case you

    static func validSelection(_ selection: AppTab, flags: FeatureFlags) -> AppTab {
        selection == .tmplay && !flags.showTMPlay ? .today : selection
    }
}

struct SectionDescriptor: Identifiable, Hashable {
    enum Kind: Hashable {
        case issue
        case articles(category: String)
    }

    let id: String
    let title: String
    let kind: Kind

    static let issue = SectionDescriptor(id: "this-week", title: "This Week", kind: .issue)

    func isVisible(flags: FeatureFlags) -> Bool {
        switch kind {
        case .issue: return flags.showThisWeek
        case .articles(let category): return flags.showsFeedCategory(category)
        }
    }

    static func articles(_ category: String) -> SectionDescriptor {
        SectionDescriptor(
            id: "category-\(category.lowercased())",
            title: category,
            kind: .articles(category: category)
        )
    }

    static func available(flags: FeatureFlags, articles: [Article]) -> [SectionDescriptor] {
        var result: [SectionDescriptor] = []
        if flags.showThisWeek { result.append(.issue) }

        let categories = [
            "News",
            "Opinion",
            "Sports",
            Config.categoryArtsEntertainment,
            "Editorial",
            Config.categoryStudentReflections,
            Config.categoryFacultyFarewells,
        ]

        for category in categories where flags.showsFeedCategory(category) {
            let isTemporary = category == Config.categoryStudentReflections ||
                category == Config.categoryFacultyFarewells
            if !isTemporary || articles.contains(where: { $0.matches(category: category) }) {
                result.append(.articles(category))
            }
        }
        return result
    }
}

/// A deterministic, duplicate-free front page built from the RSS order.
/// The lead gives image-led journalism priority; everything after the top
/// stories runs in strict reverse-chronological order, so Today reads as a
/// latest-first feed rather than a set of category modules.
struct EditorialLayout: Equatable {
    let lead: Article?
    let secondary: [Article]
    let latest: [Article]

    init(articles: [Article], flags: FeatureFlags) {
        var seen = Set<String>()
        let visible = articles
            .filter { flags.showsFeedCategory($0.category) }
            .sorted {
                $0.publishedDate == $1.publishedDate
                    ? $0.id < $1.id : $0.publishedDate > $1.publishedDate
            }
            .filter { seen.insert($0.id).inserted }
        let specialNames = [Config.categoryStudentReflections, Config.categoryFacultyFarewells]
        let core = visible.filter { article in
            !specialNames.contains(where: { article.matches(category: $0) })
        }

        let selectedLead = core.first(where: { $0.thumbnailURL != nil }) ?? core.first ?? visible.first
        lead = selectedLead

        var assigned = Set<String>()
        if let selectedLead { assigned.insert(selectedLead.id) }

        secondary = Array(visible.filter { !assigned.contains($0.id) }.prefix(2))
        secondary.forEach { assigned.insert($0.id) }

        latest = visible.filter { !assigned.contains($0.id) }
    }
}

extension Article {
    func matches(category expected: String) -> Bool {
        Self.normalizedCategory(category) == Self.normalizedCategory(expected)
    }

    private static func normalizedCategory(_ value: String) -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["arts", "a&e", "arts & entertainment"].contains(value) ? "a&e" : value
    }
}
