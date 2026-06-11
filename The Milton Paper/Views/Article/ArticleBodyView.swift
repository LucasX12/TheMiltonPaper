import SwiftUI
import WebKit

struct ArticleBodyView: UIViewRepresentable {
    let htmlContent: String
    var baseURL: URL?
    @Binding var contentHeight: CGFloat
    var viewWidth: CGFloat = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 393

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Weak wrapper: the user content controller retains its handlers strongly.
        config.userContentController.add(
            WeakScriptMessageHandler(context.coordinator), name: "miltonHeight"
        )
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: 1), configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Reload only when the content or layout width actually changes —
        // unrelated SwiftUI state updates must not restart the page load.
        let loadKey = "\(Int(viewWidth.rounded()))|\(htmlContent.hashValue)"
        guard context.coordinator.lastLoadKey != loadKey else { return }
        context.coordinator.lastLoadKey = loadKey
        uiView.loadHTMLString(styledHTML(width: Int(viewWidth.rounded())), baseURL: baseURL)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "miltonHeight")
        uiView.navigationDelegate = nil
    }

    private func styledHTML(width: Int) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=\(width), initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                :root { color-scheme: light dark; }
                html, body { overflow-x: hidden; width: 100%; }
                * { box-sizing: border-box; margin: 0; padding: 0; max-width: 100%; }
                body {
                    font-family: Georgia, serif;
                    font-size: 17px;
                    line-height: 1.7;
                    color: #1C1C1E;
                    padding: 0 24px 40px;
                    background: transparent;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                    text-align: justify;
                }
                body > :first-child { margin-top: 0 !important; padding-top: 0 !important; }
                h1, h2, h3 {
                    font-family: Georgia, serif;
                    color: #1A2744;
                    margin: 24px 0 12px;
                    text-align: left;
                    word-break: break-word;
                    overflow-wrap: break-word;
                    max-width: 100%;
                }
                h2 { font-size: 20px; }
                h3 { font-size: 17px; }
                p { margin: 0 0 16px; }
                a { color: #1A2744; text-decoration: underline; }
                img, video, iframe { max-width: 100% !important; width: auto !important; height: auto !important; border-radius: 8px; margin: 16px 0; display: block; }
                figure { margin: 16px 0; }
                figure img { margin: 0; }
                figcaption { font-size: 13px; color: #6E6E73; margin-top: 6px; font-style: italic; text-align: left; }
                blockquote {
                    border-left: 3px solid #C9A84C;
                    padding: 8px 16px;
                    margin: 16px 0;
                    color: #6E6E73;
                    font-style: italic;
                    text-align: left;
                }
                ul, ol { margin: 0 0 16px 24px; text-align: left; }
                li { margin-bottom: 6px; }
                table { width: 100% !important; table-layout: fixed; word-break: break-word; }
                @media (prefers-color-scheme: dark) {
                    body { color: #F2F2F7; }
                    h1, h2, h3 { color: #DCE4F5; }
                    a { color: #4B81CC; }
                    blockquote, figcaption { color: #8E8E93; }
                }
            </style>
        </head>
        <body>\(htmlContent)
        <script>
            function miltonReportHeight() {
                window.webkit.messageHandlers.miltonHeight.postMessage(document.documentElement.scrollHeight);
            }
            // Squarespace exports lazy-loaded images with the real URL in data-src.
            document.querySelectorAll('img[data-src]').forEach(function (img) {
                if (!img.getAttribute('src')) { img.src = img.getAttribute('data-src'); }
            });
            window.addEventListener('load', miltonReportHeight);
            new ResizeObserver(miltonReportHeight).observe(document.body);
            miltonReportHeight();
        </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var contentHeight: CGFloat
        var lastLoadKey: String?

        init(contentHeight: Binding<CGFloat>) {
            _contentHeight = contentHeight
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "miltonHeight",
                  let height = (message.body as? NSNumber).map({ CGFloat(truncating: $0) }),
                  height > 0,
                  abs(height - contentHeight) > 1 else { return }
            contentHeight = height
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] result, _ in
                guard let self,
                      let height = result as? CGFloat,
                      height > 0,
                      abs(height - self.contentHeight) > 1 else { return }
                DispatchQueue.main.async { self.contentHeight = height }
            }
        }

        // Open tapped links in the system browser instead of navigating the
        // embedded article body (which has a fixed height and no controls).
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               url.scheme?.hasPrefix("http") == true {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
