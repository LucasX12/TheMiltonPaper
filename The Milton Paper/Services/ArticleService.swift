import Foundation

enum ArticleServiceError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parseError
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid feed URL."
        case .networkError(let e): return e.localizedDescription
        case .parseError:          return "Couldn't load articles. Pull to refresh."
        case .notFound:            return "Article not found."
        }
    }
}

@MainActor
final class ArticleService {
    static let shared = ArticleService()

    private var cache: [String: Article] = [:]
    private var cachedList: [Article] = []
    private var lastFetch: Date?
    private let cacheTimeout: TimeInterval = 300
    private var inFlightFetch: Task<[Article], Error>?

    // MARK: - Public API

    func fetchArticles(forceRefresh: Bool = false) async throws -> [Article] {
        if !forceRefresh,
           let last = lastFetch,
           Date().timeIntervalSince(last) < cacheTimeout,
           !cachedList.isEmpty {
            return cachedList
        }

        // Coalesce concurrent callers onto a single network fetch
        if let inFlight = inFlightFetch {
            return try await inFlight.value
        }

        let task = Task { () async throws -> [Article] in
            if Config.useMockData { return MockData.articles }
            if !Config.squarespaceAPIKey.isEmpty { return try await self.fetchSquarespaceAPI() }
            return try await self.fetchRSS()
        }
        inFlightFetch = task
        defer { inFlightFetch = nil }

        let articles = try await task.value
        updateCache(articles)
        return cachedList
    }

    func fetchArticle(id: String) async throws -> Article {
        if let cached = cache[id] { return cached }
        let articles = try await fetchArticles()
        guard let found = articles.first(where: { $0.id == id }) else {
            throw ArticleServiceError.notFound
        }
        return found
    }

    func searchArticles(query: String) async throws -> [Article] {
        let articles = try await fetchArticles()
        let q = query.lowercased()
        return articles.filter {
            $0.title.lowercased().contains(q) ||
            $0.summary.lowercased().contains(q) ||
            $0.author.lowercased().contains(q) ||
            $0.category.lowercased().contains(q)
        }
    }

    func updateBookmark(id: String, isBookmarked: Bool) {
        if let idx = cachedList.firstIndex(where: { $0.id == id }) {
            cachedList[idx].isBookmarked = isBookmarked
        }
        if var article = cache[id] {
            article.isBookmarked = isBookmarked
            cache[id] = article
        }
    }

    // MARK: - Private

    private func updateCache(_ articles: [Article]) {
        // The same story can appear in multiple category feeds; drop duplicates
        // and carry bookmark flags over from the previous cache generation.
        var seen = Set<String>()
        var merged: [Article] = []
        merged.reserveCapacity(articles.count)
        for var article in articles {
            guard seen.insert(article.id).inserted else { continue }
            if let previous = cache[article.id] {
                article.isBookmarked = previous.isBookmarked
            }
            merged.append(article)
        }
        cachedList = merged
        cache = Dictionary(uniqueKeysWithValues: merged.map { ($0.id, $0) })
        lastFetch = Date()
    }

    private func fetchRSS() async throws -> [Article] {
        var all: [Article] = []

        try await withThrowingTaskGroup(of: [Article].self) { group in
            for feed in Config.rssFeeds {
                guard let url = URL(string: feed.url) else { continue }
                group.addTask {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        return []
                    }
                    return await RSSParser().parse(data: data, defaultCategory: feed.category)
                }
            }
            for try await articles in group {
                all.append(contentsOf: articles)
            }
        }

        if all.isEmpty { throw ArticleServiceError.parseError }
        return all.sorted { $0.publishedDate > $1.publishedDate }
    }

    private func fetchSquarespaceAPI() async throws -> [Article] {
        let urlStr = "https://api.squarespace.com/1.0/blog/collection/\(Config.squarespaceCollectionID)/posts"
        guard let url = URL(string: urlStr) else { throw ArticleServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(Config.squarespaceAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)

        struct APIResponse: Decodable {
            let items: [APIItem]
            struct APIItem: Decodable {
                let id: String
                let title: String
                let author: Author?
                let publishedOn: Int?
                let categories: [String]?
                let excerpt: Excerpt?
                let body: String?
                let fullUrl: String?
                let assetUrl: String?
                struct Author: Decodable { let displayName: String? }
                struct Excerpt: Decodable { let html: String? }
            }
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        return decoded.items.compactMap { item in
            guard let urlStr = item.fullUrl, let url = URL(string: urlStr) else { return nil }
            let summary = item.excerpt?.html?
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? ""
            return Article(
                id: item.id,
                title: item.title,
                author: item.author?.displayName ?? "The Milton Paper",
                publishedDate: item.publishedOn.map { Date(timeIntervalSince1970: Double($0) / 1000) } ?? Date(),
                category: item.categories?.first ?? "News",
                summary: summary,
                bodyHTML: item.body ?? "",
                articleURL: url,
                thumbnailURL: item.assetUrl.flatMap { URL(string: $0) }
            )
        }
    }
}
