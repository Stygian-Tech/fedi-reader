import SwiftUI
import WebKit
import Combine

struct WebKitView: View {
    let url: URL
    let coordinator: WebViewCoordinator
    @Binding var webViewBinding: WKWebView?

    var body: some View {
        GeometryReader { geometry in
            WebViewBridge(
                url: url,
                coordinator: coordinator,
                webViewBinding: $webViewBinding,
                size: geometry.size
            )
        }
    }
}

