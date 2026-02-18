import SwiftUI
import WebKit
import Combine

struct WebViewContainer: View {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webView: WKWebView?

    @State private var coordinator = WebViewCoordinator()

    var body: some View {
        WebKitView(
            url: url,
            coordinator: coordinator,
            webViewBinding: $webView
        )
        .onReceive(coordinator.$isLoading) { isLoading = $0 }
        .onReceive(coordinator.$pageTitle) { pageTitle = $0 }
        .onReceive(coordinator.$canGoBack) { canGoBack = $0 }
        .onReceive(coordinator.$canGoForward) { canGoForward = $0 }
    }
}

