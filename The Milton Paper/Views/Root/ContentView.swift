import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @ObservedObject private var appConfiguration = AppConfiguration.shared
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            ArticleFeedView()
                .tabItem { Label("Today", systemImage: "newspaper") }
                .tag(AppTab.today)

            SectionsView()
                .tabItem { Label("Sections", systemImage: "list.bullet") }
                .tag(AppTab.sections)

            if appConfiguration.flags.showTMPlay {
                WordlePageView()
                    .id(authViewModel.currentUser?.uid ?? "guest")
                    .tabItem { Label("TMPlay", systemImage: "square.grid.3x3.fill") }
                    .tag(AppTab.tmplay)
            }

            BookmarksView()
                .tabItem { Label("Saved", systemImage: "bookmark") }
                .tag(AppTab.saved)

            ProfileView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(AppTab.you)
        }
        .tint(.miltonPrimary)
        .environmentObject(authViewModel)
        .onChange(of: appConfiguration.flags.showTMPlay) { _, isVisible in
            if !isVisible {
                selectedTab = AppTab.validSelection(selectedTab, flags: appConfiguration.flags)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .miltonNavigateToArticle)) { note in
            if note.userInfo?["articleId"] is String { selectedTab = .today }
        }
        .onReceive(NotificationCenter.default.publisher(for: .miltonNavigateToCategory)) { _ in
            selectedTab = .today
        }
    }
}
