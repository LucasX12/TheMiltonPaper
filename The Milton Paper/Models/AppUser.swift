import Foundation

struct AppUser: Codable, Identifiable {
    let uid: String
    let email: String
    let displayName: String
    let role: UserRole
    let joinedDate: Date
    var bookmarkedArticleIDs: [String]
    var notificationsEnabled: Bool
    var notificationTopics: [String]

    var id: String { uid }
}

enum UserRole: String, Codable {
    case reader
    case staff
}
