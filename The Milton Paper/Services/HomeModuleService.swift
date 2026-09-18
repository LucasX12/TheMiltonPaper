import Combine
import Foundation
import FirebaseFirestore

extension Timestamp: FirestoreDateValue {}

/// Front-page modules edited in the Firebase console.
///
/// Reads are one-shot behind a TTL rather than a snapshot listener: this
/// content changes weekly at most, a listener re-bills its whole result set
/// every time it reattaches, and the editor's real feedback loop is
/// "publish, then pull to refresh", which `load(forceRefresh:)` already gives
/// him instantly. The Remote Config kill switch keeps the realtime path for
/// the one case that needs it — taking bad content down.
@MainActor
final class HomeModuleService: ObservableObject {
    static let shared = HomeModuleService()

    @Published private(set) var modules: [HomeModule] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private var loadTask: Task<Void, Never>?
    private var lastChecked: Date?
    private var cachedHash: Int?
    private let ttl: TimeInterval = 900
    private let moduleLimit = 20
    private let itemLimit = 24
    private let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("milton-home-modules.json")

    private init() {
        guard !Config.isUITesting else { return }
        // Painting from disk in init (as IssueService does with the cached PDF)
        // means the front page draws with modules already in place instead of
        // popping them in a frame later.
        if let data = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode([HomeModule].self, from: data) {
            modules = cached
            cachedHash = cached.hashValue
        }
    }

    func load(forceRefresh: Bool = false) async {
        if Config.isUITesting {
            if modules.isEmpty { modules = MockData.homeModules }
            return
        }
        if !forceRefresh, !modules.isEmpty, let lastChecked,
           Date().timeIntervalSince(lastChecked) < ttl { return }
        if let loadTask {
            await loadTask.value
            return
        }

        let task = Task { @MainActor in
            isLoading = true
            errorMessage = nil
            defer {
                isLoading = false
                loadTask = nil
            }

            do {
                let fetched = try await fetchModules()
                lastChecked = Date()
                // Nothing changed: skip the published write so SwiftUI doesn't
                // re-diff the whole front page for an identical result.
                guard fetched.hashValue != cachedHash else { return }
                modules = fetched
                cachedHash = fetched.hashValue
                if let data = try? JSONEncoder().encode(fetched) {
                    try? data.write(to: cacheURL, options: .atomic)
                }
            } catch {
                // Modules are supplementary. Keep whatever is already on screen
                // and never surface an error banner for missing decoration.
                errorMessage = error.localizedDescription
            }
        }
        loadTask = task
        await task.value
    }

    /// Filtering and ordering happen on the client so no composite index can
    /// silently go missing, and so the logic stays unit-testable.
    private func fetchModules() async throws -> [HomeModule] {
        let snapshot = try await db.collection("homeModules").limit(to: moduleLimit).getDocuments()
        let now = Date()

        let shells: [HomeModule] = snapshot.documents.compactMap { document in
            guard let module = HomeModule(documentID: document.documentID, data: document.data()) else {
#if DEBUG
                print("[HomeModules] Skipped '\(document.documentID)': missing or unrecognised type/title")
#endif
                return nil
            }
            // Rails can only be judged once their items are known, so pre-filter
            // on the item-independent rules and pay for items just once.
            guard module.isEnabled,
                  module.startsAt.map({ $0 <= now }) ?? true,
                  module.endsAt.map({ $0 > now }) ?? true else { return nil }
            return module
        }

        let railIndexes = shells.indices.filter { shells[$0].kind == .rail }
        guard !railIndexes.isEmpty else { return shells }

        return try await withThrowingTaskGroup(of: (Int, [HomeModuleItem]).self) { group in
            var result = shells
            for index in railIndexes {
                let moduleID = shells[index].id
                let database = db
                let limit = itemLimit
                group.addTask { @MainActor in
                    let items = try await database.collection("homeModules")
                        .document(moduleID)
                        .collection("items")
                        .limit(to: limit)
                        .getDocuments()
                    return (index, items.documents.compactMap {
                        HomeModuleItem(documentID: $0.documentID, data: $0.data())
                    })
                }
            }
            for try await (index, items) in group {
                result[index] = result[index].with(items: items)
            }
            return result
        }
    }
}
