import SwiftUI

extension Notification.Name {
    static let miltonNavigateToCategory = Notification.Name("miltonNavigateToCategory")
    static let miltonBookmarkChanged    = Notification.Name("miltonBookmarkChanged")
}

struct ArticleFeedView: View {
    @StateObject private var viewModel = ArticleFeedViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedArticle: Article?
    @State private var showLoginPrompt = false
    @State private var categoryIndex = 2
    @State private var pageIndex: Int? = 2
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
            .onChange(of: pageIndex) { _, newValue in
                if let newValue, newValue != categoryIndex { categoryIndex = newValue }
            }
            .onReceive(NotificationCenter.default.publisher(for: .miltonNavigateToCategory)) { notification in
                guard let category = notification.userInfo?["category"] as? String,
                      let index = viewModel.categories.firstIndex(where: {
                          $0.lowercased() == category.lowercased()
                      }) else { return }
                selectedArticle = nil
                selectPage(index)
            }
            .onReceive(NotificationCenter.default.publisher(for: .miltonNavigateToArticle)) { notification in
                guard let id = notification.userInfo?["articleId"] as? String else { return }
                Task {
                    if let article = try? await ArticleService.shared.fetchArticle(id: id) {
                        selectedArticle = article
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .miltonBookmarkChanged)) { notification in
                guard let id = notification.userInfo?["articleID"] as? String,
                      let isBookmarked = notification.userInfo?["isBookmarked"] as? Bool else { return }
                viewModel.setBookmarked(id: id, isBookmarked)
            }
        }
    }

    // MARK: - Page Selection

    private var tabSelectionBinding: Binding<Int> {
        Binding(
            get: { categoryIndex },
            set: { selectPage($0) }
        )
    }

    private func selectPage(_ index: Int) {
        categoryIndex = index
        withAnimation(.easeInOut(duration: 0.3)) {
            pageIndex = index
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom
            let pageWidth = geo.size.width

            VStack(spacing: 0) {
                CategoryTabBar(
                    categories: viewModel.categories,
                    selectedIndex: tabSelectionBinding
                )

                // Native lazy pager: pages are built on demand (the UIKit page
                // controller built all of them eagerly) and content extends
                // beneath the floating tab bar instead of being clipped at it.
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(viewModel.categories.indices, id: \.self) { index in
                            categoryPage(for: viewModel.categories[index])
                                .safeAreaPadding(.bottom, bottomInset)
                                .frame(width: pageWidth)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $pageIndex)
                .scrollIndicators(.hidden)
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
    }

    // MARK: - Per-Category Page

    @ViewBuilder
    private func categoryPage(for category: String) -> some View {
        if category == "This Week" {
            ThisWeekView()
        } else if category == "Mordle" {
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
                            Button { selectedArticle = featured } label: {
                                FeaturedArticleView(
                                    article: featured,
                                    onBookmark: authViewModel.isAuthenticated
                                        ? { Task { await toggleBookmark(featured) } }
                                        : { showLoginPrompt = true }
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }

                        ForEach(Array(pageArticles.dropFirst().enumerated()), id: \.element.id) { index, article in
                            Button { selectedArticle = article } label: {
                                cardView(for: article, at: index)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
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
        guard let uid = authViewModel.currentUser?.uid else { return }
        let current = viewModel.articles.first(where: { $0.id == article.id })?.isBookmarked
            ?? article.isBookmarked
        let isBookmarked = !current

        viewModel.setBookmarked(id: article.id, isBookmarked)
        ArticleService.shared.updateBookmark(id: article.id, isBookmarked: isBookmarked)
        do {
            if isBookmarked {
                try await FirestoreService.shared.addBookmark(uid: uid, articleID: article.id)
            } else {
                try await FirestoreService.shared.removeBookmark(uid: uid, articleID: article.id)
            }
        } catch {
            // Revert so the UI stays truthful if persistence fails
            viewModel.setBookmarked(id: article.id, !isBookmarked)
            ArticleService.shared.updateBookmark(id: article.id, isBookmarked: !isBookmarked)
        }
    }
}
