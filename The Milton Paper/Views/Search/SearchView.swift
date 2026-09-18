import SwiftUI

struct SearchView: View {
    @ObservedObject private var appConfiguration = AppConfiguration.shared
    @State private var searchQuery = ""
    @State private var articles: [Article] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedArticle: Article?

    private var filteredArticles: [Article] {
        let visible = articles.filter { appConfiguration.flags.showsFeedCategory($0.category) }
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return visible }
        let query = trimmed.lowercased()
        return visible.filter {
            $0.title.lowercased().contains(query) ||
            $0.summary.lowercased().contains(query) ||
            $0.author.lowercased().contains(query)
        }
    }

    var body: some View {
        Group {
            if isLoading && articles.isEmpty {
                EditorialFeedSkeleton()
            } else if let errorMessage, articles.isEmpty {
                ErrorView(message: errorMessage) { Task { await loadArticles() } }
            } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyMessage("Search the archive", detail: "Enter a headline, writer, or topic.")
            } else if filteredArticles.isEmpty {
                emptyMessage("No matching stories", detail: "Check the spelling or try a broader search.")
            } else {
                results
            }
        }
        .background(Color.miltonBackground.ignoresSafeArea())
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search stories")
        .navigationDestination(item: $selectedArticle) { ArticleDetailView(article: $0) }
        .task { await loadArticles() }
    }

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let errorMessage {
                    InlineRetryView(message: errorMessage) { Task { await loadArticles() } }
                }
                ForEach(Array(filteredArticles.enumerated()), id: \.element.id) { index, article in
                    ArticleCardView(article: article, onSelect: { selectedArticle = article })
                    if index < filteredArticles.count - 1 { EditorialRule() }
                }
            }
            .padding(.horizontal, MiltonLayout.gutter)
            .editorialReadableColumn()
        }
        .refreshable { await loadArticles() }
    }

    private func emptyMessage(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.miltonTitle)
                .foregroundColor(.miltonText)
            Text(detail)
                .font(.miltonMeta)
                .foregroundColor(.miltonSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(MiltonLayout.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadArticles() async {
        isLoading = true
        errorMessage = nil
        do {
            articles = try await ArticleService.shared.fetchArticles()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
