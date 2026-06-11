import SwiftUI
import WebKit

struct WebPageView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.isOpaque = false
        wv.backgroundColor = .clear
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Reload only when the target URL changes; unrelated SwiftUI updates
        // must not restart navigation (and wipe the user's scroll position).
        guard context.coordinator.lastLoadedURL != url else { return }
        context.coordinator.lastLoadedURL = url
        uiView.load(URLRequest(url: url))
    }

    final class Coordinator {
        var lastLoadedURL: URL?
    }
}
