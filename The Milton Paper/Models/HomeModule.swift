import Foundation

/// `FirebaseFirestore.Timestamp` is made to conform in `HomeModuleService`, so
/// this file — and therefore the parsing tests — never import the Firebase SDK.
protocol FirestoreDateValue {
    func dateValue() -> Date
}

/// Where a module or one of its cards sends the reader.
enum HomeModuleDestination: Hashable {
    case article(String)
    case web(URL)
    case none
}

// MARK: - Field coercion

/// Every value in a module document is typed by hand in the Firebase console,
/// so each field is read leniently: a number typed as text, or a stray trailing
/// space, must not cost the editor a front-page module.
enum HomeModuleField {
    static func string(_ any: Any?) -> String? {
        let raw: String?
        switch any {
        case let value as String: raw = value
        case let value as NSNumber: raw = value.stringValue
        default: raw = nil
        }
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func bool(_ any: Any?, default fallback: Bool) -> Bool {
        switch any {
        case let value as Bool: return value
        case let value as NSNumber: return value.boolValue
        case let value as String:
            switch value.trimmingCharacters(in: .whitespaces).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return fallback
            }
        default: return fallback
        }
    }

    static func double(_ any: Any?, default fallback: Double) -> Double {
        switch any {
        case let value as NSNumber: return value.doubleValue
        case let value as String: return Double(value.trimmingCharacters(in: .whitespaces)) ?? fallback
        default: return fallback
        }
    }

    static func date(_ any: Any?) -> Date? {
        switch any {
        case let value as FirestoreDateValue: return value.dateValue()
        case let value as Date: return value
        case let value as NSNumber: return Date(timeIntervalSince1970: value.doubleValue)
        case let value as String: return ISO8601DateFormatter().date(from: value)
        default: return nil
        }
    }

    /// Only http(s) with a host becomes a live destination. Anything else typed
    /// into the console — `javascript:`, `file:`, a half-typed address — is
    /// dropped rather than handed to a reader's tap.
    static func webURL(_ string: String?) -> URL? {
        guard let string,
              let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    static func destination(articleID: String?, linkURL: URL?) -> HomeModuleDestination {
        if let articleID { return .article(articleID) }
        if let linkURL { return .web(linkURL) }
        return .none
    }
}

// MARK: - Items

/// One card inside a rail module, stored in `homeModules/{id}/items`.
struct HomeModuleItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let imageURLString: String?
    let linkURLString: String?
    let articleID: String?
    let order: Double
    let isEnabled: Bool

    var imageURL: URL? { HomeModuleField.webURL(imageURLString) }
    var linkURL: URL? { HomeModuleField.webURL(linkURLString) }
    var destination: HomeModuleDestination {
        HomeModuleField.destination(articleID: articleID, linkURL: linkURL)
    }
    var isRenderable: Bool { isEnabled && !title.isEmpty }

    init(id: String, title: String, subtitle: String? = nil, imageURLString: String? = nil,
         linkURLString: String? = nil, articleID: String? = nil,
         order: Double = 1_000, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURLString = imageURLString
        self.linkURLString = linkURLString
        self.articleID = articleID
        self.order = order
        self.isEnabled = isEnabled
    }

    init?(documentID: String, data: [String: Any]) {
        guard let title = HomeModuleField.string(data["title"]) else { return nil }
        self.init(
            id: documentID,
            title: title,
            subtitle: HomeModuleField.string(data["subtitle"]),
            imageURLString: HomeModuleField.string(data["imageURL"]),
            linkURLString: HomeModuleField.string(data["linkURL"]),
            articleID: HomeModuleField.string(data["articleID"]),
            order: HomeModuleField.double(data["order"], default: 1_000),
            // Items default to visible: an editor who adds a card means to show it.
            isEnabled: HomeModuleField.bool(data["enabled"], default: true)
        )
    }
}

// MARK: - Modules

/// A front-page block defined in Firestore rather than in code, so new
/// packages ("Senior of the Week", a spotlight) ship without an app release.
struct HomeModule: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case spotlight
        case rail
    }

    enum Placement: String, Codable, Sendable {
        case top
        case afterIssue
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let body: String?
    let imageURLString: String?
    let linkURLString: String?
    let articleID: String?
    let actionLabel: String?
    let placement: Placement
    let order: Double
    let isEnabled: Bool
    let startsAt: Date?
    let endsAt: Date?
    let items: [HomeModuleItem]

    var imageURL: URL? { HomeModuleField.webURL(imageURLString) }
    var linkURL: URL? { HomeModuleField.webURL(linkURLString) }
    var resolvedActionLabel: String { actionLabel ?? "Read more" }
    var destination: HomeModuleDestination {
        HomeModuleField.destination(articleID: articleID, linkURL: linkURL)
    }

    var renderableItems: [HomeModuleItem] {
        Array(
            items
                .filter(\.isRenderable)
                .sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
                .prefix(HomeModuleFilter.maxItemsPerRail)
        )
    }

    /// Window is half-open — `startsAt <= now < endsAt` — so an `endsAt` of
    /// Friday midnight means "gone at midnight", which is what a person means.
    func isVisible(at now: Date) -> Bool {
        guard isEnabled, !title.isEmpty else { return false }
        if let startsAt, startsAt > now { return false }
        if let endsAt, endsAt <= now { return false }
        if kind == .rail, renderableItems.isEmpty { return false }
        return true
    }

    func with(items: [HomeModuleItem]) -> HomeModule {
        HomeModule(
            id: id, kind: kind, title: title, subtitle: subtitle, body: body,
            imageURLString: imageURLString, linkURLString: linkURLString,
            articleID: articleID, actionLabel: actionLabel, placement: placement,
            order: order, isEnabled: isEnabled, startsAt: startsAt, endsAt: endsAt,
            items: items
        )
    }

    init(id: String, kind: Kind, title: String, subtitle: String? = nil, body: String? = nil,
         imageURLString: String? = nil, linkURLString: String? = nil, articleID: String? = nil,
         actionLabel: String? = nil, placement: Placement = .afterIssue, order: Double = 1_000,
         isEnabled: Bool = true, startsAt: Date? = nil, endsAt: Date? = nil,
         items: [HomeModuleItem] = []) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.imageURLString = imageURLString
        self.linkURLString = linkURLString
        self.articleID = articleID
        self.actionLabel = actionLabel
        self.placement = placement
        self.order = order
        self.isEnabled = isEnabled
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.items = items
    }

    /// Returns `nil` only when the document cannot be rendered at all, so one
    /// bad document never takes the rest of the front page down with it.
    init?(documentID: String, data: [String: Any], items: [HomeModuleItem] = []) {
        guard let rawKind = HomeModuleField.string(data["type"])?.lowercased(),
              let kind = Kind(rawValue: rawKind),
              let title = HomeModuleField.string(data["title"]) else { return nil }

        self.init(
            id: documentID,
            kind: kind,
            title: title,
            subtitle: HomeModuleField.string(data["subtitle"]),
            body: HomeModuleField.string(data["body"]),
            imageURLString: HomeModuleField.string(data["imageURL"]),
            linkURLString: HomeModuleField.string(data["linkURL"]),
            articleID: HomeModuleField.string(data["articleID"]),
            actionLabel: HomeModuleField.string(data["actionLabel"]),
            // An unrecognised placement falls back to the safe slot rather
            // than promoting an unfinished module above the lead story.
            placement: Placement(rawValue: HomeModuleField.string(data["placement"]) ?? "") ?? .afterIssue,
            order: HomeModuleField.double(data["order"], default: 1_000),
            // The one field that fails closed: a half-built document the editor
            // saved and walked away from must not reach readers.
            isEnabled: HomeModuleField.bool(data["enabled"], default: false),
            startsAt: HomeModuleField.date(data["startsAt"]),
            endsAt: HomeModuleField.date(data["endsAt"]),
            items: items
        )
    }
}

// MARK: - Selection

enum HomeModuleFilter {
    /// A page-wide budget, applied before the placement split, so remote
    /// content can never bury the Latest list.
    static let maxModules = 3
    static let maxItemsPerRail = 12

    static func visible(_ modules: [HomeModule],
                        at now: Date = Date(),
                        limit: Int = maxModules) -> [HomeModule] {
        Array(
            modules
                .filter { $0.isVisible(at: now) }
                .sorted { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
                .prefix(max(0, limit))
        )
    }
}
