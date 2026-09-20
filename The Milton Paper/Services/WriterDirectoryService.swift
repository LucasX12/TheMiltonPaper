import Combine
import Foundation
import FirebaseFirestore

/// Writer photos and bios, edited in the Firebase console.
///
/// Mirrors `HomeModuleService`: a small collection fetched whole, cached to
/// disk so avatars are present on the first frame, and never surfaced as an
/// error — a missing directory just means bylines keep their monogram.
@MainActor
final class WriterDirectoryService: ObservableObject {
    static let shared = WriterDirectoryService()

    @Published private(set) var writersBySlug: [String: Writer] = [:]
    @Published private(set) var isLoading = false

    private let db = Firestore.firestore()
    private var loadTask: Task<Void, Never>?
    private var lastChecked: Date?
    private var cachedHash: Int?
    private let ttl: TimeInterval = 1_800
    private let writerLimit = 200
    private let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("milton-writers.json")

    private init() {
        guard !Config.isUITesting else { return }
        if let data = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode([Writer].self, from: data) {
            writersBySlug = Self.index(cached)
            cachedHash = cached.hashValue
        }
    }

    /// The writer behind a single name from a byline, or nil when the
    /// directory has no entry for them yet.
    func writer(named name: String) -> Writer? {
        writersBySlug[Writer.slug(for: name)]
    }

    func load(forceRefresh: Bool = false) async {
        if Config.isUITesting {
            if writersBySlug.isEmpty { writersBySlug = Self.index(MockData.writers) }
            return
        }
        if !forceRefresh, !writersBySlug.isEmpty, let lastChecked,
           Date().timeIntervalSince(lastChecked) < ttl { return }
        if let loadTask {
            await loadTask.value
            return
        }

        let task = Task { @MainActor in
            isLoading = true
            defer {
                isLoading = false
                loadTask = nil
            }
            do {
                let snapshot = try await db.collection("writers").limit(to: writerLimit).getDocuments()
                let fetched = snapshot.documents.compactMap {
                    Writer(documentID: $0.documentID, data: $0.data())
                }.filter(\.isEnabled)

                lastChecked = Date()
                guard fetched.hashValue != cachedHash else { return }
                writersBySlug = Self.index(fetched)
                cachedHash = fetched.hashValue
                if let data = try? JSONEncoder().encode(fetched) {
                    try? data.write(to: cacheURL, options: .atomic)
                }
            } catch {
                // Bylines fall back to their monogram; never worth a banner.
#if DEBUG
                print("[Writers] Load failed: \(error.localizedDescription)")
#endif
            }
        }
        loadTask = task
        await task.value
    }

    /// Keyed by the name slug rather than the document id, so a document whose
    /// id and `name` drifted apart still resolves from the byline.
    private static func index(_ writers: [Writer]) -> [String: Writer] {
        Dictionary(writers.map { (Writer.slug(for: $0.name), $0) }, uniquingKeysWith: { first, _ in first })
    }
}
