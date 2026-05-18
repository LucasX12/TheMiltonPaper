import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false

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
                            Text("Welcome back")
                                .font(.miltonHeadline)
                                .foregroundColor(.miltonText)
                            Text("Sign in to your Milton Paper account")
                                .font(.miltonCaption)
                                .foregroundColor(.miltonSecondary)
                        }
                        .padding(.top, 48)

                        // Form
                        VStack(spacing: 16) {
                            MiltonTextField(title: "Email", text: $email, keyboardType: .emailAddress, textContentType: .emailAddress)
                            MiltonSecureField(title: "Password", text: $password)

                            // Forgot password
                            HStack {
                                Spacer()
                                Button("Forgot password?") { showForgotPassword = true }
                                    .font(.system(size: 14))
                                    .foregroundColor(.miltonPrimary)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Error
                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.miltonCaption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }

                        // Actions
                        VStack(spacing: 12) {
                            Button {
                                Task { await authViewModel.signIn(email: email, password: password) }
                            } label: {
                                Group {
                                    if authViewModel.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Sign In")
                                    }
                                }
                                .miltonPrimaryButton()
                            }
                            .disabled(authViewModel.isLoading)

                            Button {
                                dismiss()
                            } label: {
                                Text("Continue as Guest")
                                    .miltonSecondaryButton()
                            }
                        }
                        .padding(.horizontal, 24)

                        // Sign up link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .font(.miltonCaption)
                                .foregroundColor(.miltonSecondary)
                            Button("Sign up") { showSignUp = true }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.miltonPrimary)
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.miltonPrimary)
                }
            }
            .sheet(isPresented: $showSignUp) { SignUpView() }
            .sheet(isPresented: $showForgotPassword) { ForgotPasswordView() }
            .onChange(of: authViewModel.isAuthenticated) { _, authenticated in
                if authenticated { dismiss() }
            }
        }
    }
}

// MARK: - Reusable form fields

struct MiltonTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(12)
                .background(Color.miltonSurface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.miltonSecondary.opacity(0.25), lineWidth: 1))
        }
    }
}

struct MiltonSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
            SecureField(title, text: $text)
                .textContentType(.password)
                .padding(12)
                .background(Color.miltonSurface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.miltonSecondary.opacity(0.25), lineWidth: 1))
        }
    }
}
