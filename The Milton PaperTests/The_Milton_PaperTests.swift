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


struct HomeModuleTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    // MARK: - Parsing console-typed documents

    @Test func parsesAWellFormedSpotlight() {
        let module = HomeModule(documentID: "senior", data: [
            "type": "spotlight", "title": "Maya Patel", "subtitle": "Senior of the Week",
            "body": "A sentence.", "order": 10, "enabled": true,
            "linkURL": "https://example.com/story",
        ])
        #expect(module?.kind == .spotlight)
        #expect(module?.title == "Maya Patel")
        #expect(module?.placement == .afterIssue)
        #expect(module?.destination == .web(URL(string: "https://example.com/story")!))
        #expect(module?.resolvedActionLabel == "Read more")
    }

    @Test func coercesValuesTypedAsTheWrongKind() {
        let module = HomeModule(documentID: "m", data: [
            "type": "  Spotlight ", "title": "  Title  ", "enabled": "true", "order": "20",
        ])
        #expect(module?.kind == .spotlight)
        #expect(module?.title == "Title")
        #expect(module?.isEnabled == true)
        #expect(module?.order == 20)
    }

    @Test func rejectsDocumentsThatCannotBeRendered() {
        #expect(HomeModule(documentID: "m", data: ["title": "No type"]) == nil)
        #expect(HomeModule(documentID: "m", data: ["type": "banner", "title": "Bad type"]) == nil)
        #expect(HomeModule(documentID: "m", data: ["type": "spotlight"]) == nil)
        #expect(HomeModule(documentID: "m", data: ["type": "spotlight", "title": "   "]) == nil)
    }

    @Test func unsafeDefaultsFailClosedAndUnknownFieldsAreIgnored() {
        let module = HomeModule(documentID: "m", data: [
            "type": "spotlight", "title": "Half built", "somethingElse": 42,
        ])
        // A document the editor saved and walked away from must not go live.
        #expect(module?.isEnabled == false)
        // Missing order sorts last rather than jumping the queue.
        #expect(module?.order == 1_000)
        #expect(module?.placement == .afterIssue)
    }

    @Test func typoedPlacementFallsBackToTheSafeSlot() {
        let module = HomeModule(documentID: "m", data: [
            "type": "spotlight", "title": "T", "placement": "bottom",
        ])
        #expect(module?.placement == .afterIssue)
    }

    @Test func onlyHTTPSchemesBecomeTappableDestinations() {
        for bad in ["javascript:alert(1)", "file:///etc/passwd", "not a url", "https://", "ftp://x.com"] {
            let module = HomeModule(documentID: "m", data: [
                "type": "spotlight", "title": "T", "linkURL": bad, "imageURL": bad,
            ])
            #expect(module?.linkURL == nil)
            #expect(module?.imageURL == nil)
            #expect(module?.destination == HomeModuleDestination.none)
        }
    }

    @Test func articleIDWinsOverLink() {
        let module = HomeModule(documentID: "m", data: [
            "type": "spotlight", "title": "T",
            "articleID": "article-1", "linkURL": "https://example.com",
        ])
        #expect(module?.destination == .article("article-1"))
    }

    @Test func datesParseFromEveryShapeAConsoleCanProduce() {
        let epoch = HomeModule(documentID: "m", data: [
            "type": "spotlight", "title": "T", "startsAt": 2_000_000_000 as NSNumber,
        ])
        #expect(epoch?.startsAt == now)

        let native = HomeModule(documentID: "m", data: [
            "type": "spotlight", "title": "T", "startsAt": now,
        ])
        #expect(native?.startsAt == now)

        let iso = HomeModule(documentID: "m", data: [
            "type": "spotlight", "title": "T", "startsAt": "2033-05-18T03:33:20Z",
        ])
        #expect(iso?.startsAt == now)
    }

    // MARK: - Visibility and ordering

    @Test func disabledAndOutOfWindowModulesAreHidden() {
        #expect(!spotlight("a", enabled: false).isVisible(at: now))
        #expect(spotlight("b").isVisible(at: now))
        #expect(!spotlight("c", startsAt: now.addingTimeInterval(60)).isVisible(at: now))
        #expect(!spotlight("d", endsAt: now.addingTimeInterval(-60)).isVisible(at: now))
    }

    @Test func theScheduleWindowIsHalfOpen() {
        // Starting exactly now counts as started; ending exactly now is over.
        #expect(spotlight("a", startsAt: now).isVisible(at: now))
        #expect(!spotlight("b", endsAt: now).isVisible(at: now))
    }

    @Test func modulesSortByOrderThenIDAndAreCapped() {
        let modules = [spotlight("c", order: 30), spotlight("a", order: 10), spotlight("b", order: 20)]
        #expect(HomeModuleFilter.visible(modules, at: now).map(\.id) == ["a", "b", "c"])

        let tied = [spotlight("z", order: 10), spotlight("y", order: 10)]
        let first = HomeModuleFilter.visible(tied, at: now).map(\.id)
        #expect(first == ["y", "z"])
        #expect(HomeModuleFilter.visible(tied, at: now).map(\.id) == first)

        let many = (0..<5).map { spotlight("m\($0)", order: Double($0)) }
        #expect(HomeModuleFilter.visible(many, at: now).map(\.id) == ["m0", "m1", "m2"])
    }

    @Test func emptyInputAndEmptyRailsProduceNothing() {
        #expect(HomeModuleFilter.visible([], at: now).isEmpty)
        #expect(!rail("r", items: []).isVisible(at: now))
        #expect(!rail("r", items: [HomeModuleItem(id: "i", title: "T", isEnabled: false)]).isVisible(at: now))
        #expect(rail("r", items: [HomeModuleItem(id: "i", title: "T")]).isVisible(at: now))
    }

    @Test func railItemsAreSortedFilteredAndCapped() {
        let items = (0..<20).map { HomeModuleItem(id: "i\($0)", title: "T\($0)", order: Double(20 - $0)) }
        let module = rail("r", items: items)
        #expect(module.renderableItems.count == HomeModuleFilter.maxItemsPerRail)
        #expect(module.renderableItems.first?.id == "i19")
    }

    @Test func railItemsDefaultToVisible() {
        // An editor who adds a card means to show it, so items fail open.
        let item = HomeModuleItem(documentID: "i", data: ["title": "Card"])
        #expect(item?.isEnabled == true)
        #expect(HomeModuleItem(documentID: "i", data: ["subtitle": "no title"]) == nil)
    }

    // MARK: - Helpers

    private func spotlight(_ id: String, order: Double = 10, enabled: Bool = true,
                           startsAt: Date? = nil, endsAt: Date? = nil) -> HomeModule {
        HomeModule(id: id, kind: .spotlight, title: "Module \(id)", order: order,
                   isEnabled: enabled, startsAt: startsAt, endsAt: endsAt)
    }

    private func rail(_ id: String, items: [HomeModuleItem]) -> HomeModule {
        HomeModule(id: id, kind: .rail, title: "Rail \(id)", order: 10, items: items)
    }
}
