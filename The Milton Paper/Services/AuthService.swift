import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit
import AuthenticationServices
import CryptoKit

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
        // The auth-state listener fired before the name was committed, so the
        // published user still says "Reader" — refresh it from the live user.
        currentUser = AppUser(from: result.user)
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// Permanently deletes the Firebase account and clears local per-user data.
    /// Firebase may throw `requiresRecentLogin` if the session is stale.
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        try await user.delete()
        GIDSignIn.sharedInstance.signOut()
        FirestoreService.shared.clearLocalData(uid: uid)
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
        let authResult = try await Auth.auth().signIn(with: credential)
        // Sync display name from Google profile if Firebase doesn't have one yet
        if let googleName = result.user.profile?.name,
           authResult.user.displayName == nil || authResult.user.displayName!.isEmpty {
            let req = authResult.user.createProfileChangeRequest()
            req.displayName = googleName
            try? await req.commitChanges()
        }
    }

    // MARK: - Apple Sign-In

    func signInWithApple() async throws {
        let nonce = randomNonceString()
        let hashedNonce = sha256(nonce)
        let appleCredential = try await requestAppleCredential(hashedNonce: hashedNonce)
        guard let idToken = appleCredential.identityToken,
              let idTokenString = String(data: idToken, encoding: .utf8) else {
            throw AuthError.appleSignInFailed
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        try await Auth.auth().signIn(with: credential)
    }

    private func requestAppleCredential(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = AppleSignInCoordinator(continuation: continuation)
            AppleSignInCoordinator.active = coordinator

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator
            controller.performRequests()
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                // SystemRandomNumberGenerator is also cryptographically secure
                randoms = (0..<16).map { _ in UInt8.random(in: .min ... .max) }
            }
            for r in randoms where remaining > 0 {
                if r < charset.count { result.append(charset[Int(r)]); remaining -= 1 }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
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
    case appleSignInFailed

    var errorDescription: String? {
        switch self {
        case .userNotFound:        return "No account found with that email address."
        case .emailAlreadyInUse:   return "An account with this email already exists."
        case .weakPassword:        return "Password must be at least 6 characters."
        case .invalidEmail:        return "Please enter a valid email address."
        case .configurationError:  return "Google Sign-In is not configured. Please re-download GoogleService-Info.plist with Google Sign-In enabled."
        case .googleSignInFailed:  return "Google Sign-In failed. Please try again."
        case .appleSignInFailed:   return "Apple Sign-In failed. Please try again."
        }
    }
}

// MARK: - Apple Sign-In coordinator

private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    static var active: AppleSignInCoordinator?

    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        Self.active = nil
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation.resume(throwing: AuthError.appleSignInFailed)
            return
        }
        continuation.resume(returning: credential)
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        Self.active = nil
        continuation.resume(throwing: error)
    }
}
