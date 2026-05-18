import SwiftUI

struct ArticleDetailView: View {
    @StateObject private var viewModel: ArticleDetailViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showLoginPrompt = false
    @State private var webViewHeight: CGFloat = 400

    private let screenWidth = UIScreen.main.bounds.width

    init(article: Article) {
        _viewModel = StateObject(wrappedValue: ArticleDetailViewModel(article: article))
    }

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ArticleHeaderView(article: viewModel.article)

                    ArticleBodyView(
                        htmlContent: viewModel.article.bodyHTML,
                        baseURL: viewModel.article.articleURL,
                        contentHeight: $webViewHeight,
                        viewWidth: screenWidth
                    )
                    // Explicit width so the WKWebView viewport and SwiftUI frame are identical
                    .frame(width: screenWidth, height: max(400, webViewHeight))
                    .padding(.top, 8)

                    // Footer: read original
                    Link(destination: viewModel.article.articleURL) {
                        HStack(spacing: 6) {
                            Text("Read on miltonpaper.com")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.miltonPrimary)
                        .padding(.vertical, 16)
                    }

                    Spacer(minLength: 40)
                }
                // Clamp the VStack to the screen width so the ScrollView can't grow horizontally
                .frame(width: screenWidth)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ShareButton(article: viewModel.article)

                Button {
                    if authViewModel.isAuthenticated {
                        Task { await viewModel.toggleBookmark() }
                    } else {
                        showLoginPrompt = true
                    }
                } label: {
                    Image(systemName: viewModel.article.isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(viewModel.article.isBookmarked ? .miltonAccent : .miltonPrimary)
                }
                .accessibilityLabel(viewModel.article.isBookmarked ? "Remove bookmark" : "Bookmark article")
            }
        }
        .task { await viewModel.checkBookmarkStatus() }
        .sheet(isPresented: $showLoginPrompt) { LoginView() }
    }
}
