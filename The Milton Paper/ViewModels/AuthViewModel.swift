import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showLoginSheet = false

    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        authService.$currentUser
            .assign(to: &$currentUser)
        authService.$isAuthenticated
            .assign(to: &$isAuthenticated)
    }

    func signIn(email: String, password: String) async {
        guard validateEmail(email) else {
            errorMessage = AuthError.invalidEmail.errorDescription
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signIn(email: email, password: password)
            showLoginSheet = false
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func signUp(email: String, password: String, displayName: String) async {
        guard validateEmail(email) else {
            errorMessage = AuthError.invalidEmail.errorDescription
            return
        }
        guard password.count >= 6 else {
            errorMessage = AuthError.weakPassword.errorDescription
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signUp(email: email, password: password, displayName: displayName)
            _ = await NotificationService.shared.requestPermission()
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signInWithGoogle()
            showLoginSheet = false
        } catch {
            if !isCancellation(error) { errorMessage = friendlyError(error) }
        }
        isLoading = false
    }

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signInWithApple()
            showLoginSheet = false
        } catch {
            if !isCancellation(error) { errorMessage = friendlyError(error) }
        }
        isLoading = false
    }

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        guard validateEmail(email) else {
            errorMessage = AuthError.invalidEmail.errorDescription
            return false
        }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.sendPasswordReset(email: email)
            isLoading = false
            return true
        } catch {
            errorMessage = friendlyError(error)
            isLoading = false
            return false
        }
    }

    private func validateEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    private func isCancellation(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == "com.google.GIDSignIn" && ns.code == -5 { return true }
        if ns.domain == "com.apple.AuthenticationServices.AuthorizationError" { return true }
        return false
    }

    private func friendlyError(_ error: Error) -> String {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return error.localizedDescription
        }
        switch code {
        case .userNotFound:       return "No account found with that email."
        case .wrongPassword:      return "Incorrect password. Please try again."
        case .invalidCredential:  return "Incorrect email or password."
        case .emailAlreadyInUse:  return "An account with this email already exists."
        case .invalidEmail:       return "Please enter a valid email address."
        case .weakPassword:       return "Password must be at least 6 characters."
        case .networkError:       return "No internet connection. Please check your network."
        case .tooManyRequests:    return "Too many attempts. Please try again in a moment."
        case .userDisabled:       return "This account has been disabled. Contact support."
        default:                  return error.localizedDescription
        }
    }
}
