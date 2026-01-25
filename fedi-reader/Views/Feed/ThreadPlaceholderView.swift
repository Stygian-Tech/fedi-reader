//
//  ThreadPlaceholderView.swift
//  fedi-reader
//
//  Placeholder view that loads a single status by ID for thread navigation.
//

import SwiftUI

struct ThreadPlaceholderView: View {
    let statusId: String
    @Environment(AppState.self) private var appState
    @State private var status: Status?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let status = status {
                StatusDetailView(status: status)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Post Not Found", systemImage: "bubble.left")
            }
        }
        .navigationTitle("Thread")
        .task {
            await loadStatus()
        }
    }

    private func loadStatus() async {
        let client = appState.client

        do {
            status = try await client.getStatus(id: statusId)
        } catch {
            // Handle error
        }
        isLoading = false
    }
}
