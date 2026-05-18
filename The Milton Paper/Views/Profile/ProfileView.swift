import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showLoginPrompt = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.miltonBackground.ignoresSafeArea()

                if authViewModel.isAuthenticated, let user = authViewModel.currentUser {
                    authenticatedContent(user: user)
                } else {
                    unauthenticatedContent
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.miltonSurface, for: .navigationBar)
            .sheet(isPresented: $showLoginPrompt) { LoginView() }
        }
    }

    // MARK: - Authenticated

    private func authenticatedContent(user: AppUser) -> some View {
        List {
            // Avatar + name
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.miltonPrimary)
                            .frame(width: 56, height: 56)
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.custom("Georgia", size: 22).weight(.semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.miltonText)
                        Text(user.email)
                            .font(.miltonCaption)
                            .foregroundColor(.miltonSecondary)
                    }
                    Spacer()
                    roleBadge(user.role)
                }
                .padding(.vertical, 4)
            }

            // Settings
            Section("Preferences") {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("Notification Preferences", systemImage: "bell")
                        .foregroundColor(.miltonText)
                }

                if user.role == .staff {
                    NavigationLink {
                        StaffDashboardView()
                    } label: {
                        Label("Staff Dashboard", systemImage: "briefcase")
                            .foregroundColor(.miltonText)
                    }
                }
            }

            // About
            Section("About") {
                LabeledContent("Member since") {
                    Text(user.joinedDate.miltonFormatted)
                        .font(.miltonCaption)
                        .foregroundColor(.miltonSecondary)
                }
                Link(destination: URL(string: "mailto:\(Config.supportEmail)")!) {
                    Label("Contact Support", systemImage: "envelope")
                        .foregroundColor(.miltonText)
                }
                LabeledContent("Version") {
                    Text(appVersion)
                        .font(.miltonCaption)
                        .foregroundColor(.miltonSecondary)
                }
            }

            // Sign out
            Section {
                Button(role: .destructive) {
                    authViewModel.signOut()
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.miltonBackground)
    }

    // MARK: - Unauthenticated

    private var unauthenticatedContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundColor(.miltonSecondary.opacity(0.3))

            VStack(spacing: 8) {
                Text("You're not signed in")
                    .font(.miltonTitle)
                    .foregroundColor(.miltonText)
                Text("Sign in to manage bookmarks, notifications, and your reading history.")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Sign In") { showLoginPrompt = true }
                .miltonPrimaryButton()
                .padding(.horizontal, 48)

            Text("v\(appVersion)")
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary.opacity(0.6))
                .padding(.top, 40)
        }
    }

    // MARK: - Helpers

    private func roleBadge(_ role: UserRole) -> some View {
        Text(role == .staff ? "Staff" : "Reader")
            .font(.miltonLabel)
            .foregroundColor(role == .staff ? .miltonAccent : .miltonSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    role == .staff ? Color.miltonAccent.opacity(0.15) : Color.miltonSecondary.opacity(0.1)
                )
            )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
