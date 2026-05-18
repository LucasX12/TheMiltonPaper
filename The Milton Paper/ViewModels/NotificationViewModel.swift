import Foundation
import Combine

@MainActor
final class NotificationViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool = false
    @Published var enabledTopics: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let availableTopics: [(label: String, topic: String)] = [
        ("New Articles",   Config.topicNewArticles),
        ("News",           Config.topicNews),
        ("Opinion",        Config.topicOpinion),
        ("Sports",         Config.topicSports),
        ("Editorial",      Config.topicEditorial),
    ]

    private let notificationService = NotificationService.shared
    private let firestoreService    = FirestoreService.shared
    private let authService         = AuthService.shared

    func load() {
        guard let user = authService.currentUser else { return }
        notificationsEnabled = user.notificationsEnabled
        enabledTopics = Set(user.notificationTopics)
    }

    func toggleNotifications(enabled: Bool) async {
        if enabled {
            let granted = await notificationService.requestPermission()
            notificationsEnabled = granted
        } else {
            notificationsEnabled = false
        }
        await save()
    }

    func toggleTopic(_ topic: String, enabled: Bool) async {
        if enabled {
            enabledTopics.insert(topic)
            notificationService.subscribeToTopic(topic)
        } else {
            enabledTopics.remove(topic)
            notificationService.unsubscribeFromTopic(topic)
        }
        await save()
    }

    // MARK: - Private

    private func save() async {
        guard let uid = authService.currentUser?.uid else { return }
        let topics = notificationsEnabled ? Array(enabledTopics) : []
        notificationService.syncTopics(enabled: notificationsEnabled, topics: topics)
        do {
            try await firestoreService.updateNotificationTopics(uid: uid, topics: topics)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
