import SwiftUI
import WebKit

public struct StoryTellerWebView: UIViewRepresentable {
    public let urlString: String

    public init(urlString: String) {
        self.urlString = urlString
    }

    public func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0)
        webView.scrollView.backgroundColor = webView.backgroundColor

        if let url = URL(string: urlString) {
            let req = URLRequest(url: url)
            webView.load(req)
        }
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if let currentURL = uiView.url?.absoluteString, currentURL != urlString {
            if let url = URL(string: urlString) {
                uiView.load(URLRequest(url: url))
            }
        }
    }
}
