import SwiftUI

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


