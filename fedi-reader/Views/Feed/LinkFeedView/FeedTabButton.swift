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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.roundedSubheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
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
