import Foundation
import UIKit
import UserNotifications
import os

final class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    func registerFCMToken(_ token: String) {
        // Firebase: Messaging.messaging().apnsToken = ...
        // Store in Firestore user document for server-side targeting
        os_log("[FCM] FCM token registered", log: OSLog.default, type: .debug)
    }

    func subscribeToTopic(_ topic: String) {
        // Firebase: Messaging.messaging().subscribe(toTopic: topic)
        os_log("[FCM] Subscribed to topic", log: OSLog.default, type: .debug)
    }

    func unsubscribeFromTopic(_ topic: String) {
        // Firebase: Messaging.messaging().unsubscribe(fromTopic: topic)
        os_log("[FCM] Unsubscribed from topic", log: OSLog.default, type: .debug)
    }

    func syncTopics(enabled: Bool, topics: [String]) {
        if enabled {
            topics.forEach { subscribeToTopic($0) }
        } else {
            [Config.topicNewArticles, Config.topicNews,
             Config.topicOpinion, Config.topicSports, Config.topicEditorial]
                .forEach { unsubscribeFromTopic($0) }
        }
    }
}
