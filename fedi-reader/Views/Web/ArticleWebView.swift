//
//  ArticleWebView.swift
//  fedi-reader
//
//  Minimal web viewer for articles with action toolbar
//

import SwiftUI
import WebKit

struct ArticleWebView: View {
    let url: URL
    let status: Status
    
    @Environment(AppState.self) private var appState
    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var isLoading = true
    @State private var pageTitle: String?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webView: WKWebView?
    
    var body: some View {
        VStack(spacing: 0) {
            // Web content
            WebViewContainer(
                url: url,
                isLoading: $isLoading,
                pageTitle: $pageTitle,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                webView: $webView
            )
            .ignoresSafeArea(edges: [.bottom, .leading, .trailing])
            
            // Action toolbar
            actionToolbar
        }
        .navigationTitle(pageTitle ?? url.host ?? "Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Navigation
                HStack(spacing: 16) {
                    Button {
                        webView?.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canGoBack)
                    
                    Button {
                        webView?.goForward()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canGoForward)
                    
                    if isLoading {
                        ProgressView()
                    } else {
                        Button {
                            webView?.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                
                // More options
                Menu {
                    Link(destination: url) {
                        Label("Open in Safari", systemImage: "safari")
                    }
                    
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.url = url
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .URL)
                        #endif
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }
                    
                    if readLaterManager.hasConfiguredServices {
                        Divider()
                        
                        ForEach(readLaterManager.configuredServices) { config in
                            if let serviceType = config.service {
                                Button {
                                    Task {
                                        try? await readLaterManager.save(
                                            url: url,
                                            title: pageTitle,
                                            to: serviceType
                                        )
                                    }
                                } label: {
                                    Label("Save to \(serviceType.displayName)", systemImage: serviceType.iconName)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private var actionToolbar: some View {
        StatusActionsToolbar(status: status)
            .glassEffect(.regular)
            .padding(.vertical, 4)
    }
}

// MARK: - Web View Container

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

// MARK: - WebKit View (Cross-platform)

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

// Platform-specific implementation using View
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
import UIKit

struct WebViewOverlay: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: UIViewRepresentableContext<WebViewOverlay>) -> WKWebView {
        webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: UIViewRepresentableContext<WebViewOverlay>) {}
}
#else
import AppKit

struct WebViewOverlay: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: NSViewRepresentableContext<WebViewOverlay>) -> WKWebView {
        webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<WebViewOverlay>) {}
}
#endif

// MARK: - Coordinator

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
        decisionHandler(.allow)
    }
}

// MARK: - Status Detail Row View (Full Text)

struct StatusDetailRowView: View {
    let status: Status
    @Environment(AppState.self) private var appState
    
    var displayStatus: Status {
        status.displayStatus
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Reblog indicator
            if status.isReblog {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.roundedCaption)
                    
                    Text("\(status.account.displayName) boosted")
                        .font(.roundedCaption)
                }
                .foregroundStyle(.secondary)
                .padding(.leading, Constants.UI.avatarSize + 10)
            }
            
            // Author info
            HStack(spacing: 10) {
                Button {
                    appState.navigate(to: .profile(displayStatus.account))
                } label: {
                    AsyncImage(url: displayStatus.account.avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(.tertiary)
                    }
                    .frame(width: Constants.UI.avatarSize, height: Constants.UI.avatarSize)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.UI.avatarCornerRadius))
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayStatus.account.displayName)
                        .font(.roundedSubheadline.bold())
                        .lineLimit(1)
                    
                    Text("@\(displayStatus.account.acct)")
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(TimeFormatter.relativeTimeString(from: displayStatus.createdAt))
                    .font(.roundedCaption)
                    .foregroundStyle(.tertiary)
            }
            
            // Content warning
            if !displayStatus.spoilerText.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    
                    Text(displayStatus.spoilerText)
                        .font(.roundedSubheadline.bold())
                }
                .padding()
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Full content with clickable links (no line limit)
            if #available(iOS 15.0, macOS 12.0, *) {
                Text(displayStatus.content.htmlToAttributedString)
                    .font(.roundedBody)
            } else {
                Text(displayStatus.content.htmlToPlainText)
                    .font(.roundedBody)
            }
            
            // Media attachments
            if !displayStatus.mediaAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayStatus.mediaAttachments) { attachment in
                            AsyncImage(url: URL(string: attachment.previewUrl ?? attachment.url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            
            // Link card
            if let card = displayStatus.card, card.type == .link {
                Button {
                    if let url = card.linkURL {
                        appState.navigate(to: .article(url: url, status: status))
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let imageURL = card.imageURL {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                            .frame(width: 80, height: 80)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.roundedSubheadline.bold())
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if !card.description.isEmpty {
                                Text(card.description)
                                    .font(.roundedCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.roundedCaption2)
                                
                                Text(card.providerName ?? HTMLParser.extractDomain(from: URL(string: card.url)!) ?? card.url)
                                    .font(.roundedCaption)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            
            // Actions bar
            StatusActionsBar(status: status, compact: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
    }
}

// MARK: - Status Detail View

struct StatusDetailView: View {
    let status: Status
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var context: StatusContext?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Original status with full text
                StatusDetailRowView(status: status)
                    .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                
                // Context (ancestors and descendants)
                if let context = context {
                    if !context.ancestors.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Thread")
                                .font(.roundedHeadline)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            
                            ForEach(context.ancestors) { ancestor in
                                StatusDetailRowView(status: ancestor)
                                    .padding(.horizontal)
                                Divider()
                            }
                        }
                    }
                    
                    if !context.descendants.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Replies")
                                .font(.roundedHeadline)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            
                            ForEach(context.descendants) { descendant in
                                StatusDetailRowView(status: descendant)
                                    .padding(.horizontal)
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContext()
        }
    }
    
    private func loadContext() async {
        guard let service = timelineWrapper.service else {
            isLoading = false
            return
        }
        
        do {
            context = try await service.getStatusContext(for: status)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview("Article Web View") {
    NavigationStack {
        ArticleWebView(
            url: URL(string: "https://example.com")!,
            status: Status.samplePreview
        )
    }
    .environment(AppState())
    .environment(ReadLaterManager())
    .environment(TimelineServiceWrapper())
}

// Preview helper
extension Status {
    static var samplePreview: Status {
        Status(
            id: "preview",
            uri: "https://example.com/status/preview",
            url: "https://example.com/status/preview",
            createdAt: Date(),
            account: MastodonAccount(
                id: "1",
                username: "preview",
                acct: "preview@example.com",
                displayName: "Preview User",
                locked: false,
                bot: false,
                createdAt: Date(),
                note: "",
                url: "https://example.com/@preview",
                avatar: "https://example.com/avatar.png",
                avatarStatic: "https://example.com/avatar.png",
                header: "https://example.com/header.png",
                headerStatic: "https://example.com/header.png",
                followersCount: 0,
                followingCount: 0,
                statusesCount: 0,
                lastStatusAt: nil,
                emojis: [],
                fields: []
            ),
            content: "<p>Preview content</p>",
            visibility: Visibility.public,
            sensitive: false,
            spoilerText: "",
            mediaAttachments: [],
            mentions: [],
            tags: [],
            emojis: [],
            reblogsCount: 0,
            favouritesCount: 0,
            repliesCount: 0,
            application: nil as Application?,
            language: "en",
            reblog: nil,
            card: nil,
            poll: nil,
            quote: nil,
            favourited: false,
            reblogged: false,
            muted: false,
            bookmarked: false,
            pinned: false,
            inReplyToId: nil,
            inReplyToAccountId: nil
        )
    }
}
