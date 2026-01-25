//
//  HashtagPlaceholderView.swift
//  fedi-reader
//
//  Placeholder view that loads hashtag timeline for hashtag navigation.
//

import SwiftUI

struct HashtagPlaceholderView: View {
    let tag: String
    @Environment(AppState.self) private var appState
    @State private var statuses: [Status] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if !statuses.isEmpty {
                List(statuses) { status in
                    StatusRowView(status: status)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowSpacing(8)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("No Posts", systemImage: "number")
            }
        }
        .navigationTitle("#\(tag)")
        .task {
            await loadHashtagTimeline()
        }
    }

    private func loadHashtagTimeline() async {
        let client = appState.client

        do {
            statuses = try await client.getHashtagTimeline(tag: tag)
        } catch {
            // Handle error
        }
        isLoading = false
    }
}
