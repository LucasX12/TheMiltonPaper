import SwiftUI

struct SearchView: View {
    @State private var searchQuery = ""
    @State private var articles: [Article] = []
    @State private var isLoading = true
    @State private var selectedArticle: Article?
    @State private var errorMessage: String?

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
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        reload()
                    }
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

                            Spacer(minLength: 100)
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
            reload()
        }
    }

    private func reload() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                articles = try await ArticleService.shared.fetchArticles()
            } catch {
                errorMessage = error.localizedDescription
                articles = []
            }
            isLoading = false
        }
    }
}

#Preview {
    SearchView()
}
