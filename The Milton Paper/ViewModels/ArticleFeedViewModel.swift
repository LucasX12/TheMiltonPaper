import Foundation
import Combine

@MainActor
final class ArticleFeedViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var filteredArticles: [Article] = []
    @Published var selectedCategory: String = "All"
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""

    // Temporary sections (Student Reflections, Faculty Farewells) are inserted
    // after Recent only while their feeds still return articles, so the tabs
    // retire themselves when the site takes the sections down.
    @Published private(set) var categories = ["This Week", "Mordle", "Recent",
                                              "News", "Opinion", "Sports", "Editorial"]

    private let service = ArticleService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.applyFilter() }
            .store(in: &cancellables)

        $selectedCategory
            .sink { [weak self] _ in self?.applyFilter() }
            .store(in: &cancellables)
    }

    var featuredArticle: Article? {
        filteredArticles.first
    }

    var feedArticles: [Article] {
        filteredArticles.count > 1 ? Array(filteredArticles.dropFirst()) : []
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

    func selectCategory(_ category: String) {
        selectedCategory = category
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
        var list = ["This Week", "Mordle", "Recent"]
        if hasArticles(in: Config.categoryStudentReflections) {
            list.append(Config.categoryStudentReflections)
        }
        if hasArticles(in: Config.categoryFacultyFarewells) {
            list.append(Config.categoryFacultyFarewells)
        }
        list += ["News", "Opinion", "Sports", "Editorial"]
        if list != categories { categories = list }
    }

    private func hasArticles(in category: String) -> Bool {
        articles.contains { $0.category.lowercased() == category.lowercased() }
    }

    private func applyingBookmarks(to articles: [Article]) async -> [Article] {
        guard let uid = AuthService.shared.currentUser?.uid,
              let ids = try? await FirestoreService.shared.getBookmarkedArticleIDs(uid: uid),
              !ids.isEmpty else { return articles }
        let bookmarked = Set(ids)
        var result = articles
        for index in result.indices where bookmarked.contains(result[index].id) {
            result[index].isBookmarked = true
            service.updateBookmark(id: result[index].id, isBookmarked: true)
        }
        return result
    }

    private func applyFilter() {
        var base = articles

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

        if selectedCategory != "All" {
            base = base.filter { $0.category.lowercased() == selectedCategory.lowercased() }
        }

        filteredArticles = base
    }
}
