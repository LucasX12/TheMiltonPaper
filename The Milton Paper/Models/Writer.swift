import Foundation

/// A masthead writer, edited in the Firebase console so photos and bios change
/// without an App Store release. Parsed leniently from `[String: Any]` for the
/// same reason `HomeModule` is: a mistyped field must cost that field, not the
/// whole directory.
struct Writer: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let bio: String?
    let role: String?
    let classYear: String?
    let photoURLString: String?
    let isEnabled: Bool

    var photoURL: URL? { HomeModuleField.webURL(photoURLString) }

    /// What shows under the name on the author page: "Managing Editor ’27".
    var credit: String? {
        let parts = [role, classYear].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var hasProfile: Bool { photoURL != nil || bio?.isEmpty == false }

    init(id: String, name: String, bio: String? = nil, role: String? = nil,
         classYear: String? = nil, photoURLString: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.bio = bio
        self.role = role
        self.classYear = classYear
        self.photoURLString = photoURLString
        self.isEnabled = isEnabled
    }

    init?(documentID: String, data: [String: Any]) {
        guard let name = HomeModuleField.string(data["name"]) else { return nil }
        self.init(
            id: documentID,
            name: name,
            bio: HomeModuleField.string(data["bio"]),
            role: HomeModuleField.string(data["role"]),
            classYear: HomeModuleField.string(data["classYear"]),
            photoURLString: HomeModuleField.string(data["photoURL"]),
            // A writer added to the directory is meant to be shown.
            isEnabled: HomeModuleField.bool(data["enabled"], default: true)
        )
    }

    /// Bylines arrive from RSS already cleaned — class years stripped, multiple
    /// authors joined with " and " — but spelling and spacing still vary, so
    /// both sides of the lookup are reduced to the same slug.
    static func slug(for name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return words.joined(separator: "-")
    }

    /// Splits a byline into individual writers. " and " is the only separator
    /// the parser emits (RSSParser normalises commas and ampersands to it).
    static func names(inByline byline: String) -> [String] {
        byline
            .components(separatedBy: " and ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
