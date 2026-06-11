import UIKit
import UserNotifications
import FirebaseCore
import GoogleSignIn
import os

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - APNs

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        os_log("[APNs] Device token registered", log: OSLog.default, type: .debug)
        NotificationService.shared.registerFCMToken(token)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log("[APNs] Registration failed: %@", log: OSLog.default, type: .error, error.localizedDescription)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let articleId = info["articleId"] as? String {
            NotificationCenter.default.post(
                name: .miltonNavigateToArticle,
                object: nil,
                userInfo: ["articleId": articleId]
            )
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let miltonNavigateToArticle = Notification.Name("miltonNavigateToArticle")
}
