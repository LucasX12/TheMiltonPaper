import Foundation
import Testing
@testable import The_Milton_Paper

struct EditorialLayoutTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test func imageStoryBecomesLeadEvenWhenANewerTextStoryExists() {
        let newestText = article("newest", category: "News", age: 0)
        let imageStory = article("image", category: "Opinion", age: 1, hasImage: true)
        let layout = EditorialLayout(articles: [newestText, imageStory], flags: FeatureFlags())
        #expect(layout.lead?.id == "image")
        #expect(layout.secondary.map(\.id) == ["newest"])
    }

    @Test func newestStoryIsLeadWhenThereAreNoImages() {
        let newest = article("newest", category: "News", age: 0)
        let older = article("older", category: "Sports", age: 2)
        let layout = EditorialLayout(articles: [older, newest], flags: FeatureFlags())
        #expect(layout.lead?.id == "newest")
    }

    @Test func everyStoryIsPlacedAtMostOnce() {
        let categories = ["News", "Opinion", "Sports", "A&E", "Editorial"]
        let stories = (0..<14).map { index in
            article("story-\(index)", category: categories[index % categories.count], age: index, hasImage: index == 3)
        }
        let layout = EditorialLayout(articles: stories, flags: FeatureFlags())
        let ids = [layout.lead].compactMap { $0?.id }
            + layout.secondary.map(\.id)
            + layout.latest.map(\.id)
        #expect(ids.count == Set(ids).count)
        #expect(Set(ids) == Set(stories.map(\.id)))
    }

    @Test func hiddenAndEmptyTemporarySectionsAreOmitted() {
        var flags = FeatureFlags()
        flags.showSports = false
        let stories = [
            article("news", category: "News", age: 0),
            article("sports", category: "Sports", age: 1),
        ]
        let layout = EditorialLayout(articles: stories, flags: flags)
        let sections = SectionDescriptor.available(flags: flags, articles: stories)
        #expect(layout.lead?.id == "news")
        #expect(!layout.latest.contains { $0.id == "sports" })
        #expect(!sections.contains { $0.title == "Sports" })
        #expect(!sections.contains { $0.title == Config.categoryStudentReflections })
    }

    @Test func emptyAndUndersizedFeedsRemainValid() {
        let empty = EditorialLayout(articles: [], flags: FeatureFlags())
        #expect(empty.lead == nil)
        #expect(empty.secondary.isEmpty)

        let one = EditorialLayout(articles: [article("only", category: "News", age: 0)], flags: FeatureFlags())
        #expect(one.lead?.id == "only")
        #expect(one.secondary.isEmpty)
        #expect(one.latest.isEmpty)
    }

    @Test func hiddenTMPlaySelectionFallsBackToToday() {
        var flags = FeatureFlags()
        flags.showTMPlay = false
        #expect(AppTab.validSelection(.tmplay, flags: flags) == .today)
        #expect(AppTab.validSelection(.saved, flags: flags) == .saved)
    }

    @Test func repeatedFeedEntriesAreDeduplicatedAndTiesAreStable() {
        let a = article("a", category: "News", age: 0)
        let b = article("b", category: "News", age: 0)
        let layout = EditorialLayout(articles: [b, a, b, a], flags: FeatureFlags())
        #expect(layout.lead?.id == "a")
        #expect(layout.secondary.map(\.id) == ["b"])
        #expect(layout.latest.isEmpty)
    }

    @Test func secondaryStoriesUseNextUnassignedStoriesIncludingSpecials() {
        let stories = [article("core", category: "News", age: 2, hasImage: true),
                       article("reflection", category: Config.categoryStudentReflections, age: 0),
                       article("opinion", category: "Opinion", age: 1)]
        let layout = EditorialLayout(articles: stories, flags: FeatureFlags())
        #expect(layout.lead?.id == "core")
        #expect(layout.secondary.map(\.id) == ["reflection", "opinion"])
    }

    @Test func remainingStoriesRunChronologicallyInLatest() {
        let stories = (0..<9).map { article("n\($0)", category: "News", age: $0) }
        let layout = EditorialLayout(articles: Array(stories.reversed()), flags: FeatureFlags())
        #expect(layout.lead?.id == "n0")
        #expect(layout.secondary.map(\.id) == ["n1", "n2"])
        #expect(layout.latest.map(\.id) == ["n3", "n4", "n5", "n6", "n7", "n8"])
    }

    @Test func hiddenDestinationsAndTemporaryStoriesDisappear() {
        var flags = FeatureFlags()
        flags.showSports = false
        flags.showThisWeek = false
        flags.showStudentReflections = false
        flags.showFacultyFarewells = false
        #expect(!SectionDescriptor.articles("Sports").isVisible(flags: flags))
        #expect(!SectionDescriptor.issue.isVisible(flags: flags))
        let stories = [article("r", category: Config.categoryStudentReflections, age: 0),
                       article("f", category: Config.categoryFacultyFarewells, age: 0)]
        #expect(EditorialLayout(articles: stories, flags: flags).lead == nil)
        #expect(!SectionDescriptor.available(flags: flags, articles: stories).contains(.issue))
    }

    @Test func artsAliasesShareASectionAndVisibilityFlag() {
        let arts = article("arts", category: "Arts & Entertainment", age: 0)
        #expect(arts.matches(category: "A&E"))
        var flags = FeatureFlags()
        flags.showArtsEntertainment = false
        #expect(EditorialLayout(articles: [arts], flags: flags).lead == nil)
    }

    private func article(_ id: String, category: String, age: Int, hasImage: Bool = false) -> Article {
        Article(
            id: id,
            title: "Story \(id)",
            author: "Milton Reporter",
            publishedDate: now.addingTimeInterval(Double(-age * 60)),
            category: category,
            summary: "A specific summary for \(id).",
            bodyHTML: "<p>Story body.</p>",
            articleURL: URL(string: "https://example.com/\(id)")!,
            thumbnailURL: hasImage ? URL(string: "https://example.com/\(id).jpg") : nil
        )
    }
}
