import SwiftUI

// MARK: - Line classification

private enum TextLine {
    case mainTitle(String)
    case sectionHeader(String)
    case body(String)
}

// Words that are purely navigation/footer artifacts — skip them
private let navigationNoise: Set<String> = [
    "subscribe", "contact", "home", "instagram", "menu",
    "search", "back", "read more", "learn more", "click here"
]

private func classify(_ raw: String) -> [TextLine] {
    var result: [TextLine] = []
    var isFirst = true
    var prevWasBody = false

    for line in raw.components(separatedBy: "\n") {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { continue }
        if navigationNoise.contains(t.lowercased()) { continue }

        let letters = t.filter { $0.isLetter }
        let isAllCaps = !letters.isEmpty && t == t.uppercased()
        let words     = t.split(separator: " ").count
        let hasComma  = t.contains(",")
        // Short line with no comma = likely a label/heading
        let isShortLabel = t.count < 40 && words <= 5 && !hasComma

        if isFirst {
            // The very first non-noise line is always the main title
            result.append(.mainTitle(t))
            isFirst = false
            prevWasBody = false
        } else if isAllCaps || (isShortLabel && prevWasBody) {
            // All-caps line OR a short label following body text = section header
            result.append(.sectionHeader(t))
            prevWasBody = false
        } else {
            // Split "Alice Smith & Bob Jones" into two separate person entries
            let parts = t.components(separatedBy: " & ")
                         .map { $0.trimmingCharacters(in: .whitespaces) }
                         .filter { !$0.isEmpty }
            if parts.count > 1 {
                for part in parts { result.append(.body(part)) }
            } else {
                result.append(.body(t))
            }
            prevWasBody = true
        }
    }
    return result
}

// MARK: - View

struct AboutView: View {
    @State private var selectedTab   = 0
    @State private var aboutState    = FetchState.idle
    @State private var mastheadState = FetchState.idle
    @State private var subscribeURL  = URL(string: "https://www.themiltonpaper.com")!
    @State private var showSubscribe = false

    private enum FetchState {
        case idle, loading, loaded([TextLine]), failed
    }

    private let aboutURL    = URL(string: "https://www.themiltonpaper.com/about")!
    private let mastheadURL = URL(string: "https://www.themiltonpaper.com/masthead")!

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("About").tag(0)
                Text("Masthead").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.miltonSurface)

            Divider()

            pageContent(state: selectedTab == 0 ? aboutState : mastheadState)
        }
        .background(Color.miltonBackground.ignoresSafeArea())
        .navigationTitle("The Milton Paper")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.miltonSurface, for: .navigationBar)
        .task(id: selectedTab) { await loadCurrentTab() }
        .sheet(isPresented: $showSubscribe) {
            NavigationStack {
                WebPageView(url: subscribeURL)
                    .navigationTitle("Subscribe")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showSubscribe = false }
                                .foregroundColor(.miltonPrimary)
                        }
                    }
            }
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private func pageContent(state: FetchState) -> some View {
        if case .loaded(let lines) = state {
            ScrollView {
                VStack(alignment: .center, spacing: 0) {
                    styledContent(lines)
                        .padding(.horizontal, 28)
                        .padding(.top, 36)
                        .padding(.bottom, 8)

                    Divider()
                        .padding(.horizontal, 40)
                        .padding(.vertical, 28)

                    Button { showSubscribe = true } label: {
                        Text("Subscribe")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.miltonPrimary)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
                }
                .frame(maxWidth: .infinity)
            }
        } else if case .failed = state {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.miltonSecondary.opacity(0.4))
                Text("Could not load content")
                    .font(.miltonCaption)
                    .foregroundColor(.miltonSecondary)
                Spacer()
            }
        } else {
            VStack { Spacer(); ProgressView(); Spacer() }
        }
    }

    // MARK: - Typography

    @ViewBuilder
    private func styledContent(_ lines: [TextLine]) -> some View {
        VStack(alignment: .center, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line {

                case .mainTitle(let text):
                    VStack(spacing: 14) {
                        Text(toTitleCase(text))
                            .font(.custom("Georgia", size: 24).weight(.bold))
                            .foregroundColor(.miltonPrimary)
                            .multilineTextAlignment(.center)
                            .tracking(0.5)
                        Rectangle()
                            .fill(Color.miltonAccent)
                            .frame(width: 44, height: 1.5)
                    }
                    .padding(.bottom, 32)

                case .sectionHeader(let text):
                    Text(text.uppercased())
                        .font(.custom("Georgia", size: 13).weight(.semibold))
                        .foregroundColor(.miltonPrimary)
                        .multilineTextAlignment(.center)
                        .tracking(1.5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                case .body(let text):
                    Text(text)
                        .font(.custom("Georgia", size: 15))
                        .foregroundColor(.miltonSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 3)
                }
            }
        }
    }

    // MARK: - Fetching

    private func loadCurrentTab() async {
        if selectedTab == 0 {
            guard case .idle = aboutState else { return }
            aboutState = .loading
            let (text, url) = await fetch(url: aboutURL)
            if let url { subscribeURL = url }
            aboutState = text.isEmpty ? .failed : .loaded(classify(text))
        } else {
            guard case .idle = mastheadState else { return }
            mastheadState = .loading
            let (text, url) = await fetch(url: mastheadURL)
            if let url { subscribeURL = url }
            mastheadState = text.isEmpty ? .failed : .loaded(classify(text))
        }
    }

    // Converts "THE 43rd EDITORIAL BOARD" → "The 43rd Editorial Board"
    private func toTitleCase(_ s: String) -> String {
        s.components(separatedBy: " ").map { word in
            guard !word.isEmpty else { return word }
            if word.first?.isNumber == true { return word.lowercased() }
            return word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }

    private func fetch(url: URL) async -> (String, URL?) {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let html = String(data: data, encoding: .utf8) else { return ("", nil) }
        return (extractText(from: html), extractSubscribeURL(from: html))
    }

    // Search for <a> tags whose visible text mentions subscribe/membership/support
    private func extractSubscribeURL(from html: String) -> URL? {
        let terms = ["subscribe", "membership", "support us", "join"]
        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        for term in terms {
            let pattern = "<a[^>]+href=[\"']([^\"'#][^\"']*)[\"'][^>]*>[^<]{0,60}\(term)[^<]{0,60}</a>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: html, range: fullRange),
                  match.numberOfRanges > 1 else { continue }
            let raw = ns.substring(with: match.range(at: 1))
            guard !raw.hasPrefix("javascript"), !raw.hasPrefix("mailto") else { continue }
            if raw.hasPrefix("http") { return URL(string: raw) }
            if raw.hasPrefix("/")    { return URL(string: "https://www.themiltonpaper.com\(raw)") }
        }
        return nil
    }

    private func extractText(from html: String) -> String {
        var content = html
        if let s = html.range(of: "<main", options: .caseInsensitive),
           let e = html.range(of: "</main>", options: [.caseInsensitive, .backwards]) {
            content = String(html[s.lowerBound..<e.upperBound])
        }
        var text = content
        text = text.replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<style[\\s\\S]*?</style>",  with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</(p|div|h[1-6]|li|section|article)>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [(String, String)] = [
            ("&amp;","&"),("&nbsp;"," "),("&lt;","<"),("&gt;",">"),
            ("&#39;","'"),("&quot;","\""),("&mdash;","—"),("&ndash;","–"),
            ("&rsquo;","\u{2019}"),("&lsquo;","\u{2018}"),
            ("&rdquo;","\u{201D}"),("&ldquo;","\u{201C}")
        ]
        for (e, c) in entities { text = text.replacingOccurrences(of: e, with: c) }
        return text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
