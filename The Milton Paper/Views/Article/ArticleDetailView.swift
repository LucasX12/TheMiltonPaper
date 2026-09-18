import SwiftUI
import UIKit

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
        var view: UIView? = superview
        while let candidate = view {
            if let scrollView = candidate as? UIScrollView {
                DispatchQueue.main.async { [weak self, weak scrollView] in
                    if let scrollView { self?.onScrollViewReady?(scrollView) }
                }
                token = scrollView.observe(\.contentOffset, options: .new) { [weak self] scrollView, _ in
                    let scrollable = scrollView.contentSize.height - scrollView.bounds.height
                    guard scrollable > 120 else { return }
                    let offset = max(0, scrollView.contentOffset.y)
                    let progress = min(1, offset / scrollable)
                    DispatchQueue.main.async { self?.onScroll(progress, offset) }
                }
                return
            }
            view = candidate.superview
        }
    }
}

private struct ScrollProgressTracker: UIViewRepresentable {
    let onScroll: (Double, CGFloat) -> Void
    let onScrollViewReady: (UIScrollView) -> Void

    func makeUIView(context: Context) -> ScrollTrackerUIView {
        let view = ScrollTrackerUIView(onScroll: onScroll)
        view.onScrollViewReady = onScrollViewReady
        return view
    }

    func updateUIView(_ uiView: ScrollTrackerUIView, context: Context) {
        uiView.onScroll = onScroll
        uiView.onScrollViewReady = onScrollViewReady
    }
}

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
        GeometryReader { geometry in
            let contentWidth = min(geometry.size.width, MiltonLayout.readableWidth)

            ScrollView {
                ZStack(alignment: .top) {
                    ScrollProgressTracker(
                        onScroll: trackScroll,
                        onScrollViewReady: { scrollView = $0 }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        ArticleHeaderView(article: viewModel.article, width: contentWidth)

                        ArticleBodyView(
                            htmlContent: viewModel.article.bodyHTML,
                            baseURL: viewModel.article.articleURL,
                            contentHeight: $webViewHeight,
                            viewWidth: contentWidth
                        )
                        .frame(width: contentWidth, height: max(400, webViewHeight))
                        .padding(.top, 12)

                        relatedStories
                        Spacer(minLength: 44)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .onChange(of: webViewHeight) { _, _ in restoreScrollIfNeeded() }
        }
        .background(Color.miltonBackground.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.miltonPrimary)
                    .frame(width: geometry.size.width * readingProgress, height: 2)
                    .animation(.linear(duration: 0.12), value: readingProgress)
            }
            .frame(height: 2)
            .accessibilityHidden(true)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.miltonBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { saveButton }
            ToolbarItem(placement: .topBarTrailing) { articleActions }
        }
        .task(id: authViewModel.currentUser?.uid) { await viewModel.checkBookmarkStatus() }
        .task { await viewModel.loadRelatedArticles() }
        .sheet(isPresented: $showLoginPrompt) { LoginView() }
        .alert("Couldn't update Saved", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .onDisappear { saveReadingProgress() }
    }

    private var saveButton: some View {
        Button {
            if authViewModel.isAuthenticated {
                Task { await viewModel.toggleBookmark() }
            } else {
                showLoginPrompt = true
            }
        } label: {
            Image(systemName: viewModel.article.isBookmarked ? "bookmark.fill" : "bookmark")
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(viewModel.article.isBookmarked ? "Remove from Saved" : "Save Story")
    }

    private var articleActions: some View {
        Menu {
            ShareLink(item: viewModel.article.articleURL, subject: Text(viewModel.article.title)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Link(destination: viewModel.article.articleURL) {
                Label("Open on Website", systemImage: "arrow.up.right.square")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Article actions")
    }

    @ViewBuilder
    private var relatedStories: some View {
        if !viewModel.relatedArticles.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                EditorialRule()
                Text("More from \(viewModel.article.category)")
                    .font(.miltonSectionTitle)
                    .foregroundColor(.miltonText)
                    .padding(.vertical, 16)
                EditorialRule()

                ForEach(Array(viewModel.relatedArticles.enumerated()), id: \.element.id) { index, related in
                    NavigationLink(destination: ArticleDetailView(article: related)) {
                        RelatedArticleRow(article: related)
                    }
                    .buttonStyle(.plain)
                    if index < viewModel.relatedArticles.count - 1 { EditorialRule() }
                }
            }
            .padding(.horizontal, MiltonLayout.gutter)
            .frame(maxWidth: MiltonLayout.readableWidth)
        }
    }

    private func trackScroll(_ progress: Double, _ offset: CGFloat) {
        lastScrollOffset = offset
        guard progress > readingProgress else { return }
        let crossedEnd = progress >= 0.99 && readingProgress < 0.99
        if progress - readingProgress >= 0.005 || crossedEnd {
            readingProgress = progress
            if crossedEnd { saveReadingProgress() }
        }
    }

    private func restoreScrollIfNeeded() {
        guard !hasRestoredScroll, initialScrollOffset > 10, let scrollView else { return }
        let scrollable = scrollView.contentSize.height - scrollView.bounds.height
        guard scrollable > 120 else { return }
        scrollView.setContentOffset(
            CGPoint(x: 0, y: min(initialScrollOffset, scrollable)),
            animated: false
        )
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

private struct RelatedArticleRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(article.title)
                    .font(.miltonStoryTitle)
                    .foregroundColor(.miltonText)
                    .lineLimit(3)
                Text("By \(article.author) · \(article.publishedDate.miltonRelative)")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let thumbnail = article.thumbnailURL {
                RemoteImage(url: thumbnail, targetWidth: 90) { Color.miltonRule.opacity(0.5) }
                    .frame(width: 88, height: 66)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: MiltonLayout.cornerRadius))
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
