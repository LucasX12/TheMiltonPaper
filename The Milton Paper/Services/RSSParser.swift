import Foundation
import UIKit

final class RSSParser: NSObject, XMLParserDelegate {
    private var articles: [Article] = []
    private var currentElement = ""
    private var currentItem: [String: String] = [:]
    private var inItem = false
    private var buffer = ""
    private var defaultCategory = "News"

    func parse(data: Data, defaultCategory: String = "News") -> [Article] {
        articles = []
        self.defaultCategory = defaultCategory
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        currentElement = elementName
        buffer = ""

        if elementName == "item" {
            inItem = true
            currentItem = [:]
        }

        // Media thumbnail via attribute
        if (elementName == "media:thumbnail" || elementName == "media:content"),
           let url = attributeDict["url"] {
            currentItem["thumbnailURL"] = url
        }
        if elementName == "enclosure",
           let url = attributeDict["url"],
           let type = attributeDict["type"],
           type.hasPrefix("image") {
            currentItem["thumbnailURL"] = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let str = String(data: CDATABlock, encoding: .utf8) {
            buffer += str
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        buffer = ""

        guard inItem else { return }

        switch elementName {
        case "title":           currentItem["title"] = value
        case "description":     currentItem["description"] = value
        case "content:encoded": currentItem["bodyHTML"] = value
        case "dc:creator", "author":
            if currentItem["author"] == nil { currentItem["author"] = value }
        case "pubDate":         currentItem["pubDate"] = value
        case "link":            currentItem["link"] = value
        case "guid":            if currentItem["guid"] == nil { currentItem["guid"] = value }
        case "category":        if currentItem["category"] == nil { currentItem["category"] = value }
        case "item":
            if let article = buildArticle(from: currentItem) {
                articles.append(article)
            }
            inItem = false
        default: break
        }
    }

    // MARK: - Private

    private func buildArticle(from item: [String: String]) -> Article? {
        guard
            let title = item["title"], !title.isEmpty,
            let linkStr = item["link"] ?? item["guid"],
            let url = URL(string: linkStr)
        else { return nil }

        let id = item["guid"] ?? linkStr
        // Try to extract the real byline from article content before falling back to the poster account
        let contentForAuthor = item["description"] ?? item["bodyHTML"] ?? ""
        let author = extractAuthorFromContent(contentForAuthor) ?? item["author"] ?? "The Milton Paper"
        let category = item["category"] ?? defaultCategory
        // Strip byline from body HTML so it doesn't appear twice (header already shows the author)
        let rawBodyHTML = item["bodyHTML"] ?? item["description"] ?? ""
        let bodyHTML = stripBylineFromBodyHTML(rawBodyHTML)
        // Strip byline from summary text so it doesn't appear in article cards
        let rawSummary = stripHTML(item["description"] ?? String(bodyHTML.prefix(500)))
        let summary = stripBylineFromText(rawSummary)
        let thumbnailURL = item["thumbnailURL"].flatMap { URL(string: $0) }
            ?? extractFirstImage(from: bodyHTML)
        let publishedDate = item["pubDate"].flatMap { parsePubDate($0) } ?? Date()

        return Article(
            id: id,
            title: title,
            author: author,
            publishedDate: publishedDate,
            category: category,
            summary: summary,
            bodyHTML: bodyHTML,
            articleURL: url,
            thumbnailURL: thumbnailURL
        )
    }

    private func extractAuthorFromContent(_ html: String) -> String? {
        // Convert HTML tags to newlines so each block element becomes its own line
        let text = html
            .replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Find the first line that is purely a byline (starts with "By ")
        let bylineLine = lines.prefix(8).first {
            let lower = $0.lowercased()
            return lower.hasPrefix("by ") && $0.count < 80
        }
        guard let line = bylineLine else { return nil }

        // Drop the leading "By " then split on " and " / " & " for multiple authors.
        // For each author segment, keep only purely alphabetic words — this discards
        // class-year tokens like '26 regardless of which apostrophe character is used.
        let afterBy = String(line.dropFirst(3))
            .replacingOccurrences(of: " & ", with: " and ")
            .trimmingCharacters(in: .whitespaces)
        let names = afterBy
            .components(separatedBy: " and ")
            .map { part in
                part.components(separatedBy: " ")
                    .filter { word in
                        !word.isEmpty &&
                        word.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
                    }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { $0.count > 1 }

        guard let first = names.first else { return nil }
        let stopWords: Set<String> = ["the", "a", "an", "our", "staff", "editors", "reporter"]
        let firstWord = first.components(separatedBy: " ").first?.lowercased() ?? ""
        guard !stopWords.contains(firstWord) else { return nil }

        return names.joined(separator: " and ")
    }

    // Removes leading "By …" lines from plain summary text
    private func stripBylineFromText(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
        while let first = lines.first,
              first.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("by ") {
            lines.removeFirst()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Removes the first byline block from body HTML so it doesn't appear twice
    private func stripBylineFromBodyHTML(_ html: String) -> String {
        let pattern = #"<(?:p|div|span)[^>]*>\s*[Bb]y\s[^<]{1,200}</(?:p|div|span)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return html }
        let nsHTML = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: nsHTML.length)),
              match.range.location < 800
        else { return html }
        return nsHTML.replacingCharacters(in: match.range, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parsePubDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }

    private func stripHTML(_ html: String) -> String {
        guard let data = html.data(using: .utf8) else { return html }
        if let attr = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var result = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, replacement) in [("&amp;","&"),("&lt;","<"),("&gt;",">"),("&nbsp;"," "),("&#39;","'"),("&quot;","\"")] {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractFirstImage(from html: String) -> URL? {
        guard let range = html.range(of: #"<img[^>]+src="([^"]+)""#, options: .regularExpression) else { return nil }
        let tag = String(html[range])
        guard let srcRange = tag.range(of: #"src="([^"]+)""#, options: .regularExpression) else { return nil }
        let src = String(tag[srcRange])
            .replacingOccurrences(of: "src=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
        return URL(string: src)
    }
}
