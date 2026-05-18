import SwiftUI

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarkViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedArticle: Article?
    @State private var showLoginPrompt = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.miltonBackground.ignoresSafeArea()

                if !authViewModel.isAuthenticated {
                    unauthenticatedState
                } else if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.bookmarkedArticles.isEmpty {
                    emptyState
                } else {
                    bookmarkList
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.miltonSurface, for: .navigationBar)
            .task {
                if authViewModel.isAuthenticated {
                    await viewModel.loadBookmarks()
                }
            }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleDetailView(article: article)
            }
            .sheet(isPresented: $showLoginPrompt) { LoginView() }
        }
    }

    private var bookmarkList: some View {
        List {
            ForEach(viewModel.bookmarkedArticles) { article in
                ArticleCardView(article: article)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.miltonBackground)
                    .listRowSeparator(.hidden)
                    .onTapGesture { selectedArticle = article }
            }
            .onDelete { offsets in
                Task { await viewModel.removeBookmarks(at: offsets) }
            }
        }
        .listStyle(.plain)
        .background(Color.miltonBackground)
        .refreshable { await viewModel.loadBookmarks() }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark")
                .font(.system(size: 52))
                .foregroundColor(.miltonSecondary.opacity(0.3))
            Text("No saved articles yet")
                .font(.miltonTitle)
                .foregroundColor(.miltonSecondary)
            Text("Tap the bookmark icon on any article to save it here.")
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var unauthenticatedState: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundColor(.miltonSecondary.opacity(0.4))
            Text("Sign in to save articles")
                .font(.miltonTitle)
                .foregroundColor(.miltonText)
            Text("Create a free account to bookmark articles and read them anytime.")
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Sign In") { showLoginPrompt = true }
                .miltonPrimaryButton()
                .padding(.horizontal, 48)
        }
    }
}
