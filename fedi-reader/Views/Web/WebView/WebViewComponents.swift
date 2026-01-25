//
//  WebViewComponents.swift
//  fedi-reader
//
//  WebView container, bridge, coordinator for article viewing.
//

import SwiftUI
import WebKit
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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

#if os(iOS)
struct WebViewOverlay: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: UIViewRepresentableContext<WebViewOverlay>) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<WebViewOverlay>) {}
}
#else
struct WebViewOverlay: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: NSViewRepresentableContext<WebViewOverlay>) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<WebViewOverlay>) {}
}
#endif

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
