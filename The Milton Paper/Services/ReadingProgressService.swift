import Foundation

struct ReadingRecord: Codable, Identifiable {
    let id: String
    let title: String
    let author: String
    let category: String
    let thumbnailURL: URL?
    let articleURL: URL
    var progress: Double
    var lastRead: Date
    var scrollOffset: CGFloat

    var isCompleted: Bool { progress >= 0.85 }

    init(id: String, title: String, author: String, category: String,
         thumbnailURL: URL?, articleURL: URL, progress: Double,
         lastRead: Date, scrollOffset: CGFloat = 0) {
        self.id = id; self.title = title; self.author = author
        self.category = category; self.thumbnailURL = thumbnailURL
        self.articleURL = articleURL; self.progress = progress
        self.lastRead = lastRead; self.scrollOffset = scrollOffset
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, author, category, thumbnailURL, articleURL, progress, lastRead, scrollOffset
    }

    // Custom decoder so existing records without scrollOffset don't fail to load
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(String.self, forKey: .id)
        title        = try c.decode(String.self, forKey: .title)
        author       = try c.decode(String.self, forKey: .author)
        category     = try c.decode(String.self, forKey: .category)
        thumbnailURL = try c.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        articleURL   = try c.decode(URL.self, forKey: .articleURL)
        progress     = try c.decode(Double.self, forKey: .progress)
        lastRead     = try c.decode(Date.self, forKey: .lastRead)
        scrollOffset = (try? c.decode(CGFloat.self, forKey: .scrollOffset)) ?? 0
    }
}

final class ReadingProgressService {
    static let shared = ReadingProgressService()
    private let key = "reading.history.v1"
    private let maxRecords = 50

    private init() {}

    func record(articleId: String, title: String, author: String, category: String,
                thumbnailURL: URL?, articleURL: URL, progress: Double, scrollOffset: CGFloat = 0) {
        guard progress > 0.01 else { return }
        var records = loadAll()
        records.removeAll { $0.id == articleId }
        let rec = ReadingRecord(
            id: articleId, title: title, author: author, category: category,
            thumbnailURL: thumbnailURL, articleURL: articleURL,
            progress: progress, lastRead: Date(), scrollOffset: scrollOffset
        )
        records.insert(rec, at: 0)
        if records.count > maxRecords { records = Array(records.prefix(maxRecords)) }
        save(records)
    }

    func loadAll() -> [ReadingRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([ReadingRecord].self, from: data) else {
            return []
        }
        return records
    }

    var inProgress: [ReadingRecord] {
        loadAll().filter { !$0.isCompleted && $0.progress > 0.05 }
    }

    var recentlyCompleted: [ReadingRecord] {
        loadAll().filter { $0.isCompleted }
    }

    private func save(_ records: [ReadingRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
