import Combine
@preconcurrency import FirebaseRemoteConfig
import Foundation

/// Editorial copy that has to be changeable without an App Store release.
/// These are Remote Config strings rather than Firestore documents: it is a
/// paragraph and a link, the live listener already pushes edits to open apps,
/// and no new collection or security rule is needed.
struct AppNotices: Equatable {
    var aiNotice = AppNotices.defaultAINotice
    var aiPolicyLabel = "Read our AI usage policy"
    var aiPolicyURLString = ""

    /// Shipped in the app so an offline first launch still says something true.
    static let defaultAINotice = """
        Note: The Milton Paper utilized Claude Code and Codex as an aid in the \
        creation of this app. However, the writing, layout design, and \
        production of the Paper itself will never incorporate the use of \
        generative AI.
        """

    var aiPolicyURL: URL? { HomeModuleField.webURL(aiPolicyURLString) }
}

struct FeatureFlags: Equatable {
    var showThisWeek = true
    var showTMPlay = true
    var showStudentReflections = true
    var showFacultyFarewells = true
    var showNews = true
    var showOpinion = true
    var showSports = true
    var showArtsEntertainment = true
    var showEditorial = true
    var showHomeModules = true
    var showConnections = true

    func showsFeedCategory(_ category: String) -> Bool {
        let normalized = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == Config.categoryStudentReflections.lowercased() {
            return showStudentReflections
        }
        if normalized == Config.categoryFacultyFarewells.lowercased() {
            return showFacultyFarewells
        }
        switch normalized {
        case "news": return showNews
        case "opinion": return showOpinion
        case "sports": return showSports
        case "a&e", "arts", "arts & entertainment": return showArtsEntertainment
        case "editorial": return showEditorial
        default: return true
        }
    }
}

/// App-wide editorial controls that can be changed in Firebase without
/// shipping a new App Store build. In-app defaults keep the app usable while
/// offline and the last activated values are cached by Remote Config.
@MainActor
final class AppConfiguration: ObservableObject {
    static let shared = AppConfiguration()

    @Published private(set) var flags = FeatureFlags()
    @Published private(set) var notices = AppNotices()

    private enum Key {
        static let showThisWeek = "show_this_week"
        static let showTMPlay = "show_tmplay"
        static let showStudentReflections = "show_student_reflections"
        static let showFacultyFarewells = "show_faculty_farewells"
        static let showNews = "show_news"
        static let showOpinion = "show_opinion"
        static let showSports = "show_sports"
        static let showArtsEntertainment = "show_aande"
        static let showEditorial = "show_editorial"
        static let showHomeModules = "show_home_modules"
        static let showConnections = "show_connections"
        static let aiNotice = "about_ai_notice"
        static let aiPolicyLabel = "about_ai_policy_label"
        static let aiPolicyURL = "about_ai_policy_url"
    }

    private var remoteConfig: RemoteConfig?
    private var updateListener: ConfigUpdateListenerRegistration?
    private var hasStarted = false

    private init() {}

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        if Config.isUITesting {
            var testFlags = FeatureFlags()
            testFlags.showTMPlay = !ProcessInfo.processInfo.arguments.contains("-hideTMPlay")
            testFlags.showSports = !ProcessInfo.processInfo.arguments.contains("-hideSports")
            testFlags.showHomeModules = !ProcessInfo.processInfo.arguments.contains("-hideHomeModules")
            testFlags.showConnections = !ProcessInfo.processInfo.arguments.contains("-hideConnections")
            flags = testFlags
            return
        }

        // `start()` runs after AppDelegate has configured Firebase. Keeping
        // Firebase access out of init also makes the in-app defaults safe to
        // read while SwiftUI is constructing its initial view hierarchy.
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
#if DEBUG
        settings.minimumFetchInterval = 0
#else
        settings.minimumFetchInterval = 3_600
#endif
        config.configSettings = settings
        config.setDefaults([
            Key.showThisWeek: true as NSNumber,
            Key.showTMPlay: true as NSNumber,
            Key.showStudentReflections: true as NSNumber,
            Key.showFacultyFarewells: true as NSNumber,
            Key.showNews: true as NSNumber,
            Key.showOpinion: true as NSNumber,
            Key.showSports: true as NSNumber,
            Key.showArtsEntertainment: true as NSNumber,
            Key.showEditorial: true as NSNumber,
            Key.showHomeModules: true as NSNumber,
            Key.showConnections: true as NSNumber,
            Key.aiNotice: AppNotices.defaultAINotice as NSString,
            Key.aiPolicyLabel: "Read our AI usage policy" as NSString,
            Key.aiPolicyURL: "" as NSString,
        ])
        remoteConfig = config
        applyActivatedValues(from: config)

        Task { [weak self] in
            await self?.fetchLatest()
        }

        updateListener = config.addOnConfigUpdateListener { [weak self, config] _, error in
            guard error == nil else {
                print("[Remote Config] Live update failed: \(error!.localizedDescription)")
                return
            }
            config.activate { _, activationError in
                guard activationError == nil else {
                    print("[Remote Config] Activation failed: \(activationError!.localizedDescription)")
                    return
                }
                Task { @MainActor [weak self] in
                    self?.applyActivatedValues(from: config)
                }
            }
        }
    }

    private func fetchLatest() async {
        guard let remoteConfig else { return }
        do {
            _ = try await remoteConfig.fetchAndActivate()
            applyActivatedValues(from: remoteConfig)
        } catch {
            // Defaults or the last activated values remain available offline.
            print("[Remote Config] Fetch failed: \(error.localizedDescription)")
        }
    }

    private func applyActivatedValues(from remoteConfig: RemoteConfig) {
        flags = FeatureFlags(
            showThisWeek: remoteConfig[Key.showThisWeek].boolValue,
            showTMPlay: remoteConfig[Key.showTMPlay].boolValue,
            showStudentReflections: remoteConfig[Key.showStudentReflections].boolValue,
            showFacultyFarewells: remoteConfig[Key.showFacultyFarewells].boolValue,
            showNews: remoteConfig[Key.showNews].boolValue,
            showOpinion: remoteConfig[Key.showOpinion].boolValue,
            showSports: remoteConfig[Key.showSports].boolValue,
            showArtsEntertainment: remoteConfig[Key.showArtsEntertainment].boolValue,
            showEditorial: remoteConfig[Key.showEditorial].boolValue,
            showHomeModules: remoteConfig[Key.showHomeModules].boolValue,
            showConnections: remoteConfig[Key.showConnections].boolValue
        )

        // An empty string means "not configured", so fall back rather than
        // rendering a blank notice.
        let fallback = AppNotices()
        notices = AppNotices(
            aiNotice: text(remoteConfig[Key.aiNotice].stringValue) ?? fallback.aiNotice,
            aiPolicyLabel: text(remoteConfig[Key.aiPolicyLabel].stringValue) ?? fallback.aiPolicyLabel,
            aiPolicyURLString: text(remoteConfig[Key.aiPolicyURL].stringValue) ?? ""
        )
    }

    private func text(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
