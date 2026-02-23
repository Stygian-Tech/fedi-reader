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
    var pillNamespace: Namespace.ID?
    let action: () -> Void

    init(
        title: String,
        isSelected: Bool,
        pillNamespace: Namespace.ID? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.pillNamespace = pillNamespace
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.roundedSubheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected, let namespace = pillNamespace {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.15))
                            .matchedGeometryEffect(id: "feedTabPill", in: namespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
