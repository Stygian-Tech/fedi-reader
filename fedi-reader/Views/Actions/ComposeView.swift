//
//  ComposeView.swift
//  fedi-reader
//
//  Compose new post, reply, or quote
//

import SwiftUI

struct ComposeView: View {
    let replyTo: Status?
    let quote: Status?
    
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var content = ""
    @State private var spoilerText = ""
    @State private var showSpoiler = false
    @State private var visibility: Visibility = .public
    @State private var isPosting = false
    @State private var error: Error?
    
    @FocusState private var isContentFocused: Bool
    
    private var isReply: Bool { replyTo != nil }
    private var isQuote: Bool { quote != nil }
    
    private var title: String {
        if isReply { return "Reply" }
        if isQuote { return "Quote" }
        return "New Post"
    }
    
    private var canPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isPosting
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Reply context
                if let replyTo {
                    replyContext(replyTo)
                }
                
                // Quote context
                if let quote {
                    quoteContext(quote)
                }
                
                // Content warning
                if showSpoiler {
                    TextField("Content warning", text: $spoilerText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .padding(.top)
                }
                
                // Main content
                TextEditor(text: $content)
                    .focused($isContentFocused)
                    .frame(minHeight: 150)
                    .padding()
                    .scrollContentBackground(.hidden)
                
                Divider()
                
                // Toolbar
                composeToolbar
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await post()
                        }
                    } label: {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("Post")
                                .bold()
                        }
                    }
                    .disabled(!canPost)
                }
            }
            .onAppear {
                setupInitialContent()
                isContentFocused = true
            }
            .alert("Error", isPresented: Binding(
                get: { error != nil },
                set: { isPresented in
                    if !isPresented {
                        error = nil
                    }
                }
            )) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Reply Context
    
    private func replyContext(_ status: Status) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(.secondary)
                .frame(width: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Replying to @\(status.displayStatus.account.acct)")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                
                Text(status.displayStatus.content.htmlToPlainText)
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Quote Context
    
    private func quoteContext(_ status: Status) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quoting")
                .font(.roundedCaption)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .top, spacing: 8) {
                AsyncImage(url: status.displayStatus.account.avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.tertiary)
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 2) {
                    EmojiText(text: status.displayStatus.account.displayName, emojis: status.displayStatus.account.emojis, font: .roundedCaption.bold())
                    
                    Text(status.displayStatus.content.htmlToPlainText)
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Compose Toolbar
    
    private var composeToolbar: some View {
        HStack(spacing: 16) {
            // Content warning toggle
            Button {
                showSpoiler.toggle()
            } label: {
                Image(systemName: showSpoiler ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                    .foregroundStyle(showSpoiler ? .orange : .secondary)
            }
            
            // Visibility picker
            Menu {
                ForEach([Visibility.public, .unlisted, .private, .direct], id: \.rawValue) { vis in
                    Button {
                        visibility = vis
                    } label: {
                        Label(visibilityLabel(vis), systemImage: visibilityIcon(vis))
                    }
                }
            } label: {
                Image(systemName: visibilityIcon(visibility))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Character count
            Text("\(content.count)")
                .font(.roundedCaption)
                .foregroundStyle(content.count > 500 ? .red : .secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    private func visibilityLabel(_ vis: Visibility) -> String {
        switch vis {
        case .public: return "Public"
        case .unlisted: return "Unlisted"
        case .private: return "Followers Only"
        case .direct: return "Direct Message"
        }
    }
    
    private func visibilityIcon(_ vis: Visibility) -> String {
        switch vis {
        case .public: return "globe"
        case .unlisted: return "lock.open"
        case .private: return "lock"
        case .direct: return "envelope"
        }
    }
    
    // MARK: - Actions
    
    private func setupInitialContent() {
        guard let replyTo else { return }
        
        let targetStatus = replyTo.displayStatus
        
        // Collect all mentions: original poster + all mentioned users
        var mentionsToInclude: Set<String> = []
        
        // Add the original poster
        mentionsToInclude.insert(targetStatus.account.acct)
        
        // Add all users mentioned in the original post
        for mention in targetStatus.mentions {
            mentionsToInclude.insert(mention.acct)
        }
        
        // Exclude current user to avoid self-mentioning
        if let currentAccount = appState.currentAccount {
            mentionsToInclude.remove(currentAccount.acct)
        }
        
        // Build mention string
        let mentionStrings = mentionsToInclude.sorted().map { "@\($0) " }
        content = mentionStrings.joined()
        
        // Inherit visibility from the post being replied to
        visibility = targetStatus.visibility
    }
    
    private func post() async {
        guard canPost else { return }
        
        isPosting = true
        defer { isPosting = false }
        
        do {
            if let replyTo {
                // Reply
                guard let service = timelineWrapper.service else {
                    throw FediReaderError.noActiveAccount
                }
                _ = try await service.reply(to: replyTo.displayStatus, content: content)
            } else if let quote {
                // Quote boost
                guard let service = timelineWrapper.service else {
                    throw FediReaderError.noActiveAccount
                }
                _ = try await service.quoteBoost(status: quote, content: content)
            } else {
                // New post (would need to add postStatus to TimelineService)
                guard let account = appState.currentAccount,
                      let token = await appState.getAccessToken() else {
                    throw FediReaderError.noActiveAccount
                }
                
                _ = try await appState.client.postStatus(
                    instance: account.instance,
                    accessToken: token,
                    status: content,
                    sensitive: showSpoiler,
                    spoilerText: showSpoiler ? spoilerText : nil,
                    visibility: visibility
                )
            }
            
            dismiss()
        } catch {
            self.error = error
        }
    }
}

#Preview {
    ComposeView(replyTo: nil, quote: nil)
        .environment(AppState())
        .environment(TimelineServiceWrapper())
}
