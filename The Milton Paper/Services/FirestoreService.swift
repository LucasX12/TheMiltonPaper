import Foundation

// Mock Firestore service backed by UserDefaults.
// Replace method bodies with real Firestore calls once the Firebase SDK is added.
@MainActor
final class FirestoreService {
    static let shared = FirestoreService()

    private let bookmarkKeyPrefix = "miltonpaper.bookmarks."

    // MARK: - User

    func getUser(uid: String) async throws -> AppUser? {
        // Firebase: Firestore.firestore().collection("users").document(uid).getDocument()
        return AuthService.shared.currentUser
    }

    func updateUser(_ user: AppUser) async throws {
        // Firebase: Firestore.firestore().collection("users").document(user.uid).setData(...)
        AuthService.shared.updateCurrentUser(user)
    }

    // MARK: - Bookmarks

    func addBookmark(uid: String, articleID: String) async throws {
        var ids = getStoredBookmarks(uid: uid)
        if !ids.contains(articleID) {
            ids.append(articleID)
            saveBookmarks(ids, uid: uid)
        }
        try await syncBookmarksToUser(uid: uid, ids: ids)
    }

    func removeBookmark(uid: String, articleID: String) async throws {
        var ids = getStoredBookmarks(uid: uid)
        ids.removeAll { $0 == articleID }
        saveBookmarks(ids, uid: uid)
        try await syncBookmarksToUser(uid: uid, ids: ids)
    }

    func getBookmarkedArticleIDs(uid: String) async throws -> [String] {
        return getStoredBookmarks(uid: uid)
    }

    func isStaff(uid: String) async throws -> Bool {
        return AuthService.shared.currentUser?.role == .staff
    }

    /// Removes everything stored locally for a user (called on account deletion).
    func clearLocalData(uid: String) {
        UserDefaults.standard.removeObject(forKey: bookmarkKeyPrefix + uid)
    }

    // MARK: - Notification Topics

    func updateNotificationTopics(uid: String, topics: [String]) async throws {
        // Firebase: update user document with notificationTopics array
        guard var user = AuthService.shared.currentUser else { return }
        user = AppUser(
            uid: user.uid, email: user.email, displayName: user.displayName,
            role: user.role, joinedDate: user.joinedDate,
            bookmarkedArticleIDs: user.bookmarkedArticleIDs,
            notificationsEnabled: user.notificationsEnabled,
            notificationTopics: topics
        )
        AuthService.shared.updateCurrentUser(user)
    }

    // MARK: - Private

    private func getStoredBookmarks(uid: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: bookmarkKeyPrefix + uid) ?? []
    }

    private func saveBookmarks(_ ids: [String], uid: String) {
        UserDefaults.standard.set(ids, forKey: bookmarkKeyPrefix + uid)
    }

    private func syncBookmarksToUser(uid: String, ids: [String]) async throws {
        guard var user = AuthService.shared.currentUser, user.uid == uid else { return }
        user = AppUser(
            uid: user.uid, email: user.email, displayName: user.displayName,
            role: user.role, joinedDate: user.joinedDate,
            bookmarkedArticleIDs: ids,
            notificationsEnabled: user.notificationsEnabled,
            notificationTopics: user.notificationTopics
        )
        AuthService.shared.updateCurrentUser(user)
    }
}
