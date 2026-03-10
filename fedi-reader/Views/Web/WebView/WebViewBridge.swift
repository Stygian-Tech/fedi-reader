import SwiftUI
import WebKit
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct WebViewBridge: View {
    let url: URL
    let coordinator: WebViewCoordinator
    @Binding var webViewBinding: WKWebView?
    let size: CGSize
    let colorScheme: ColorScheme

    @State private var webView: WKWebView?

    var body: some View {
        Color.clear
            .onAppear {
                setupWebView()
            }
            .onChange(of: url) { _, newURL in
                webView?.load(URLRequest(url: newURL))
            }
            .onChange(of: colorScheme) { _, newScheme in
                applyColorScheme(newScheme, to: webView)
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
        #if os(iOS)
        wkWebView.isOpaque = false
        wkWebView.backgroundColor = .clear
        wkWebView.scrollView.backgroundColor = .clear
        #endif

        webViewBinding = wkWebView
        webView = wkWebView

        wkWebView.load(URLRequest(url: url))
        applyColorScheme(colorScheme, to: wkWebView)
    }

    private func applyColorScheme(_ scheme: ColorScheme, to wk: WKWebView? = nil) {
        #if os(iOS)
        let target = wk ?? webView
        guard let target else { return }
        switch scheme {
        case .dark:
            target.overrideUserInterfaceStyle = .dark
        case .light:
            target.overrideUserInterfaceStyle = .light
        @unknown default:
            target.overrideUserInterfaceStyle = .unspecified
        }
        #endif
    }
}


