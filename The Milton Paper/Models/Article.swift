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

    var estimatedReadTime: Int {
        let wordCount = bodyHTML
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        return max(1, wordCount / 200)
    }
}
