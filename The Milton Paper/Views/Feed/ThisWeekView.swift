import SwiftUI
import PDFKit

// MARK: - This Week View

struct ThisWeekView: View {
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            Color.miltonBackground.ignoresSafeArea()

            if isLoading {
                LoadingView()
            } else if let msg = loadError {
                ErrorView(message: msg) {
                    Task { await loadPDF() }
                }
            } else if let doc = pdfDocument {
                PDFKitView(document: doc)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .task { await loadPDF() }
    }

    private func loadPDF() async {
        isLoading = true
        loadError = nil
        pdfDocument = nil
        do {
            let fileID = try await fetchGoogleDriveFileID()
            let data   = try await downloadDrivePDF(fileID: fileID)
            if let doc = PDFDocument(data: data) {
                pdfDocument = doc
            } else {
                loadError = "Could not open PDF"
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // Step 1: fetch the Squarespace JSON API to extract the embedded Drive file ID
    private func fetchGoogleDriveFileID() async throws -> String {
        let url = URL(string: "https://themiltonpaper.com/latest-issue?format=json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let text = String(data: data, encoding: .utf8) ?? ""

        // Match: drive.google.com/file/d/<ID>/ or drive.google.com/open?id=<ID>
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

    // Step 2: download the raw PDF bytes from Google Drive
    private func downloadDrivePDF(fileID: String) async throws -> Data {
        // confirm=t bypasses the virus-scan interstitial for larger files
        let url = URL(string: "https://drive.google.com/uc?export=download&id=\(fileID)&confirm=t")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
        if contentType.contains("text/html") {
            // Google returned the confirm page — parse out the real download link
            let html = String(data: data, encoding: .utf8) ?? ""
            if let confirmURL = extractConfirmURL(from: html, fileID: fileID) {
                let (pdfData, _) = try await URLSession.shared.data(from: confirmURL)
                return pdfData
            }
            throw URLError(.cannotParseResponse)
        }
        return data
    }

    private func extractConfirmURL(from html: String, fileID: String) -> URL? {
        // Drive confirm pages contain a form action or link like /uc?export=download&id=...&confirm=...
        let pattern = #"href="(/uc\?export=download[^"]+)""#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           match.numberOfRanges > 1,
           let pathRange = Range(match.range(at: 1), in: html) {
            let path = String(html[pathRange])
                .replacingOccurrences(of: "&amp;", with: "&")
            return URL(string: "https://drive.google.com" + path)
        }
        return nil
    }
}

// MARK: - PDF renderer

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.autoScales = true
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(Color.miltonBackground)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
