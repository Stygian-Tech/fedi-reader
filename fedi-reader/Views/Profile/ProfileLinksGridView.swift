//
//  ProfileLinksGridView.swift
//  fedi-reader
//
//  Responsive multi-column profile links grid.
//

import SwiftUI

struct ProfileLinksGridView: View {
    let fields: [Field]

    @State private var containerWidth: CGFloat = 0

    var body: some View {
        let metrics = ProfileLinksGridLayout.metrics(containerWidth: containerWidth)

        LazyVGrid(
            columns: ProfileLinksGridLayout.gridItems(columnCount: metrics.columns),
            alignment: .leading,
            spacing: ProfileLinksGridLayout.interItemSpacing
        ) {
            ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                FieldCardView(field: field)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ProfileLinksGridLayout.horizontalPadding)
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(key: ProfileLinksGridWidthPreferenceKey.self, value: geo.size.width)
            }
        }
        .onPreferenceChange(ProfileLinksGridWidthPreferenceKey.self) { width in
            containerWidth = width
        }
    }
}

struct ProfileLinksGridMetrics: Equatable {
    let columns: Int
    let itemWidth: CGFloat
}

enum ProfileLinksGridLayout {
    static let horizontalPadding: CGFloat = 16
    static let interItemSpacing: CGFloat = 12
    static let minimumCardWidth: CGFloat = 168

    static func metrics(containerWidth: CGFloat) -> ProfileLinksGridMetrics {
        let usableWidth = max(0, containerWidth - (horizontalPadding * 2))
        let denominator = minimumCardWidth + interItemSpacing
        let columns = max(1, Int((usableWidth + interItemSpacing) / denominator))
        let totalSpacing = interItemSpacing * CGFloat(max(0, columns - 1))
        let itemWidth = max(0, (usableWidth - totalSpacing) / CGFloat(columns))

        return ProfileLinksGridMetrics(columns: columns, itemWidth: itemWidth)
    }

    static func gridItems(columnCount: Int) -> [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: interItemSpacing, alignment: .top),
            count: max(1, columnCount)
        )
    }
}

private struct ProfileLinksGridWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
