//
//  ReadLaterLoginView.swift
//  fedi-reader
//
//  Login/configure read-later services
//

import SwiftUI
import SwiftData

struct ReadLaterLoginView: View {
    let serviceType: ReadLaterServiceType
    
    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: serviceType.iconName)
                        .font(.rounded(size: 50))
                        .foregroundStyle(.tint)
                    
                    Text("Connect to \(serviceType.displayName)")
                        .font(.roundedTitle2.bold())
                    
                    Text(serviceDescription)
                        .font(.roundedSubheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 32)
                
                // Input fields
                VStack(spacing: 16) {
                    switch serviceType {
                    case .pocket:
                        pocketLoginView
                    case .instapaper:
                        instapaperLoginView
                    case .omnivore:
                        apiKeyLoginView(placeholder: "Omnivore API Key", helpURL: "https://omnivore.app/settings/api")
                    case .readwise:
                        apiKeyLoginView(placeholder: "Readwise Access Token", helpURL: "https://readwise.io/access_token")
                    case .raindrop:
                        apiKeyLoginView(placeholder: "Raindrop Access Token", helpURL: "https://app.raindrop.io/settings/integrations")
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Connect button
                Button {
                    Task {
                        await connect()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.primary)
                    } else {
                        Text("Connect")
                            .font(.roundedHeadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.liquidGlass)
                .disabled(!canConnect || isLoading)
                .opacity(canConnect ? 1.0 : 0.5)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle(serviceType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
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
    
    private var serviceDescription: String {
        switch serviceType {
        case .pocket:
            return "Save articles to Pocket for reading later."
        case .instapaper:
            return "Save articles to Instapaper with your account credentials."
        case .omnivore:
            return "Connect to Omnivore using an API key from your settings."
        case .readwise:
            return "Save to Readwise Reader using your access token."
        case .raindrop:
            return "Save bookmarks to Raindrop.io using an API token."
        }
    }
    
    private var canConnect: Bool {
        switch serviceType {
        case .pocket:
            return true // Uses OAuth
        case .instapaper:
            return !username.isEmpty && !password.isEmpty
        case .omnivore, .readwise, .raindrop:
            return !apiKey.isEmpty
        }
    }
    
    // MARK: - Login Views
    
    private var pocketLoginView: some View {
        VStack(spacing: 12) {
            Text("Pocket uses OAuth authentication. You'll be redirected to Pocket to authorize Fedi Reader.")
                .font(.roundedCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Consumer key input (required for Pocket)
            VStack(alignment: .leading, spacing: 8) {
                Text("Consumer Key")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                
                SecureField("Enter your Pocket consumer key", text: $apiKey)
                    .textFieldStyle(.plain)
                    .padding()
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
                
                Link("Get a consumer key from Pocket", destination: URL(string: "https://getpocket.com/developer/apps/")!)
                    .font(.roundedCaption)
            }
        }
    }
    
    private var instapaperLoginView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email or Username")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                
                TextField("Email", text: $username)
                    .textFieldStyle(.plain)
                    .textContentType(.emailAddress)
                    .padding()
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .textContentType(.password)
                    .padding()
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    
    private func apiKeyLoginView(placeholder: String, helpURL: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key / Token")
                .font(.roundedCaption)
                .foregroundStyle(.secondary)
            
            SecureField(placeholder, text: $apiKey)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .padding()
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            
            Link("Get your API key", destination: URL(string: helpURL)!)
                .font(.roundedCaption)
        }
    }
    
    // MARK: - Actions
    
    private func connect() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            switch serviceType {
            case .pocket:
                // For Pocket, we'd need to go through OAuth
                // For now, store the consumer key
                if !apiKey.isEmpty {
                    let configData = try JSONEncoder().encode(PocketConfig(consumerKey: apiKey))
                    try await readLaterManager.configureService(
                        .pocket,
                        token: "", // Will be obtained through OAuth
                        additionalConfig: configData,
                        modelContext: modelContext
                    )
                }
                
            case .instapaper:
                // Store credentials for Instapaper basic-auth save endpoint
                try await readLaterManager.configureService(
                    .instapaper,
                    token: "\(username):\(password)",
                    modelContext: modelContext
                )
                
            case .omnivore:
                try await readLaterManager.configureService(
                    .omnivore,
                    token: apiKey,
                    modelContext: modelContext
                )
                
            case .readwise:
                try await readLaterManager.configureService(
                    .readwise,
                    token: apiKey,
                    modelContext: modelContext
                )
                
            case .raindrop:
                try await readLaterManager.configureService(
                    .raindrop,
                    token: apiKey,
                    modelContext: modelContext
                )
            }
            
            dismiss()
        } catch {
            self.error = error
        }
    }
}

#Preview {
    ReadLaterLoginView(serviceType: .omnivore)
        .environment(ReadLaterManager())
}
