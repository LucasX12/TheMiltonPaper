import SwiftUI

struct SectionsView: View {
    @StateObject private var viewModel = ArticleFeedViewModel()
    @ObservedObject private var appConfiguration = AppConfiguration.shared
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var selectedSection: SectionDescriptor?
    @State private var showSearch = false
    @State private var showLoginPrompt = false

    private var sections: [SectionDescriptor] {
        SectionDescriptor.available(flags: appConfiguration.flags, articles: viewModel.filteredArticles)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.articles.isEmpty {
                    sectionSkeleton
                } else if let error = viewModel.errorMessage, viewModel.articles.isEmpty {
                    ErrorView(message: error) { Task { await viewModel.loadArticles() } }
                } else {
                    sectionIndex
                }
            }
            .background(Color.miltonBackground.ignoresSafeArea())
            .navigationTitle("Sections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Search")
                }
            }
            .navigationDestination(item: $selectedSection) { destination(for: $0) }
            .navigationDestination(isPresented: $showSearch) { SearchView() }
            .sheet(isPresented: $showLoginPrompt) { LoginView() }
            .task(id: authViewModel.currentUser?.uid) { await viewModel.loadArticles() }
            .onChange(of: appConfiguration.flags) { _, flags in
                if let selectedSection, !selectedSection.isVisible(flags: flags) {
                    self.selectedSection = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .miltonBookmarkChanged)) { note in
                guard let id = note.userInfo?["articleID"] as? String,
                      let isBookmarked = note.userInfo?["isBookmarked"] as? Bool else { return }
                viewModel.setBookmarked(id: id, isBookmarked)
            }
        }
    }

    private var sectionIndex: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let error = viewModel.errorMessage {
                    InlineRetryView(message: error) { Task { await viewModel.refresh() } }
                }
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    Button { selectedSection = section } label: {
                        HStack(spacing: 12) {
                            Text(section.title)
                                .font(.system(.title2, design: .serif, weight: .bold))
                                .foregroundColor(.miltonText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.miltonSecondary)
                        }
                        .frame(minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("section.\(section.id)")
                    if index < sections.count - 1 { EditorialRule() }
                }

                sectionsFooter
            }
            .padding(.horizontal, MiltonLayout.gutter)
            .editorialReadableColumn()
        }
        .refreshable { await viewModel.refresh() }
    }

    /// The paper's colophon. About itself stays on the masthead wordmark and
    /// in the You tab.
    private var sectionsFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialRule().padding(.top, 20)

            AINoticeView()
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
    }

    private var sectionSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { _ in
                ShimmerView().frame(height: 22).padding(.vertical, 21)
                EditorialRule()
            }
        }
        .padding(.horizontal, MiltonLayout.gutter)
        .editorialReadableColumn()
    }

    @ViewBuilder
    private func destination(for section: SectionDescriptor) -> some View {
        switch section.kind {
        case .issue:
            ThisWeekView()
                .navigationTitle(section.title)
                .navigationBarTitleDisplayMode(.inline)
        case .articles(let category):
            SectionFeedView(
                category: category,
                articles: viewModel.filteredArticles.filter { $0.matches(category: category) },
                bookmarkAction: bookmarkAction
            )
        }
    }

    private func bookmarkAction(for article: Article) -> (() -> Void)? {
        authViewModel.isAuthenticated
            ? { Task { await toggleBookmark(article) } }
            : { showLoginPrompt = true }
    }

    private func toggleBookmark(_ article: Article) async {
        guard let uid = authViewModel.currentUser?.uid else { return }
        let current = viewModel.articles.first(where: { $0.id == article.id })?.isBookmarked
            ?? article.isBookmarked
        let newValue = !current
        viewModel.setBookmarked(id: article.id, newValue)
        ArticleService.shared.updateBookmark(id: article.id, isBookmarked: newValue)
        do {
            if newValue {
                try await FirestoreService.shared.addBookmark(uid: uid, articleID: article.id)
            } else {
                try await FirestoreService.shared.removeBookmark(uid: uid, articleID: article.id)
            }
            NotificationCenter.default.post(name: .miltonBookmarkChanged, object: nil,
                userInfo: ["articleID": article.id, "isBookmarked": newValue])
        } catch {
            viewModel.errorMessage = "Couldn't update your saved stories. Please try again."
            viewModel.setBookmarked(id: article.id, !newValue)
            ArticleService.shared.updateBookmark(id: article.id, isBookmarked: !newValue)
        }
    }
}

struct SectionFeedView: View {
    let category: String
    let articles: [Article]
    let bookmarkAction: (Article) -> (() -> Void)?

    @State private var selectedArticle: Article?

    private var sortedArticles: [Article] {
        articles.sorted { $0.publishedDate > $1.publishedDate }
    }

    var body: some View {
        Group {
            if sortedArticles.isEmpty {
                Text("No stories are available in this section.")
                    .font(.miltonBody)
                    .foregroundColor(.miltonSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(MiltonLayout.gutter)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let first = sortedArticles.first {
                            LeadStoryView(article: first, onBookmark: bookmarkAction(first), showsCategory: false) { selectedArticle = first }
                                .padding(.bottom, 20)
                        }

                        ForEach(Array(sortedArticles.dropFirst().enumerated()), id: \.element.id) { _, article in
                            EditorialRule()
                            ArticleCardView(article: article, onBookmark: bookmarkAction(article), showsCategory: false) { selectedArticle = article }
                        }
                    }
                    .padding(.horizontal, MiltonLayout.gutter)
                    .padding(.vertical, 16)
                    .editorialReadableColumn()
                }
            }
        }
        .background(Color.miltonBackground.ignoresSafeArea())
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedArticle) { ArticleDetailView(article: $0) }
    }
}
