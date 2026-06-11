import Foundation

struct Article: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let publishedDate: Date
    let category: String
    let summary: String
    let bodyHTML: String
    let articleURL: URL
    let thumbnailURL: URL?
    var isBookmarked: Bool = false

    // Cached because cards recompute this while scrolling, and the regex over
    // full article HTML is too slow to run per frame. NSCache is thread-safe.
    private static let readTimeCache = NSCache<NSString, NSNumber>()

    var estimatedReadTime: Int {
        if let cached = Self.readTimeCache.object(forKey: id as NSString) {
            return cached.intValue
        }
        let wordCount = bodyHTML
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        let minutes = max(1, wordCount / 200)
        Self.readTimeCache.setObject(NSNumber(value: minutes), forKey: id as NSString)
        return minutes
    }
}
