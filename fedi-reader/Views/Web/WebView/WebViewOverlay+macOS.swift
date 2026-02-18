import SwiftUI
import WebKit
#if os(macOS)
import AppKit
#endif

#if os(macOS)
struct WebViewOverlay: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: NSViewRepresentableContext<WebViewOverlay>) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<WebViewOverlay>) {}
}
#endif
