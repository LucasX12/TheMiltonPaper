import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.miltonBackground.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    if didSend {
                        sentConfirmation
                    } else {
                        form
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { authViewModel.errorMessage = nil }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.miltonPrimary)
                }
            }
        }
    }

    private var form: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.miltonAccent)
                Text("Forgot your password?")
                    .font(.miltonTitle)
                    .foregroundColor(.miltonText)
                Text("Enter your email and we'll send you a reset link.")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
                    .multilineTextAlignment(.center)
            }

            MiltonTextField(title: "Email", text: $email, keyboardType: .emailAddress, textContentType: .emailAddress)

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.miltonCaption)
                    .foregroundColor(.red)
            }

            Button {
                Task {
                    let success = await authViewModel.sendPasswordReset(email: email)
                    if success { didSend = true }
                }
            } label: {
                Group {
                    if authViewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send Reset Link")
                    }
                }
                .miltonPrimaryButton()
            }
            .disabled(authViewModel.isLoading)
        }
    }

    private var sentConfirmation: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.checkmark.fill")
                .font(.system(size: 48))
                .foregroundColor(.categorySports)
            Text("Check your email")
                .font(.miltonTitle)
                .foregroundColor(.miltonText)
            Text("A password reset link has been sent to \(email).")
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .miltonPrimaryButton()
            }
        }
    }
}
