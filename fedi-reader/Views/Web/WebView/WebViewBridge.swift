import SwiftUI
import WebKit
import Combine

struct WebViewBridge: View {
    let url: URL
    let coordinator: WebViewCoordinator
    @Binding var webViewBinding: WKWebView?
    let size: CGSize

    @State private var webView: WKWebView?

    var body: some View {
        Color.clear
            .onAppear {
                setupWebView()
            }
            .overlay {
                if let webView = webView {
                    WebViewOverlay(webView: webView)
                }
            }
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        #endif

        let wkWebView = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: config)
        wkWebView.navigationDelegate = coordinator
        wkWebView.allowsBackForwardNavigationGestures = true

        webViewBinding = wkWebView
        webView = wkWebView

        wkWebView.load(URLRequest(url: url))
    }
}


