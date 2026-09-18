import SwiftUI
import GoogleSignIn

@main
struct The_Milton_PaperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appConfiguration = AppConfiguration.shared

    init() {
        // Test launches read local flags with no Firebase dependency, so the
        // flags must be final before the first frame — otherwise the tab bar
        // renders once with default flags and rebuilds mid-interaction.
        if Config.isUITesting {
            AppConfiguration.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appConfiguration)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task { appConfiguration.start() }
        }
    }
}
