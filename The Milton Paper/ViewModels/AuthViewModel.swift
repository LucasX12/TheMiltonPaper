import Foundation
import Combine

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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    private func validateEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }
}
