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

    /// Used when the feed gives no byline. It reads fine as a list subtitle but
    /// not as "By The Milton Paper" under a headline, so `hasNamedAuthor`
    /// gates the byline rows.
    static let houseByline = "The Milton Paper"

    var hasNamedAuthor: Bool {
        !author.trimmingCharacters(in: .whitespaces).isEmpty && author != Self.houseByline
    }

    /// The feed reuses the article's opening as its description, so a standfirst
    /// would just repeat the first lines of the body. Show it only when it says
    /// something the body doesn't already open with.
    var standfirst: String? {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let probe = Self.comparable(trimmed.replacingOccurrences(of: "…", with: ""))
        guard probe.count >= 24 else { return trimmed }
        let body = Self.comparable(bodyHTML)
        return body.hasPrefix(String(probe.prefix(60))) ? nil : trimmed
    }

    private static func comparable(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

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
