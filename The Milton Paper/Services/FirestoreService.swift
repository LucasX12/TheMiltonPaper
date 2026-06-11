import Foundation
import FirebaseFirestore

/// Cloud-backed user profiles and bookmarks, stored in `users/{uid}`.
///
/// Reads fall back to Firestore's local cache when offline. Bookmark and
/// preference writes are intentionally fire-and-forget: Firestore queues them
/// locally and syncs when connectivity returns, so the UI never hangs offline.
@MainActor
final class FirestoreService {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    // Older app versions stored bookmarks here; migrated to Firestore once.
    private let legacyBookmarkKeyPrefix = "miltonpaper.bookmarks."

    private func userRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    // MARK: - User

    /// Creates the user document on first sign-in and merges any bookmarks
    /// saved locally by older app versions.
    func ensureUserDocument(for user: AppUser) async {
        let ref = userRef(user.uid)
        do {
            let snapshot = try await ref.getDocument()
            if !snapshot.exists {
                try await ref.setData(userData(from: user))
            }
            let legacy = UserDefaults.standard.stringArray(forKey: legacyBookmarkKeyPrefix + user.uid) ?? []
            if !legacy.isEmpty {
                try await ref.setData(
                    ["bookmarkedArticleIDs": FieldValue.arrayUnion(legacy)], merge: true
                )
                UserDefaults.standard.removeObject(forKey: legacyBookmarkKeyPrefix + user.uid)
            }
        } catch {
            // Offline or rules issue — retried on next sign-in/launch
        }
    }

    func getUser(uid: String) async throws -> AppUser? {
        let snapshot = try await userRef(uid).getDocument()
        guard let data = snapshot.data() else { return nil }
        return appUser(uid: uid, data: data)
    }

    func updateUser(_ user: AppUser) async throws {
        try await userRef(user.uid).setData(userData(from: user), merge: true)
        AuthService.shared.updateCurrentUser(user)
    }

    /// Re-creates the profile document (used if account deletion fails midway).
    func restoreUser(_ user: AppUser) async throws {
        try await userRef(user.uid).setData(userData(from: user))
    }

    func isStaff(uid: String) async throws -> Bool {
        let snapshot = try await userRef(uid).getDocument()
        return (snapshot.data()?["role"] as? String) == UserRole.staff.rawValue
    }

    // MARK: - Bookmarks

    func addBookmark(uid: String, articleID: String) async throws {
        userRef(uid).setData(
            ["bookmarkedArticleIDs": FieldValue.arrayUnion([articleID])], merge: true
        )
        syncBookmarkToLocalUser(uid: uid, articleID: articleID, added: true)
    }

    func removeBookmark(uid: String, articleID: String) async throws {
        userRef(uid).setData(
            ["bookmarkedArticleIDs": FieldValue.arrayRemove([articleID])], merge: true
        )
        syncBookmarkToLocalUser(uid: uid, articleID: articleID, added: false)
    }

    func getBookmarkedArticleIDs(uid: String) async throws -> [String] {
        // Local mirror first: instant, and correct even before the next sync
        if let user = AuthService.shared.currentUser, user.uid == uid,
           !user.bookmarkedArticleIDs.isEmpty {
            return user.bookmarkedArticleIDs
        }
        let snapshot = try await userRef(uid).getDocument()
        return snapshot.data()?["bookmarkedArticleIDs"] as? [String] ?? []
    }

    // MARK: - Notification Preferences

    func updateNotificationSettings(uid: String, enabled: Bool, topics: [String]) async throws {
        userRef(uid).setData([
            "notificationsEnabled": enabled,
            "notificationTopics": topics
        ], merge: true)
        guard var user = AuthService.shared.currentUser, user.uid == uid else { return }
        user.notificationsEnabled = enabled
        user.notificationTopics = topics
        AuthService.shared.updateCurrentUser(user)
    }

    // MARK: - Account Deletion

    /// Removes the user's cloud data: profile document and leaderboard
    /// entries (which carry their display name).
    func deleteUserData(uid: String) async throws {
        try await userRef(uid).delete()
        let scores = try await db.collection("wordleScores")
            .whereField("uid", isEqualTo: uid)
            .getDocuments()
        for document in scores.documents {
            try await document.reference.delete()
        }
    }

    /// Removes everything stored locally for a user.
    func clearLocalData(uid: String) {
        UserDefaults.standard.removeObject(forKey: legacyBookmarkKeyPrefix + uid)
    }

    // MARK: - Private

    private func syncBookmarkToLocalUser(uid: String, articleID: String, added: Bool) {
        guard var user = AuthService.shared.currentUser, user.uid == uid else { return }
        if added {
            if !user.bookmarkedArticleIDs.contains(articleID) {
                user.bookmarkedArticleIDs.append(articleID)
            }
        } else {
            user.bookmarkedArticleIDs.removeAll { $0 == articleID }
        }
        AuthService.shared.updateCurrentUser(user)
    }

    private func userData(from user: AppUser) -> [String: Any] {
        [
            "email": user.email,
            "displayName": user.displayName,
            "role": user.role.rawValue,
            "joinedDate": Timestamp(date: user.joinedDate),
            "bookmarkedArticleIDs": user.bookmarkedArticleIDs,
            "notificationsEnabled": user.notificationsEnabled,
            "notificationTopics": user.notificationTopics
        ]
    }

    private func appUser(uid: String, data: [String: Any]) -> AppUser {
        AppUser(
            uid: uid,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "Reader",
            role: UserRole(rawValue: data["role"] as? String ?? "") ?? .reader,
            joinedDate: (data["joinedDate"] as? Timestamp)?.dateValue() ?? Date(),
            bookmarkedArticleIDs: data["bookmarkedArticleIDs"] as? [String] ?? [],
            notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true,
            notificationTopics: data["notificationTopics"] as? [String] ?? [Config.topicNewArticles]
        )
    }
}
