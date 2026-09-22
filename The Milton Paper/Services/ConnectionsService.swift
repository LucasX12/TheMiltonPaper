import Combine
import Foundation
import FirebaseFirestore

// `extension Timestamp: FirestoreDateValue` lives in HomeModuleService; a
// second conformance here would not compile.

/// The weekly Connections puzzle, edited in the Firebase console. Mirrors
/// `HomeModuleService`: disk cache painted in `init`, TTL, in-flight
/// coalescing, and last-good values kept when a fetch fails.
@MainActor
final class ConnectionsService: ObservableObject {
    static let shared = ConnectionsService()

    @Published private(set) var puzzles: [ConnectionsPuzzle] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private var loadTask: Task<Void, Never>?
    private var lastChecked: Date?
    private var cachedHash: Int?
    private let ttl: TimeInterval = 900
    private let puzzleLimit = 8
    private let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("milton-connections.json")

    var livePuzzle: ConnectionsPuzzle? { ConnectionsPuzzleFilter.live(puzzles) }
    var knownPuzzleIDs: Set<String> { Set(puzzles.map(\.id)) }

    private init() {
        guard !Config.isUITesting else { return }
        // The puzzle is the whole screen, so paint it from disk before the
        // first frame instead of popping a board in a second later.
        if let data = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode([ConnectionsPuzzle].self, from: data) {
            puzzles = cached
            cachedHash = cached.hashValue
        }
    }

    func load(forceRefresh: Bool = false) async {
        if Config.isUITesting {
            if puzzles.isEmpty { puzzles = MockData.connectionsPuzzles }
            return
        }
        if !forceRefresh, !puzzles.isEmpty, let lastChecked,
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
                let fetched = try await fetchPuzzles()
                lastChecked = Date()
                guard fetched.hashValue != cachedHash else { return }
                puzzles = fetched
                cachedHash = fetched.hashValue
                if let data = try? JSONEncoder().encode(fetched) {
                    try? data.write(to: cacheURL, options: .atomic)
                }
            } catch {
                // A cached puzzle stays playable; the view only shows an error
                // when it has nothing at all. Log it so a silent failure is
                // still diagnosable from the console.
#if DEBUG
                print("[Connections] Fetch failed: \(error)")
#endif
                errorMessage = error.localizedDescription
            }
        }
        loadTask = task
        await task.value
    }

    /// Ordered newest-first so the limit keeps the *current* puzzles: an
    /// unordered `limit` returns documents in ascending name order, which from
    /// the ninth week onwards would silently drop the live puzzle and keep the
    /// oldest ones.
    ///
    /// The sort key is `startsAt` rather than the document id. Ordering by
    /// `__name__` descending needs a composite index that has to be created by
    /// hand — miss it and every fetch throws, which is exactly how this was
    /// first shipped. A single field like `startsAt` is covered by Firestore's
    /// automatic indexes, so there is nothing to forget. The trade is that a
    /// document with no `startsAt` is never returned, so that field is
    /// genuinely required rather than merely recommended.
    ///
    /// Semantic selection still happens client-side, in tested pure code.
    private func fetchPuzzles() async throws -> [ConnectionsPuzzle] {
        let snapshot = try await db.collection("connectionsPuzzles")
            .order(by: "startsAt", descending: true)
            .limit(to: puzzleLimit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            guard let puzzle = ConnectionsPuzzle(documentID: document.documentID, data: document.data()) else {
#if DEBUG
                print("[Connections] Skipped '\(document.documentID)': needs four groups of four distinct words and a start date")
#endif
                return nil
            }
            return puzzle
        }
    }

#if DEBUG
    /// Prints why the tab is empty, which is otherwise invisible.
    func debugDescribeSelection() {
        print("[Connections] \(puzzles.count) puzzle(s) parsed; live = \(livePuzzle?.id ?? "none")")
        for puzzle in puzzles {
            print("[Connections]   \(puzzle.id) enabled=\(puzzle.isEnabled) startsAt=\(puzzle.startsAt) now=\(Date())")
        }
    }
#endif
}
