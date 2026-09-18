import SwiftUI

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarkViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedArticle: Article?
    @State private var showLoginPrompt = false
    @State private var pendingDeleteOffsets: IndexSet?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.miltonBackground.ignoresSafeArea()

                if !authViewModel.isAuthenticated {
                    unauthenticatedState
                } else if viewModel.isLoading && viewModel.bookmarkedArticles.isEmpty {
                    EditorialFeedSkeleton()
                } else if let error = viewModel.errorMessage,
                          viewModel.bookmarkedArticles.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.loadBookmarks() }
                    }
                } else if viewModel.bookmarkedArticles.isEmpty {
                    emptyState
                } else {
                    bookmarkList
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.miltonSurface, for: .navigationBar)
            .task(id: authViewModel.currentUser?.uid) {
                if authViewModel.isAuthenticated {
                    await viewModel.loadBookmarks()
                }
            }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleDetailView(article: article)
            }
            .sheet(isPresented: $showLoginPrompt) { LoginView() }
            .onReceive(NotificationCenter.default.publisher(for: .miltonBookmarkChanged)) { _ in
                Task { await viewModel.loadBookmarks() }
            }
            .alert("Remove Bookmark?", isPresented: Binding(
                get: { pendingDeleteOffsets != nil },
                set: { if !$0 { pendingDeleteOffsets = nil } }
            )) {
                Button("Remove", role: .destructive) {
                    if let offsets = pendingDeleteOffsets {
                        Task { await viewModel.removeBookmarks(at: offsets) }
                        pendingDeleteOffsets = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingDeleteOffsets = nil }
            } message: {
                Text("This article will be removed from your bookmarks.")
            }
        }
    }

    private var bookmarkList: some View {
        List {
            if let error = viewModel.errorMessage {
                InlineRetryView(message: error) { Task { await viewModel.loadBookmarks() } }
            }
            ForEach(viewModel.bookmarkedArticles) { article in
                ArticleCardView(article: article, onSelect: { selectedArticle = article })
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.miltonBackground)
                    .listRowSeparatorTint(Color.miltonSecondary.opacity(0.22))
            }
            .onDelete { offsets in
                pendingDeleteOffsets = offsets
            }
        }
        .listStyle(.plain)
        .editorialReadableColumn()
        .background(Color.miltonBackground)
        .refreshable { await viewModel.loadBookmarks() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No saved articles yet")
                .font(.miltonTitle)
                .foregroundColor(.miltonSecondary)
            Text("Tap the bookmark icon on any article to save it here.")
                .font(.miltonMeta)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var unauthenticatedState: some View {
        VStack(spacing: 14) {
            Text("Sign in to save articles")
                .font(.miltonTitle)
                .foregroundColor(.miltonText)
            Text("Create a free account to bookmark articles and read them anytime.")
                .font(.miltonMeta)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showLoginPrompt = true
            } label: {
                Text("Sign In")
                    .miltonPrimaryButton()
            }
            .padding(.horizontal, 48)
        }
    }
}
