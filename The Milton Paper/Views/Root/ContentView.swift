import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showSplash = true
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                mainContent
            }
        }
        .environmentObject(authViewModel)
        .onReceive(NotificationCenter.default.publisher(for: .miltonNavigateToArticle)) { note in
            // Deep-link from push notification tap
            if note.userInfo?["articleId"] is String {
                selectedTab = 0 // switch to feed; ArticleFeedView handles navigation
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            ArticleFeedView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)

            BookmarksView()
                .tabItem { Label("Bookmarks", systemImage: "bookmark.fill") }
                .tag(2)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(.miltonPrimary)
    }
}
