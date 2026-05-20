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

    let categories = ["Wordle", "Recent", "News", "Opinion", "Sports", "Editorial"]

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
            articles = try await service.fetchArticles()
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        errorMessage = nil
        do {
            articles = try await service.fetchArticles(forceRefresh: true)
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectCategory(_ category: String) {
        selectedCategory = category
    }

    // MARK: - Private

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
