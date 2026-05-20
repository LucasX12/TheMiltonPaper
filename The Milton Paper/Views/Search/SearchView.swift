import SwiftUI

struct SearchView: View {
    @State private var searchQuery = ""
    @State private var articles: [Article] = []
    @State private var isLoading = true
    @State private var selectedArticle: Article?

    private var filteredArticles: [Article] {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            return articles
        }
        let query = searchQuery.lowercased()
        return articles.filter { article in
            article.title.lowercased().contains(query) ||
            article.summary.lowercased().contains(query) ||
            article.author.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.miltonBackground.ignoresSafeArea()

                if isLoading {
                    LoadingView()
                } else if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.miltonSecondary.opacity(0.4))
                        Text("Search articles")
                            .font(.miltonTitle)
                            .foregroundColor(.miltonSecondary.opacity(0.4))
                    }
                } else if filteredArticles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.miltonSecondary.opacity(0.4))
                        Text("No results found")
                            .font(.miltonTitle)
                            .foregroundColor(.miltonSecondary.opacity(0.4))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredArticles) { article in
                                ArticleCardView(article: article, onBookmark: nil)
                                    .onTapGesture {
                                        selectedArticle = article
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.miltonSurface, for: .navigationBar)
            .searchable(text: $searchQuery, prompt: "Search articles")
            .navigationDestination(item: $selectedArticle) { article in
                ArticleDetailView(article: article)
            }
        }
        .task {
            do {
                articles = try await ArticleService.shared.fetchArticles()
            } catch {
                articles = []
            }
            isLoading = false
        }
    }
}

#Preview {
    SearchView()
}
