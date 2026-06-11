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
    @State private var currentScrollOffset: CGFloat = 0

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
                                currentScrollOffset = offset
                                if progress > readingProgress {
                                    readingProgress = progress
                                    lastScrollOffset = offset
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

                            // Related articles
                            if !viewModel.relatedArticles.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("More from \(viewModel.article.category)")
                                        .font(.miltonLabel)
                                        .foregroundColor(.miltonSecondary)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 20)
                                        .padding(.bottom, 12)

                                    Divider().padding(.horizontal, 20)

                                    ForEach(viewModel.relatedArticles) { related in
                                        NavigationLink(destination: ArticleDetailView(article: related)) {
                                            RelatedArticleRow(article: related)
                                        }
                                        .buttonStyle(.plain)

                                        if related.id != viewModel.relatedArticles.last?.id {
                                            Divider().padding(.horizontal, 20)
                                        }
                                    }
                                }
                                .background(Color.miltonSurface)
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }

                            Spacer(minLength: 100)
                        }
                        .frame(width: w)
                    }
                }
                .onChange(of: webViewHeight) { _, _ in restoreScrollIfNeeded() }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if currentScrollOffset > 300 {
                Button {
                    scrollView?.setContentOffset(.zero, animated: true)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.miltonPrimary)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: currentScrollOffset > 300)
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
        .task { await viewModel.loadRelatedArticles() }
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

// MARK: - Related article row

private struct RelatedArticleRow: View {
    let article: Article

    var body: some View {
        HStack(spacing: 12) {
            if let thumb = article.thumbnailURL {
                AsyncImage(url: thumb) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color.miltonSecondary.opacity(0.12)
                }
                .frame(width: 64, height: 64)
                .cornerRadius(8)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.miltonBody)
                    .foregroundColor(.miltonText)
                    .lineLimit(2)
                Text(article.author)
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.miltonSecondary.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
