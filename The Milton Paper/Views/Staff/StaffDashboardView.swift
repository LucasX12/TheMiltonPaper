import SwiftUI

struct StaffDashboardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var recentArticles: [Article] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            if authViewModel.currentUser?.role != .staff {
                unauthorizedView
            } else {
                dashboardContent
            }
        }
        .navigationTitle("Staff Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadArticles() }
    }

    // MARK: - Content

    private var dashboardContent: some View {
        List {
            // Quick links
            Section("Quick Links") {
                if let squarespaceURL = URL(string: "https://account.squarespace.com") {
                    Link(destination: squarespaceURL) {
                        Label("Open Squarespace Editor", systemImage: "pencil.and.outline")
                            .foregroundColor(.miltonText)
                    }
                }
                if let firebaseURL = URL(string: "https://console.firebase.google.com") {
                    Link(destination: firebaseURL) {
                        Label("Firebase Console", systemImage: "flame")
                            .foregroundColor(.miltonText)
                    }
                }
            }

            // Stats summary
            Section("At a Glance") {
                statsRow(label: "Published Articles", value: "\(recentArticles.count)", icon: "doc.text.fill")
                statsRow(label: "Latest Category", value: recentArticles.first?.category ?? "—", icon: "tag.fill")
                statsRow(label: "Latest Author", value: recentArticles.first?.author ?? "—", icon: "person.fill")
            }

            // Recent articles
            Section("Recent Articles") {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.miltonBackground)
                } else {
                    ForEach(recentArticles.prefix(10)) { article in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                TagChipView(category: article.category)
                                Spacer()
                                Text(article.publishedDate.miltonRelative)
                                    .font(.miltonCaption)
                                    .foregroundColor(.miltonSecondary)
                            }
                            Text(article.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.miltonText)
                            Text("by \(article.author)")
                                .font(.miltonCaption)
                                .foregroundColor(.miltonSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.miltonBackground)
        .refreshable { await loadArticles() }
    }

    private var unauthorizedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundColor(.miltonSecondary)
            Text("Staff Only")
                .font(.miltonTitle)
                .foregroundColor(.miltonText)
            Text("This area is restricted to Milton Paper staff members.")
                .font(.miltonCaption)
                .foregroundColor(.miltonSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func statsRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.miltonText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.miltonPrimary)
        }
    }

    private func loadArticles() async {
        isLoading = true
        recentArticles = (try? await ArticleService.shared.fetchArticles()) ?? []
        isLoading = false
    }
}
