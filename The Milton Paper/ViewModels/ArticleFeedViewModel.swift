import Foundation
import Combine

@MainActor
final class ArticleFeedViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var filteredArticles: [Article] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""

    // Temporary sections (Student Reflections, Faculty Farewells) are inserted
    // after Recent only while their feeds still return articles, so the tabs
    // retire themselves when the site takes the sections down.
    @Published private(set) var categories = ["This Week", "TMPlay", "Recent",
                                              "News", "Opinion", "Sports", "A&E", "Editorial"]

    private let service = ArticleService.shared
    private let appConfiguration = AppConfiguration.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.applyFilter() }
            .store(in: &cancellables)

        appConfiguration.$flags
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateCategories()
                self?.applyFilter()
            }
            .store(in: &cancellables)
    }

    func loadArticles() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await service.fetchArticles()
            articles = await applyingBookmarks(to: fetched)
            updateCategories()
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        errorMessage = nil
        do {
            let fetched = try await service.fetchArticles(forceRefresh: true)
            articles = await applyingBookmarks(to: fetched)
            updateCategories()
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Updates a single article's bookmark flag in place, preserving the
    /// current search/category/date filtering.
    func setBookmarked(id: String, _ isBookmarked: Bool) {
        if let index = articles.firstIndex(where: { $0.id == id }) {
            articles[index].isBookmarked = isBookmarked
        }
        if let index = filteredArticles.firstIndex(where: { $0.id == id }) {
            filteredArticles[index].isBookmarked = isBookmarked
        }
    }

    // MARK: - Private

    private func updateCategories() {
        let flags = appConfiguration.flags
        var list: [String] = []
        if flags.showThisWeek { list.append("This Week") }
        if flags.showTMPlay { list.append("TMPlay") }
        list.append("Recent")
        if flags.showStudentReflections,
           hasArticles(in: Config.categoryStudentReflections) {
            list.append(Config.categoryStudentReflections)
        }
        if flags.showFacultyFarewells,
           hasArticles(in: Config.categoryFacultyFarewells) {
            list.append(Config.categoryFacultyFarewells)
        }
        if flags.showNews { list.append("News") }
        if flags.showOpinion { list.append("Opinion") }
        if flags.showSports { list.append("Sports") }
        if flags.showArtsEntertainment { list.append(Config.categoryArtsEntertainment) }
        if flags.showEditorial { list.append("Editorial") }
        if list != categories { categories = list }
    }

    private func hasArticles(in category: String) -> Bool {
        articles.contains { $0.category.lowercased() == category.lowercased() }
    }

    private func applyingBookmarks(to articles: [Article]) async -> [Article] {
        guard let uid = AuthService.shared.currentUser?.uid else {
            return articles.map { var article = $0; article.isBookmarked = false; return article }
        }
        guard let ids = try? await FirestoreService.shared.getBookmarkedArticleIDs(uid: uid) else { return articles }
        let bookmarked = Set(ids)
        var result = articles
        for index in result.indices {
            result[index].isBookmarked = bookmarked.contains(result[index].id)
            service.updateBookmark(id: result[index].id, isBookmarked: result[index].isBookmarked)
        }
        return result
    }

    private func applyFilter() {
        var base = articles

        base = base.filter { appConfiguration.flags.showsFeedCategory($0.category) }

        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        base = base.filter { $0.publishedDate >= oneYearAgo }

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            base = base.filter {
                $0.title.lowercased().contains(q) ||
                $0.summary.lowercased().contains(q) ||
                $0.author.lowercased().contains(q)
            }
        }

        filteredArticles = base
    }
}
