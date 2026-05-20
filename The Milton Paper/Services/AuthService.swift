import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isAuthenticated = false

    private var stateListener: AuthStateDidChangeListenerHandle?

    init() {
        stateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                self?.currentUser = firebaseUser.map { AppUser(from: $0) }
                self?.isAuthenticated = firebaseUser != nil
            }
        }
    }

    // MARK: - Email / Password

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let request = result.user.createProfileChangeRequest()
        request.displayName = displayName
        try await request.commitChanges()
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        else {
            throw AuthError.googleSignInFailed
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.googleSignInFailed
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Local state update (used by FirestoreService)

    func updateCurrentUser(_ user: AppUser) {
        currentUser = user
    }
}

// MARK: - AppUser from Firebase user

private extension AppUser {
    init(from firebaseUser: FirebaseAuth.User) {
        self.uid = firebaseUser.uid
        self.email = firebaseUser.email ?? ""
        self.displayName = firebaseUser.displayName ?? "Reader"
        self.role = .reader
        self.joinedDate = firebaseUser.metadata.creationDate ?? Date()
        self.bookmarkedArticleIDs = []
        self.notificationsEnabled = true
        self.notificationTopics = [Config.topicNewArticles]
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case invalidEmail
    case configurationError
    case googleSignInFailed

    var errorDescription: String? {
        switch self {
        case .userNotFound:        return "No account found with that email address."
        case .emailAlreadyInUse:   return "An account with this email already exists."
        case .weakPassword:        return "Password must be at least 6 characters."
        case .invalidEmail:        return "Please enter a valid email address."
        case .configurationError:  return "Google Sign-In is not configured. Please re-download GoogleService-Info.plist with Google Sign-In enabled."
        case .googleSignInFailed:  return "Google Sign-In failed. Please try again."
        }
    }
}
