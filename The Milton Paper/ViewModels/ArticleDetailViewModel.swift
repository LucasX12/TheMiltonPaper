import Foundation
import Combine

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published var article: Article
    @Published var isLoading = false
    @Published var errorMessage: String?

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
        } catch {
            errorMessage = error.localizedDescription
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
