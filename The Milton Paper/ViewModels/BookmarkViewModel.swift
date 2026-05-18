import Foundation
import Combine

@MainActor
final class BookmarkViewModel: ObservableObject {
    @Published var bookmarkedArticles: [Article] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private let articleService   = ArticleService.shared
    private let authService      = AuthService.shared

    func loadBookmarks() async {
        guard let uid = authService.currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil
        do {
            let ids = try await firestoreService.getBookmarkedArticleIDs(uid: uid)
            let allArticles = try await articleService.fetchArticles()
            bookmarkedArticles = allArticles
                .filter { ids.contains($0.id) }
                .map { var a = $0; a.isBookmarked = true; return a }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func removeBookmark(article: Article) async {
        guard let uid = authService.currentUser?.uid else { return }
        do {
            try await firestoreService.removeBookmark(uid: uid, articleID: article.id)
            bookmarkedArticles.removeAll { $0.id == article.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeBookmarks(at offsets: IndexSet) async {
        let articlesToRemove = offsets.map { bookmarkedArticles[$0] }
        for article in articlesToRemove {
            await removeBookmark(article: article)
        }
    }
}
