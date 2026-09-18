import SwiftUI

extension Notification.Name {
    static let miltonNavigateToCategory = Notification.Name("miltonNavigateToCategory")
    static let miltonBookmarkChanged = Notification.Name("miltonBookmarkChanged")
}

/// The app's editorial front page. Stories are assigned once by
/// `EditorialLayout`, so a story never repeats as the reader scrolls.
struct ArticleFeedView: View {
    @StateObject private var viewModel = ArticleFeedViewModel()
    @ObservedObject private var appConfiguration = AppConfiguration.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedArticle: Article?
    @State private var selectedSection: SectionDescriptor?
    @State private var showSearch = false
    @State private var showLoginPrompt = false

    private var layout: EditorialLayout {
        EditorialLayout(articles: viewModel.filteredArticles, flags: appConfiguration.flags)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.articles.isEmpty {
                    EditorialFeedSkeleton()
                } else if let error = viewModel.errorMessage, viewModel.articles.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.loadArticles() }
                    }
                } else if layout.lead == nil {
                    emptyState
                } else {
                    frontPage
                }
            }
            .background(Color.miltonBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSearch) { SearchView() }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleDetailView(article: article)
            }
            .navigationDestination(item: $selectedSection) { section in
                sectionDestination(section)
            }
            .sheet(isPresented: $showLoginPrompt) { LoginView() }
            .task(id: authViewModel.currentUser?.uid) { await viewModel.loadArticles() }
            .onChange(of: appConfiguration.flags) { _, flags in
                if let selectedSection, !selectedSection.isVisible(flags: flags) {
                    self.selectedSection = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .miltonNavigateToCategory)) { note in
                guard let category = note.userInfo?["category"] as? String,
                      appConfiguration.flags.showsFeedCategory(category) else { return }
                selectedArticle = nil
                selectedSection = .articles(category)
            }
            .onReceive(NotificationCenter.default.publisher(for: .miltonNavigateToArticle)) { note in
                guard let id = note.userInfo?["articleId"] as? String else { return }
                Task {
                    if let article = try? await ArticleService.shared.fetchArticle(id: id) {
                        selectedArticle = article
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .miltonBookmarkChanged)) { note in
                guard let id = note.userInfo?["articleID"] as? String,
                      let isBookmarked = note.userInfo?["isBookmarked"] as? Bool else { return }
                viewModel.setBookmarked(id: id, isBookmarked)
            }
        }
    }

    private var frontPage: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                masthead

                if let error = viewModel.errorMessage {
                    inlineRefreshError(error)
                        .padding(.bottom, 18)
                }

                if let lead = layout.lead {
                    LeadStoryView(article: lead, onBookmark: bookmarkAction(for: lead)) { selectedArticle = lead }
                }

                if !layout.secondary.isEmpty {
                    EditorialRule().padding(.top, 22)
                    secondaryStories
                }

                if appConfiguration.flags.showThisWeek {
                    EditorialRule().padding(.vertical, 20)
                    IssuePromoView()
                }

                if !layout.latest.isEmpty {
                    latestStories.padding(.top, 24)
                }
            }
            .padding(.horizontal, MiltonLayout.gutter)
            .padding(.bottom, 36)
            .editorialReadableColumn()
        }
        .refreshable { await viewModel.refresh() }
    }

    private var masthead: some View {
        VStack(spacing: 3) {
            Text("The Milton Paper")
                .font(.custom("OldEnglishTextMT", size: 30, relativeTo: .title))
                .foregroundColor(.miltonText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.custom("Georgia", size: 13, relativeTo: .footnote))
                .foregroundColor(.miltonSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .overlay(alignment: .topTrailing) {
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.miltonSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search")
        }
        .overlay(alignment: .bottom) { EditorialRule() }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var secondaryStories: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize && layout.secondary.count == 2 {
            HStack(alignment: .top, spacing: 22) {
                ForEach(layout.secondary) { article in
                    SecondaryStoryView(article: article, onBookmark: bookmarkAction(for: article)) { selectedArticle = article }
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        } else {
            ForEach(Array(layout.secondary.enumerated()), id: \.element.id) { index, article in
                SecondaryStoryView(article: article, onBookmark: bookmarkAction(for: article)) { selectedArticle = article }
                if index < layout.secondary.count - 1 { EditorialRule() }
            }
        }
    }

    private var latestStories: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialRule().padding(.bottom, 13)
            Text("Latest")
                .font(.miltonSectionTitle)
                .foregroundColor(.miltonText)
                .padding(.bottom, 7)

            ForEach(Array(layout.latest.enumerated()), id: \.element.id) { index, article in
                ArticleCardView(article: article, onBookmark: bookmarkAction(for: article)) { selectedArticle = article }
                if index < layout.latest.count - 1 { EditorialRule() }
            }
        }
    }

    private func inlineRefreshError(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Couldn’t refresh. The stories below may be out of date.")
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
            Spacer(minLength: 4)
            Button("Retry") { Task { await viewModel.refresh() } }
                .font(.miltonCaption)
                .frame(minWidth: 44, minHeight: 44)
                .foregroundColor(.miltonPrimary)
        }
        .accessibilityHint(message)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No stories available")
                .font(.miltonTitle)
                .foregroundColor(.miltonText)
            Text("Check back after the next story is published.")
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
            Button("Refresh") { Task { await viewModel.refresh() } }
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(MiltonLayout.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func sectionDestination(_ descriptor: SectionDescriptor) -> some View {
        switch descriptor.kind {
        case .issue:
            ThisWeekView().navigationTitle(descriptor.title)
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
        let isBookmarked = !current

        viewModel.setBookmarked(id: article.id, isBookmarked)
        ArticleService.shared.updateBookmark(id: article.id, isBookmarked: isBookmarked)
        do {
            if isBookmarked {
                try await FirestoreService.shared.addBookmark(uid: uid, articleID: article.id)
            } else {
                try await FirestoreService.shared.removeBookmark(uid: uid, articleID: article.id)
            }
            NotificationCenter.default.post(name: .miltonBookmarkChanged, object: nil,
                userInfo: ["articleID": article.id, "isBookmarked": isBookmarked])
        } catch {
            viewModel.errorMessage = "Couldn't update your saved stories. Please try again."
            viewModel.setBookmarked(id: article.id, !isBookmarked)
            ArticleService.shared.updateBookmark(id: article.id, isBookmarked: !isBookmarked)
        }
    }
}
