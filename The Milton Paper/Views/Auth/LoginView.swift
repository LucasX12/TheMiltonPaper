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
                            Text("The Milton Paper")
                                .font(.custom("OldEnglishTextMT", size: 36))
                                .foregroundColor(.miltonPrimary)
                            Rectangle()
                                .fill(Color.miltonPrimary.opacity(0.2))
                                .frame(height: 1)
                                .padding(.horizontal, 20)
                            Text("Sign in to your account")
                                .font(.miltonCaption)
                                .foregroundColor(.miltonSecondary)
                                .padding(.top, 2)
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
                                HStack {
                                    Spacer(minLength: 0)
                                    if authViewModel.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Sign In")
                                    }
                                    Spacer(minLength: 0)
                                }
                                .miltonPrimaryButton()
                            }
                            .disabled(authViewModel.isLoading)

                            // Divider
                            HStack {
                                Rectangle().fill(Color.miltonSecondary.opacity(0.25)).frame(height: 1)
                                Text("or").font(.miltonCaption).foregroundColor(.miltonSecondary)
                                Rectangle().fill(Color.miltonSecondary.opacity(0.25)).frame(height: 1)
                            }

                            Button {
                                Task { await authViewModel.signInWithGoogle() }
                            } label: {
                                HStack(spacing: 10) {
                                    GoogleGIcon(size: 20)
                                    Text("Continue with Google")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.miltonText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.miltonSurface)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.miltonSecondary.opacity(0.3), lineWidth: 1))
                            }
                            .disabled(authViewModel.isLoading)

                            Button {
                                Task { await authViewModel.signInWithApple() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 17, weight: .medium))
                                    Text("Continue with Apple")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.miltonText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.miltonSurface)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.miltonSecondary.opacity(0.3), lineWidth: 1))
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
            .onAppear { authViewModel.errorMessage = nil }
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

// MARK: - Google G logo

private struct GoogleGIcon: View {
    let size: CGFloat

    var body: some View {
        Image("google_logo")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
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
    var textContentType: UITextContentType = .password

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
            SecureField(title, text: $text)
                .textContentType(textContentType)
                .padding(12)
                .background(Color.miltonSurface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.miltonSecondary.opacity(0.25), lineWidth: 1))
        }
    }
}
