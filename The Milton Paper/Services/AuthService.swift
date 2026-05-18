import Foundation
import Combine

// Mock authentication service backed by UserDefaults.
// Replace with a Firebase-backed implementation once FirebaseAuth is configured.
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isAuthenticated = false

    private let userDefaultsKey = "miltonpaper.currentUser"
    private let usersStoreKey   = "miltonpaper.usersStore"

    init() {
        restoreSession()
    }

    // MARK: - Public

    func signIn(email: String, password: String) async throws {
        try await Task.sleep(nanoseconds: 600_000_000) // simulate network latency
        guard let user = storedUser(for: email) else {
            throw AuthError.userNotFound
        }
        persist(user: user)
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        try await Task.sleep(nanoseconds: 800_000_000)
        if storedUser(for: email) != nil {
            throw AuthError.emailAlreadyInUse
        }
        let newUser = AppUser(
            uid: UUID().uuidString,
            email: email,
            displayName: displayName,
            role: .reader,
            joinedDate: Date(),
            bookmarkedArticleIDs: [],
            notificationsEnabled: true,
            notificationTopics: [Config.topicNewArticles]
        )
        storeUser(newUser)
        persist(user: newUser)
    }

    func signOut() throws {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    func sendPasswordReset(email: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        // Firebase: Auth.auth().sendPasswordReset(withEmail: email)
        // Mock: no-op — in real use, Firebase handles delivery
    }

    func updateCurrentUser(_ user: AppUser) {
        storeUser(user)
        persist(user: user)
    }

    // MARK: - Private

    private func restoreSession() {
        guard
            let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let user = try? JSONDecoder().decode(AppUser.self, from: data)
        else { return }
        currentUser = user
        isAuthenticated = true
    }

    private func persist(user: AppUser) {
        currentUser = user
        isAuthenticated = true
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func storedUser(for email: String) -> AppUser? {
        guard
            let data = UserDefaults.standard.data(forKey: usersStoreKey),
            let dict = try? JSONDecoder().decode([String: AppUser].self, from: data)
        else { return nil }
        return dict[email]
    }

    private func storeUser(_ user: AppUser) {
        var dict: [String: AppUser] = [:]
        if let data = UserDefaults.standard.data(forKey: usersStoreKey),
           let existing = try? JSONDecoder().decode([String: AppUser].self, from: data) {
            dict = existing
        }
        dict[user.email] = user
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: usersStoreKey)
        }
    }
}

enum AuthError: LocalizedError {
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .userNotFound:      return "No account found with that email address."
        case .emailAlreadyInUse: return "An account with this email already exists."
        case .weakPassword:      return "Password must be at least 6 characters."
        case .invalidEmail:      return "Please enter a valid email address."
        }
    }
}
