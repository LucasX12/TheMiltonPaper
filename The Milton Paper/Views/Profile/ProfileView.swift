import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showLoginPrompt = false
    @State private var inProgressArticles: [ReadingRecord] = []
    @State private var recentlyReadArticles: [ReadingRecord] = []
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let user = authViewModel.currentUser {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(user.displayName).font(.miltonTitle)
                            Text(user.email).font(.miltonCaption).foregroundStyle(Color.miltonSecondary)
                            if user.role == .staff {
                                Text("Staff").font(.miltonCaption)
                            }
                        }.padding(.vertical, 10)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your reading, in one place").font(.miltonTitle)
                            Text("Sign in to save stories across your devices. Your reading history stays on this device.")
                                .font(.miltonBody).foregroundStyle(Color.miltonSecondary)
                            Button("Sign In") { showLoginPrompt = true }
                                .font(.headline).frame(minHeight: 44)
                        }.padding(.vertical, 10)
                    }
                }

                historySection("Continue reading", records: inProgressArticles,
                               empty: "Stories you start will appear here.")
                historySection("Recently read", records: recentlyReadArticles,
                               empty: "Stories you finish will appear here.")

                Section("Preferences") {
                    NavigationLink("Notification preferences") { NotificationSettingsView() }
                    if authViewModel.currentUser?.role == .staff {
                        NavigationLink("Staff dashboard") { StaffDashboardView() }
                    }
                }

                Section("The Milton Paper") {
                    NavigationLink("About The Milton Paper") { AboutView() }
                    Link("Contact support", destination: URL(string: "mailto:\(Config.supportEmail)")!)
                    LabeledContent("Version", value: appVersion)
                        .foregroundStyle(Color.miltonSecondary)
                    if let user = authViewModel.currentUser {
                        LabeledContent("Member since", value: user.joinedDate.miltonFormatted)
                            .foregroundStyle(Color.miltonSecondary)
                    }
                }

                if authViewModel.isAuthenticated {
                    Section {
                        Button("Sign Out", role: .destructive) { showSignOutConfirm = true }
                        Button("Delete Account", role: .destructive) { showDeleteConfirm = true }
                            .disabled(authViewModel.isLoading)
                    } footer: {
                        Text("Deleting your account permanently removes your sign-in and saved stories.")
                    }
                }
            }
            .listStyle(.plain)
            .listRowSpacing(0)
            .scrollContentBackground(.hidden)
            .editorialReadableColumn()
            .background(Color.miltonBackground.ignoresSafeArea())
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showLoginPrompt) { LoginView() }
            .onAppear { loadReadingHistory() }
            .alert("Sign Out?", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) { authViewModel.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can sign back in at any time. Your saved stories stay with your account.")
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        if !(await authViewModel.deleteAccount()) {
                            deleteErrorMessage = authViewModel.errorMessage ?? "Please try again."
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and saved stories. This cannot be undone.")
            }
            .alert("Couldn't Delete Account", isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { deleteErrorMessage = nil }
            } message: { Text(deleteErrorMessage ?? "") }
        }
    }

    private func historySection(_ title: String, records: [ReadingRecord], empty: String) -> some View {
        Section(title) {
            if records.isEmpty {
                Text(empty).font(.miltonCaption).foregroundStyle(Color.miltonSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(records.prefix(3)) { record in
                    NavigationLink { ReadingResumeView(record: record) } label: {
                        ReadingRecordRow(record: record)
                    }
                }
                if records.count > 3 {
                    NavigationLink("See all") {
                        ReadingHistoryListView(title: title, records: records)
                    }
                }
            }
        }
    }

    private func loadReadingHistory() {
        inProgressArticles = ReadingProgressService.shared.inProgress
        recentlyReadArticles = ReadingProgressService.shared.recentlyCompleted
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
            VStack(alignment: .trailing, spacing: 5) {
                Text(record.isCompleted ? "Read" : "\(Int(record.progress * 100))%")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.miltonRule)
                        Rectangle()
                            .fill(Color.miltonPrimary)
                            .frame(width: geometry.size.width * record.progress)
                    }
                }
                .frame(width: 40, height: 2)
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
            } catch {}
            isLoading = false
        }
    }
}
