import SwiftUI
import os

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showLoginPrompt = false
    @State private var inProgressArticles: [ReadingRecord] = []
    @State private var recentlyReadArticles: [ReadingRecord] = []

    private let listCap = 3

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
            .onAppear { loadReadingHistory() }
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

            // Pick up where you left off
            Section("Pick Up Where You Left Off") {
                if inProgressArticles.isEmpty {
                    Text("No articles in progress")
                        .font(.miltonCaption)
                        .foregroundColor(.miltonSecondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(inProgressArticles.prefix(listCap)) { record in
                        NavigationLink {
                            ReadingResumeView(record: record)
                        } label: {
                            ReadingRecordRow(record: record)
                        }
                    }
                    if inProgressArticles.count > listCap {
                        NavigationLink {
                            ReadingHistoryListView(title: "In Progress", records: inProgressArticles)
                        } label: {
                            Text("See All (\(inProgressArticles.count))")
                                .font(.miltonCaption)
                                .foregroundColor(.miltonPrimary)
                        }
                    }
                }
            }

            // Recently read
            Section("Recently Read") {
                if recentlyReadArticles.isEmpty {
                    Text("Articles you finish will appear here")
                        .font(.miltonCaption)
                        .foregroundColor(.miltonSecondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(recentlyReadArticles.prefix(listCap)) { record in
                        NavigationLink {
                            ReadingResumeView(record: record)
                        } label: {
                            ReadingRecordRow(record: record)
                        }
                    }
                    if recentlyReadArticles.count > listCap {
                        NavigationLink {
                            ReadingHistoryListView(title: "Recently Read", records: recentlyReadArticles)
                        } label: {
                            Text("See All (\(recentlyReadArticles.count))")
                                .font(.miltonCaption)
                                .foregroundColor(.miltonPrimary)
                        }
                    }
                }
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
                Button {
                    if let url = URL(string: "mailto:\(Config.supportEmail)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
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
        ScrollView {
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

                readingHistorySection
                    .padding(.top, 8)

                Text("v\(appVersion)")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary.opacity(0.6))
                    .padding(.top, 16)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
    }

    private var readingHistorySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // In progress
            VStack(alignment: .leading, spacing: 10) {
                Text("Pick Up Where You Left Off")
                    .font(.miltonLabel)
                    .foregroundColor(.miltonSecondary)
                    .padding(.horizontal, 16)

                if inProgressArticles.isEmpty {
                    Text("No articles in progress")
                        .font(.miltonCaption)
                        .foregroundColor(.miltonSecondary.opacity(0.6))
                        .padding(.horizontal, 16)
                } else {
                    ForEach(inProgressArticles.prefix(listCap)) { record in
                        NavigationLink {
                            ReadingResumeView(record: record)
                        } label: {
                            ReadingRecordRow(record: record)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                    if inProgressArticles.count > listCap {
                        NavigationLink {
                            ReadingHistoryListView(title: "In Progress", records: inProgressArticles)
                        } label: {
                            Text("See All (\(inProgressArticles.count))")
                                .font(.miltonCaption)
                                .foregroundColor(.miltonPrimary)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Recently read
            VStack(alignment: .leading, spacing: 10) {
                Text("Recently Read")
                    .font(.miltonLabel)
                    .foregroundColor(.miltonSecondary)
                    .padding(.horizontal, 16)

                if recentlyReadArticles.isEmpty {
                    Text("Articles you finish will appear here")
                        .font(.miltonCaption)
                        .foregroundColor(.miltonSecondary.opacity(0.6))
                        .padding(.horizontal, 16)
                } else {
                    ForEach(recentlyReadArticles.prefix(listCap)) { record in
                        NavigationLink {
                            ReadingResumeView(record: record)
                        } label: {
                            ReadingRecordRow(record: record)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                    if recentlyReadArticles.count > listCap {
                        NavigationLink {
                            ReadingHistoryListView(title: "Recently Read", records: recentlyReadArticles)
                        } label: {
                            Text("See All (\(recentlyReadArticles.count))")
                                .font(.miltonCaption)
                                .foregroundColor(.miltonPrimary)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func loadReadingHistory() {
        inProgressArticles = ReadingProgressService.shared.inProgress
        recentlyReadArticles = ReadingProgressService.shared.recentlyCompleted
    }

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

// MARK: - Reading Record Row

struct ReadingRecordRow: View {
    let record: ReadingRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.miltonBody)
                    .foregroundColor(.miltonText)
                    .lineLimit(2)
                Text(record.author)
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
            }
            Spacer()
            VStack(spacing: 3) {
                CircularProgressRing(progress: record.progress, size: 28, lineWidth: 3)
                if !record.isCompleted {
                    Text("~\(Int(record.progress * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.miltonSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reading History List (See All)

struct ReadingHistoryListView: View {
    let title: String
    let records: [ReadingRecord]

    var body: some View {
        List {
            ForEach(records) { record in
                NavigationLink {
                    ReadingResumeView(record: record)
                } label: {
                    ReadingRecordRow(record: record)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.miltonBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.miltonSurface, for: .navigationBar)
    }
}

// MARK: - Reading Resume View

struct ReadingResumeView: View {
    let record: ReadingRecord
    @State private var article: Article?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()
            if let article {
                ArticleDetailView(
                    article: article,
                    initialScrollOffset: record.isCompleted ? 0 : record.scrollOffset
                )
            } else if isLoading {
                VStack { Spacer(); ProgressView(); Spacer() }
            } else {
                // Fallback if article is no longer in the feed
                WebPageView(url: record.articleURL)
                    .navigationTitle(record.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            do {
                article = try await ArticleService.shared.fetchArticle(id: record.id)
            } catch {
                os_log("[Reading Resume] Failed to fetch article %@: %@", log: OSLog.default, type: .error, record.id, error.localizedDescription)
            }
            isLoading = false
        }
    }
}
