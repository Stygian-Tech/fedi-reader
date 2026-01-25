//
//  LoginView.swift
//  fedi-reader
//
//  Mastodon instance login view
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthSession
    
    @State private var instanceURL = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showInstanceSuggestions = false
    
    private let popularInstances = [
        "mastodon.social",
        "mastodon.online",
        "fosstodon.org",
        "hachyderm.io",
        "infosec.exchange",
        "tech.lgbt",
        "mstdn.social"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.key")
                        .font(.rounded(size: 60))
                        .foregroundStyle(.tint)
                    
                    Text("Connect to Mastodon")
                        .font(.roundedTitle2.bold())
                    
                    Text("Enter your instance URL to log in")
                        .font(.roundedSubheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Instance input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instance URL")
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.secondary)
                        
                        TextField("mastodon.social", text: $instanceURL)
                            .textFieldStyle(.plain)
                            .textContentType(.URL)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                            .onSubmit {
                                Task {
                                    await login()
                                }
                            }
                    }
                    .padding()
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)
                
                // Popular instances
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation {
                            showInstanceSuggestions.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Popular Instances")
                                .font(.roundedSubheadline)
                            
                            Spacer()
                            
                            Image(systemName: showInstanceSuggestions ? "chevron.up" : "chevron.down")
                                .font(.roundedCaption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    if showInstanceSuggestions {
                        FlowLayout(spacing: 8) {
                            ForEach(popularInstances, id: \.self) { instance in
                                LiquidGlassTag(instance) {
                                    instanceURL = instance
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Login button
                Button {
                    Task {
                        await login()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.white)
                    } else {
                        Text("Continue")
                            .font(.roundedHeadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.liquidGlass)
                .disabled(instanceURL.isEmpty || isLoading)
                .opacity(instanceURL.isEmpty ? 0.5 : 1.0)
                .padding(.horizontal)
                
                // Privacy note
                Text("We'll open a browser to authenticate with your instance. Your credentials are never stored by Fedi Reader.")
                    .font(.roundedCaption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Login Error", isPresented: .constant(error != nil)) {
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
    
    private func login() async {
        guard !instanceURL.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let authURL = try await appState.authService.initiateLogin(instance: instanceURL)
            
            // Use web authentication session
            let callbackURL = try await webAuthSession.authenticate(
                using: authURL,
                callbackURLScheme: Constants.OAuth.redirectScheme
            )
            
            let account = try await appState.authService.handleCallback(url: callbackURL, modelContext: modelContext)
            // Fetch custom emoji for the newly logged-in instance
            await appState.emojiService.fetchCustomEmojis(for: account.instance)
            dismiss()
        } catch ASWebAuthenticationSessionError.canceledLogin {
            // User cancelled - do nothing
        } catch {
            self.error = error
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: ProposedViewSize(result.sizes[index]))
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                sizes.append(size)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                
                self.size.width = max(self.size.width, currentX - spacing)
            }
            
            self.size.height = currentY + lineHeight
        }
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
