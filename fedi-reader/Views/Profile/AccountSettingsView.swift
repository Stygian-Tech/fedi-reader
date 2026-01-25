//
//  AccountSettingsView.swift
//  fedi-reader
//
//  Account settings view (profile, refresh, logout).
//

import SwiftUI
import SwiftData

struct AccountSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var isRefreshing = false

    var body: some View {
        List {
            if let account = appState.currentAccount {
                Section {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(.tertiary)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.displayName)
                                .font(.roundedHeadline)

                            Text(account.fullHandle)
                                .font(.roundedSubheadline)
                                .foregroundStyle(.secondary)

                            Text(account.instance)
                                .font(.roundedCaption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        Task {
                            isRefreshing = true
                            try? await appState.authService.refreshAccountInfo(for: account, modelContext: modelContext)
                            isRefreshing = false
                        }
                    } label: {
                        HStack {
                            Label("Refresh Account Info", systemImage: "arrow.clockwise")

                            if isRefreshing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRefreshing)

                    Link(destination: URL(string: "https://\(account.instance)/settings/profile")!) {
                        Label("Edit Profile on Web", systemImage: "safari")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await appState.authService.logout(account: account, modelContext: modelContext)
                        }
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Account",
                    systemImage: "person.slash",
                    description: Text("Please log in first")
                )
            }
        }
        .navigationTitle("Account Settings")
    }
}
