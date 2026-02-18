import SwiftUI
import WebKit
#if os(iOS)
import UIKit
#endif

#if os(iOS)
struct WebViewOverlay: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: UIViewRepresentableContext<WebViewOverlay>) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<WebViewOverlay>) {}
}
#endif
