import Combine
import Foundation
import PDFKit
import UIKit

@MainActor
final class IssueService: ObservableObject {
    static let shared = IssueService()

    @Published private(set) var document: PDFDocument?
    @Published private(set) var coverImage: UIImage?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var loadTask: Task<Void, Never>?
    private var lastChecked: Date?
    private var cachedFileID: String?
    private let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("milton-latest-issue.pdf")

    private init() {
        guard !Config.isUITesting else { return }
        if let cached = PDFDocument(url: cacheURL) {
            setDocument(cached)
            cachedFileID = UserDefaults.standard.string(forKey: "issue.cachedFileID")
        }
    }

    func load(forceRefresh: Bool = false) async {
        if Config.isUITesting {
            if document == nil { setDocument(Self.testDocument()) }
            return
        }
        if !forceRefresh, document != nil, let lastChecked,
           Date().timeIntervalSince(lastChecked) < 300 { return }
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
                let fileID = try await fetchGoogleDriveFileID()
                if fileID == cachedFileID, document != nil, !forceRefresh {
                    lastChecked = Date()
                    return
                }
                let data = try await downloadDrivePDF(fileID: fileID)
                guard let loadedDocument = PDFDocument(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                setDocument(loadedDocument)
                cachedFileID = fileID
                lastChecked = Date()
                do {
                    try data.write(to: cacheURL, options: .atomic)
                    UserDefaults.standard.set(fileID, forKey: "issue.cachedFileID")
                } catch {
                    // An unavailable disk cache must not prevent reading.
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        loadTask = task
        await task.value
    }

    private func setDocument(_ document: PDFDocument) {
        self.document = document
        coverImage = document.page(at: 0)?.thumbnail(of: CGSize(width: 360, height: 480), for: .mediaBox)
    }

    private static func testDocument() -> PDFDocument {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 600, height: 800))
        let data = renderer.pdfData { context in
            for page in 1...2 {
                context.beginPage()
                UIColor.white.setFill()
                context.cgContext.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
                ("The Milton Paper" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: [
                    .font: UIFont(name: "Georgia-Bold", size: 40)!, .foregroundColor: UIColor.black
                ])
                ("UI test edition · Page \(page)" as NSString).draw(at: CGPoint(x: 40, y: 105), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.darkGray
                ])
                context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
                context.cgContext.move(to: CGPoint(x: 40, y: 140))
                context.cgContext.addLine(to: CGPoint(x: 560, y: 140))
                context.cgContext.strokePath()
            }
        }
        return PDFDocument(data: data)!
    }

    private func fetchGoogleDriveFileID() async throws -> String {
        let url = URL(string: "https://themiltonpaper.com/latest-issue?format=json")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        let patterns = [
            #"drive\.google\.com/file/d/([A-Za-z0-9_\-]+)"#,
            #"drive\.google\.com/open\?id=([A-Za-z0-9_\-]+)"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let idRange = Range(match.range(at: 1), in: text) {
                return String(text[idRange])
            }
        }
        throw URLError(.cannotParseResponse)
    }

    private func downloadDrivePDF(fileID: String) async throws -> Data {
        let url = URL(string: "https://drive.google.com/uc?export=download&id=\(fileID)&confirm=t")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)

        let contentType = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type") ?? ""
        guard contentType.contains("text/html") else { return data }

        let html = String(data: data, encoding: .utf8) ?? ""
        guard let confirmURL = extractConfirmURL(from: html) else {
            throw URLError(.cannotParseResponse)
        }
        let (confirmedData, _) = try await URLSession.shared.data(from: confirmURL)
        return confirmedData
    }

    private func extractConfirmURL(from html: String) -> URL? {
        let pattern = #"href="(/uc\?export=download[^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              match.numberOfRanges > 1,
              let pathRange = Range(match.range(at: 1), in: html) else { return nil }
        let path = String(html[pathRange]).replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: "https://drive.google.com" + path)
    }
}
