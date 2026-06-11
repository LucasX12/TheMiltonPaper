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
        let w = Int(viewWidth)
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=\(w), initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
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
                img, video, iframe { max-width: 100% !important; width: auto !important; height: auto !important; border-radius: 8px; margin: 12px 0; display: block; }
                blockquote {
                    border-left: 3px solid #C9A84C;
                    padding: 8px 16px;
                    margin: 16px 0;
                    color: #6E6E73;
                    font-style: italic;
                    text-align: left;
                }
                figure { margin: 12px 0; }
                figcaption { font-size: 13px; color: #6E6E73; margin-top: 4px; font-style: italic; text-align: left; }
                ul, ol { margin: 0 0 16px 24px; text-align: left; }
                li { margin-bottom: 6px; }
                table { width: 100% !important; table-layout: fixed; word-break: break-word; }
            </style>
        </head>
        <body>\(htmlContent)</body>
        </html>
        """
        uiView.loadHTMLString(styledHTML, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var contentHeight: CGFloat

        init(contentHeight: Binding<CGFloat>) {
            _contentHeight = contentHeight
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.contentHeight = height
                    }
                }
            }
        }
    }
}
