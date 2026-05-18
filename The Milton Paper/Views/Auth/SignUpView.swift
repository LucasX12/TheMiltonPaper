import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var passwordMismatch = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.miltonBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "newspaper.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.miltonPrimary)
                            Text("Create Account")
                                .font(.miltonHeadline)
                                .foregroundColor(.miltonText)
                            Text("Join The Milton Paper community")
                                .font(.miltonCaption)
                                .foregroundColor(.miltonSecondary)
                        }
                        .padding(.top, 40)

                        // Form
                        VStack(spacing: 16) {
                            MiltonTextField(title: "Display Name", text: $displayName, textContentType: .name)
                            MiltonTextField(title: "Email", text: $email, keyboardType: .emailAddress, textContentType: .emailAddress)
                            MiltonSecureField(title: "Password", text: $password)
                            MiltonSecureField(title: "Confirm Password", text: $confirmPassword)
                        }
                        .padding(.horizontal, 24)

                        // Errors
                        VStack(spacing: 4) {
                            if passwordMismatch {
                                Text("Passwords do not match.")
                                    .font(.miltonCaption)
                                    .foregroundColor(.red)
                            }
                            if let error = authViewModel.errorMessage {
                                Text(error)
                                    .font(.miltonCaption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Actions
                        Button {
                            submit()
                        } label: {
                            Group {
                                if authViewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Create Account")
                                }
                            }
                            .miltonPrimaryButton()
                        }
                        .disabled(authViewModel.isLoading)
                        .padding(.horizontal, 24)

                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.miltonPrimary)
                }
            }
            .onChange(of: authViewModel.isAuthenticated) { _, authenticated in
                if authenticated { dismiss() }
            }
        }
    }

    private func submit() {
        passwordMismatch = password != confirmPassword
        guard !passwordMismatch else { return }
        Task { await authViewModel.signUp(email: email, password: password, displayName: displayName) }
    }
}
