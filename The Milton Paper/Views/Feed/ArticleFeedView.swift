import SwiftUI

struct ArticleFeedView: View {
    @StateObject private var viewModel = ArticleFeedViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedArticle: Article?
    @State private var showLoginPrompt = false
    @State private var categoryIndex = 1
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.miltonBackground.ignoresSafeArea()

                if viewModel.isLoading && viewModel.articles.isEmpty {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.articles.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.loadArticles() }
                    }
                } else {
                    feedContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.miltonSurface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        showAbout = true
                    } label: {
                        Text("The Milton Paper")
                            .font(.custom("OldEnglishTextMT", size: 28))
                            .foregroundColor(.miltonPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .task { await viewModel.loadArticles() }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleDetailView(article: article)
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showLoginPrompt) {
                LoginView()
            }
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        VStack(spacing: 0) {
            CategoryTabBar(
                categories: viewModel.categories,
                selectedIndex: $categoryIndex
            )

            TabView(selection: $categoryIndex) {
                ForEach(viewModel.categories.indices, id: \.self) { index in
                    categoryPage(for: viewModel.categories[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    // MARK: - Per-Category Page

    @ViewBuilder
    private func categoryPage(for category: String) -> some View {
        if category == "Wordle" {
            WordlePageView()
        } else {
            let pageArticles = self.pageArticles(for: category)
            if pageArticles.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let featured = pageArticles.first {
                            FeaturedArticleView(
                                article: featured,
                                onBookmark: authViewModel.isAuthenticated
                                    ? { Task { await toggleBookmark(featured) } }
                                    : { showLoginPrompt = true }
                            )
                            .padding(.horizontal, 16)
                            .onTapGesture { selectedArticle = featured }
                        }

                        ForEach(Array(pageArticles.dropFirst().enumerated()), id: \.element.id) { index, article in
                            cardView(for: article, at: index)
                                .padding(.horizontal, 16)
                                .onTapGesture { selectedArticle = article }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.top, 12)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }

    private func pageArticles(for category: String) -> [Article] {
        let base = viewModel.filteredArticles
        if category == "Recent" { return Array(base.prefix(15)) }
        return base.filter { $0.category.lowercased() == category.lowercased() }
    }

    // MARK: - Card Style Rotation

    @ViewBuilder
    private func cardView(for article: Article, at index: Int) -> some View {
        let bookmark: (() -> Void)? = authViewModel.isAuthenticated
            ? { Task { await toggleBookmark(article) } }
            : { showLoginPrompt = true }

        switch index % 6 {
        case 0:
            WideArticleCardView(article: article, onBookmark: bookmark)
        case 3:
            EditorialArticleCardView(article: article, onBookmark: bookmark)
        default:
            ArticleCardView(article: article, onBookmark: bookmark)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 44))
                .foregroundColor(.miltonSecondary.opacity(0.4))
            Text("No articles found")
                .font(.miltonTitle)
                .foregroundColor(.miltonSecondary)
            if !viewModel.searchQuery.isEmpty {
                Text("Try a different search term")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Actions

    private func toggleBookmark(_ article: Article) async {
        if let idx = viewModel.articles.firstIndex(where: { $0.id == article.id }) {
            let isBookmarked = !viewModel.articles[idx].isBookmarked
            viewModel.articles[idx].isBookmarked = isBookmarked
            viewModel.filteredArticles = viewModel.articles
            guard let uid = authViewModel.currentUser?.uid else { return }
            let fs = FirestoreService.shared
            do {
                if isBookmarked {
                    try await fs.addBookmark(uid: uid, articleID: article.id)
                } else {
                    try await fs.removeBookmark(uid: uid, articleID: article.id)
                }
            } catch {}
        }
    }
}
