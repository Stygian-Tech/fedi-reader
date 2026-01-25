//
//  FeedTabButton.swift
//  fedi-reader
//
//  Tab button for link feed list picker.
//

import SwiftUI

struct FeedTabButton: View {
    let title: String
    let isSelected: Bool
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.roundedSubheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}
