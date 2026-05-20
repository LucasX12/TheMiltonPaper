import SwiftUI
import UIKit

// MARK: - UIKit scroll progress bridge

private final class ScrollTrackerUIView: UIView {
    var onScroll: (Double, CGFloat) -> Void
    var onScrollViewReady: ((UIScrollView) -> Void)?
    private var token: NSKeyValueObservation?

    init(onScroll: @escaping (Double, CGFloat) -> Void) {
        self.onScroll = onScroll
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        token = nil
        guard window != nil else { return }
        findAndAttach()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if token == nil { findAndAttach() }
    }

    private func findAndAttach() {
        var v: UIView? = superview
        while let candidate = v {
            if let sv = candidate as? UIScrollView {
                onScrollViewReady?(sv)
                token = sv.observe(\.contentOffset, options: .new) { [weak self] sv, _ in
                    let contentH  = sv.contentSize.height
                    let viewportH = sv.bounds.height
                    guard contentH > viewportH + 120 else { return }
                    let offset    = max(0, sv.contentOffset.y)
                    let scrollable = contentH - viewportH
                    let progress  = min(1.0, offset / scrollable)
                    DispatchQueue.main.async { self?.onScroll(progress, offset) }
                }
                return
            }
            v = candidate.superview
        }
    }
}

private struct ScrollProgressTracker: UIViewRepresentable {
    let onScroll: (Double, CGFloat) -> Void
    let onScrollViewReady: ((UIScrollView) -> Void)?

    func makeUIView(context: Context) -> ScrollTrackerUIView {
        let view = ScrollTrackerUIView(onScroll: onScroll)
        view.onScrollViewReady = onScrollViewReady
        return view
    }
    func updateUIView(_ uiView: ScrollTrackerUIView, context: Context) {
        uiView.onScroll = onScroll
    }
}

// MARK: - Article detail view

struct ArticleDetailView: View {
    @StateObject private var viewModel: ArticleDetailViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showLoginPrompt = false
    @State private var webViewHeight: CGFloat = 400
    @State private var readingProgress: Double = 0
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollView: UIScrollView?
    @State private var hasRestoredScroll = false

    let initialScrollOffset: CGFloat

    init(article: Article, initialScrollOffset: CGFloat = 0) {
        _viewModel = StateObject(wrappedValue: ArticleDetailViewModel(article: article))
        self.initialScrollOffset = initialScrollOffset
    }

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                ScrollView {
                    ZStack(alignment: .top) {
                        ScrollProgressTracker(
                            onScroll: { progress, offset in
                                if progress > readingProgress {
                                    readingProgress = progress
                                    lastScrollOffset = offset  // track the furthest point reached
                                }
                                if progress >= 0.99 { saveReadingProgress() }
                            },
                            onScrollViewReady: { sv in scrollView = sv }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)

                        VStack(spacing: 0) {
                            ArticleHeaderView(article: viewModel.article, width: w)

                            ArticleBodyView(
                                htmlContent: viewModel.article.bodyHTML,
                                baseURL: viewModel.article.articleURL,
                                contentHeight: $webViewHeight,
                                viewWidth: w
                            )
                            .frame(width: w, height: max(400, webViewHeight))
                            .padding(.top, 8)

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
                        .frame(width: w)
                    }
                }
                .onChange(of: webViewHeight) { _, _ in restoreScrollIfNeeded() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                CircularProgressRing(progress: readingProgress)
                    .animation(.linear(duration: 0.15), value: readingProgress)
            }
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
        .onDisappear { saveReadingProgress() }
    }

    private func restoreScrollIfNeeded() {
        guard !hasRestoredScroll, initialScrollOffset > 10, let sv = scrollView else { return }
        let contentH  = sv.contentSize.height
        let viewportH = sv.bounds.height
        guard contentH > viewportH + 120 else { return }
        let clamped = min(initialScrollOffset, contentH - viewportH)
        sv.setContentOffset(CGPoint(x: 0, y: clamped), animated: false)
        hasRestoredScroll = true
    }

    private func saveReadingProgress() {
        guard readingProgress > 0.01 else { return }
        ReadingProgressService.shared.record(
            articleId: viewModel.article.id,
            title: viewModel.article.title,
            author: viewModel.article.author,
            category: viewModel.article.category,
            thumbnailURL: viewModel.article.thumbnailURL,
            articleURL: viewModel.article.articleURL,
            progress: readingProgress,
            scrollOffset: lastScrollOffset
        )
    }
}
