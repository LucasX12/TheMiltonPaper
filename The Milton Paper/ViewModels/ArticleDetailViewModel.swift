import Foundation
import Combine

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published var article: Article
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var relatedArticles: [Article] = []

    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared

    init(article: Article) {
        self.article = article
    }

    func toggleBookmark() async {
        guard let user = authService.currentUser else { return }
        do {
            if article.isBookmarked {
                try await firestoreService.removeBookmark(uid: user.uid, articleID: article.id)
                article.isBookmarked = false
            } else {
                try await firestoreService.addBookmark(uid: user.uid, articleID: article.id)
                article.isBookmarked = true
            }
            // Sync back to shared cache so the feed reflects the change
            ArticleService.shared.updateBookmark(id: article.id, isBookmarked: article.isBookmarked)
            NotificationCenter.default.post(
                name: .miltonBookmarkChanged,
                object: nil,
                userInfo: ["articleID": article.id, "isBookmarked": article.isBookmarked]
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadRelatedArticles() async {
        do {
            let all = try await ArticleService.shared.fetchArticles()
            relatedArticles = Array(
                all.filter { $0.category == article.category && $0.id != article.id }
                   .prefix(3)
            )
        } catch {
            // Non-critical — leave empty
        }
    }

    func checkBookmarkStatus() async {
        guard let user = authService.currentUser else {
            article.isBookmarked = false
            return
        }
        do {
            let ids = try await firestoreService.getBookmarkedArticleIDs(uid: user.uid)
            article.isBookmarked = ids.contains(article.id)
        } catch {
            // Non-critical — leave isBookmarked as-is
        }
    }
}
