import SwiftUI
import WebKit
import Combine

final class WebViewCoordinator: NSObject, WKNavigationDelegate, ObservableObject {
    @Published var isLoading = false
    @Published var pageTitle: String?
    @Published var canGoBack = false
    @Published var canGoForward = false

    @MainActor
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }

    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        pageTitle = webView.title
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    @MainActor
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        guard let scheme = url.scheme?.lowercased() else {
            decisionHandler(.cancel)
            return
        }
        switch scheme {
        case "https", "http":
            decisionHandler(.allow)
        default:
            decisionHandler(.cancel)
        }
    }
}

