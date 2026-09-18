import Combine
@preconcurrency import FirebaseRemoteConfig
import Foundation

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
            showHomeModules: remoteConfig[Key.showHomeModules].boolValue
        )
    }
}
